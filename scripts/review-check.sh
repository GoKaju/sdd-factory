#!/usr/bin/env bash
# The `mechanical` gate: objective checks of a code PR done in bash before any reviewer runs, so the LLM gates
# spend their attention on judgement. Run from the issue's worktree; prints one gate-result YAML block.
#
#   sdd review-check <issue> <cycle>   → YAML (gate: mechanical) on stdout; post it with `sdd gate-result post`
#
# BLOCKER: `skip`/`only`-style markers added to tests (constitution Q3) · TODO/FIXME/HACK/XXX added to code.
# WARNING: test files deleted · files changed outside the Locations of the affected design · requirement IDs of the
#          affected specs that no test file cites · exemplar paths of docs/blueprint.md that do not exist.
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"
need_issue "${1:-}"; issue="$1"; cycle="${2:-0}"

pr="$("$S/pr.sh" find "$issue")"; [ -n "$pr" ] || die "issue #$issue has no PR"
base="$(gh pr view "$pr" --json baseRefName -q .baseRefName)"
git fetch -q origin "$base" 2>/dev/null || true
head="$(git rev-parse HEAD)"
diff="$(mktemp)"; git diff --unified=0 --no-color "origin/$base...HEAD" > "$diff"
status="$(mktemp)"; git diff --name-status "origin/$base...HEAD" > "$status"

python3 - "$issue" "$pr" "$head" "$cycle" "$diff" "$status" <<'PY'
import os, re, subprocess, sys
issue, pr, head, cycle, diff_file, status_file = sys.argv[1:]

TEST = re.compile(r"(\.test\.|\.spec\.|_test\.|(^|/)tests?/|(^|/)__tests__/|(^|/)test_[^/]+$)")
SKIP = re.compile(r"(\b(it|test|describe|context)\.(skip|only|todo)\(|\b(xit|xdescribe|xtest|fit|fdescribe)\(|@pytest\.mark\.(skip|xfail)|\bt\.Skip\(|@Disabled\b|@Ignore\b|\bpending\()")
TODO = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b")
IGNORE = re.compile(r"(^docs/|^\.sdd/|\.md$|(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|bun\.lockb?|Cargo\.lock|poetry\.lock|uv\.lock|go\.sum|composer\.lock|Gemfile\.lock)$)")

findings = []
def add(sev, loc, desc, action, req=None):
    findings.append((sev, loc, desc, action, req))

# added lines per file, with their new line numbers
cur, line = None, 0
for raw in open(diff_file, encoding="utf-8", errors="replace"):
    if raw.startswith("+++ "):
        cur = raw[6:].rstrip("\n") if raw.startswith("+++ b/") else None; continue
    m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
    if m: line = int(m.group(1)); continue
    if cur is None or not raw.startswith("+") or raw.startswith("+++"): continue
    text = raw[1:].rstrip("\n")
    if TEST.search(cur) and SKIP.search(text):
        add("BLOCKER", "%s:%d" % (cur, line), "Test disabled or focused in this PR: `%s`." % text.strip()[:120],
            "Remove the marker, or justify it with a Spec change (cite the ID) in the PR description.")
    elif not IGNORE.search(cur) and TODO.search(text):
        add("BLOCKER", "%s:%d" % (cur, line), "Work marker added to code: `%s`." % text.strip()[:120],
            "Do the work now or remove the marker; open work is tracked in the Issue.")
    line += 1

changed, deleted = [], []
for raw in open(status_file):
    parts = raw.rstrip("\n").split("\t")
    if not parts or not parts[0]: continue
    kind, path = parts[0][0], parts[-1]
    (deleted if kind == "D" else changed).append(path)
for p in deleted:
    if TEST.search(p):
        add("WARNING", p, "Test file deleted in this PR.", "The behaviour gate classifies it as JUSTIFIED or SUSPICIOUS; justify it in the PR description.")

def read(p):
    try: return open(p, encoding="utf-8").read()
    except OSError: return ""

# affected modules: a docs/<domain>/<module>/ touched by the PR, or whose design Locations contain a changed file
def locations(design):
    txt = read(design); m = re.search(r"^## Components\n(.*?)(?=^## |\Z)", txt, re.S | re.M)
    return sorted({x for x in re.findall(r"`([A-Za-z0-9_./-]+/[A-Za-z0-9_./-]*)`", m.group(1) if m else "") if "<" not in x})
modules = {}
for d in sorted({os.path.dirname(p) for p in subprocess.run(["git", "ls-files", "docs/*/*/design.md", "docs/*/*/spec.md"], capture_output=True, text=True).stdout.split()}):
    locs = locations(os.path.join(d, "design.md"))
    if any(p.startswith(d + "/") for p in changed + deleted) or any(p.startswith(l) for p in changed for l in locs):
        modules[d] = locs

prefixes = [l for locs in modules.values() for l in locs]
if prefixes:
    for p in changed:
        if IGNORE.search(p) or TEST.search(p) or any(p.startswith(l) for l in prefixes): continue
        add("WARNING", p, "File changed outside the Locations and Boundary of the affected design(s).", "Explain it in the PR description, or move the change inside the design's Locations.")

tests = [p for p in subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split("\n") if p and TEST.search(p)]
corpus = "\n".join(read(p) for p in tests)
for d in modules:
    spec = read(os.path.join(d, "spec.md"))
    for rid, title in re.findall(r"^### ([A-Z][A-Z0-9]*-\d{3})\b(.*)$", spec, re.M):
        if "Removed" in title: continue
        if not re.search(r"\b%s\b" % re.escape(rid), corpus):
            add("WARNING", os.path.join(d, "spec.md"), "No test file cites %s." % rid, "Name the requirement ID in the test that proves it (the behaviour gate looks for it by behavior).", rid)

bp = read("docs/blueprint.md")
for row in re.findall(r"^\|.*\|[ \t]*$", bp, re.M):
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    if not cells or cells[0] in ("Kind", "Kind of test") or set(cells[0]) <= set("- "): continue
    for p in re.findall(r"`([^`<>]+)`", cells[-1]):
        if "/" in p and not os.path.exists(p):
            add("WARNING", "docs/blueprint.md", "Exemplar `%s` does not exist." % p, "Point the blueprint row at an existing file through a Constitution issue.")

status = "FAIL" if any(f[0] == "BLOCKER" for f in findings) else "PASS"
q = lambda s: '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
out = ["gate: mechanical", "issue: " + issue, "pr: " + pr, "commit: " + head, "status: " + status, "rework_cycle: " + cycle]
out.append("findings:" + ("" if findings else " []"))
for sev, loc, desc, action, req in findings:
    out.append("  - severity: " + sev)
    if req: out.append("    requirement: " + req)
    out += ["    location: " + loc, "    description: >", "      " + desc, "    required_action: " + q(action)]
out += ["evidence:", "  - git diff origin/<base>...HEAD", "  - docs/blueprint.md"]
print("\n".join(out))
PY
rm -f "$diff" "$status"
