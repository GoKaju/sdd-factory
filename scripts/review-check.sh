#!/usr/bin/env bash
# The `mechanical` gate: objective checks of a code PR done in bash before any reviewer runs, so the LLM gates
# spend their attention on judgement. Run from the issue's worktree; prints one gate-result YAML block.
#
#   sdd review-check <issue> <cycle>   → YAML (gate: mechanical) on stdout; post it with `sdd gate-result post`
#
# BLOCKER: `skip`/`only`-style markers added to tests (constitution Q3) · TODO/FIXME/HACK/XXX added to code.
# WARNING: added comments, docstrings or document lines that read as Spanish (constitution C1; string literals are skipped)
#          · test files deleted · files below a folder changed outside the Locations of the affected design (root-level
#          config files and tool folders are exempt) · blueprint exemplars that do not exist, when this PR edits the
#          blueprint or deletes the exemplar.
# NIT:     one line listing the requirement IDs no test cites literally (a lead for the behaviour gate, not a defect).
# From cycle 1 on, a finding a reviewer ruled `disputed: withdrawn` in an earlier cycle (same location) is not reported
# again; one ruled `disputed: upheld` stays, marked, and turns the status into NEEDS_HUMAN instead of FAIL.
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"
need_issue "${1:-}"; issue="$1"; cycle="${2:-0}"

pr="$("$S/pr.sh" find "$issue")"; [ -n "$pr" ] || die "issue #$issue has no PR"
base="$(gh pr view "$pr" --json baseRefName -q .baseRefName)"
git fetch -q origin "$base" 2>/dev/null || true
head="$(git rev-parse HEAD)"
diff="$(mktemp)"; git diff --unified=0 --no-color "origin/$base...HEAD" > "$diff"
status="$(mktemp)"; git diff --name-status "origin/$base...HEAD" > "$status"
rulings="$(mktemp)"; c=0; while [ "$c" -lt "$cycle" ] 2>/dev/null; do "$S/gate-result.sh" show "$pr" "$c" >> "$rulings" || true; c=$((c + 1)); done

python3 - "$issue" "$pr" "$head" "$cycle" "$diff" "$status" "$rulings" <<'PY'
import os, re, subprocess, sys
issue, pr, head, cycle, diff_file, status_file, rulings_file = sys.argv[1:]

TEST = re.compile(r"(\.test\.|\.spec\.|_test\.|(^|/)tests?/|(^|/)__tests__/|(^|/)test_[^/]+$)")
# bare calls only: `TaskStatus.pending(`, `model.fit(` or `suite.test.skip(` are not test markers
SKIP = re.compile(r"((?<![\w.$])(it|test|describe|context)\.(skip|only|todo)\(|(?<![\w.$])(xit|xdescribe|xtest|fit|fdescribe|pending)\(|@pytest\.mark\.(skip|xfail)|\bt\.Skip\(|@Disabled\b|@Ignore\b)")
TODO = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b")
# Spanish in added prose: comments and docstrings of code files, every line of documents. String literals are not prose.
SPANISH_WORDS = {"que", "para", "los", "las", "del", "una", "con", "por", "cuando", "esto", "este", "esta", "pero", "como",
                 "porque", "también", "según", "debe", "sino", "está", "son", "más", "aquí", "donde", "cada", "entre", "hasta",
                 "el", "la", "al", "se", "su", "sus", "lo", "le", "hay", "sin", "sobre", "desde", "usuario", "mensaje"}
DOC = re.compile(r"(\.md|\.mdx|\.rst|\.txt|\.adoc)$")
LANG_SKIP = re.compile(r"(^\.github/ISSUE_TEMPLATE/|(^|/)(locales?|i18n|translations?|lang)/|\.(json|ya?ml|po|properties|csv|svg|html?)$)")
COMMENT = re.compile(r"^\s*(//+|#+(?![!\[])|/\*+|\*+(?!/)|\"\"\"|\'\'\'|<!--|--(?!-)|;+)\s?(.*)$")
TRAILING = re.compile(r"\s(//|#)\s+(.+)$")
def prose(path, text):
    if path.endswith("spec.md") and text.lstrip().startswith("|"): return ""   # Rejections rows carry end-user messages
    if DOC.search(path): return text
    m = COMMENT.match(text)
    if m: return m.group(2)
    m = TRAILING.search(text)
    if m and text[:m.start()].count('"') % 2 == 0 and text[:m.start()].count("'") % 2 == 0: return m.group(2)
    return ""
def spanish(t):
    words = re.findall(r"[a-záéíóúñü]+", t.lower())
    hits = sum(w in SPANISH_WORDS for w in words)
    return bool(re.search(r"[¿¡]", t)) or hits >= 2 or (hits >= 1 and bool(re.search(r"[áéíóúñ]", t.lower())))
IGNORE = re.compile(r"(^docs/|^\.sdd/|\.md$|(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|bun\.lockb?|Cargo\.lock|poetry\.lock|uv\.lock|go\.sum|composer\.lock|Gemfile\.lock)$)")

ROOT_OR_TOOLING = re.compile(r"(^[^/]+$|^\.(github|claude|vscode|husky|devcontainer|changeset)/)")   # tsconfig.json, package.json, CI, editor
findings = []
def add(sev, loc, desc, action, req=None):
    findings.append((sev, loc, desc, action, req))

# added lines per file, with their new line numbers
cur, line, lang_hits = None, 0, {}
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
    if not LANG_SKIP.search(cur) and not cur.startswith(".sdd/") and spanish(prose(cur, text)):
        lang_hits.setdefault(cur, []).append((line, text.strip()[:100]))
    line += 1

for path, hits in lang_hits.items():
    ln, sample = hits[0]
    more = " (and %d more line(s) in this file)" % (len(hits) - 1) if len(hits) > 1 else ""
    add("WARNING", "%s:%d" % (path, ln), "Reads as Spanish: `%s`%s. The repository is English (C1)." % (sample.replace("`", "'"), more),
        "Rewrite it in English; only end-user message strings may use another language.")

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
        if IGNORE.search(p) or TEST.search(p) or ROOT_OR_TOOLING.search(p) or any(p.startswith(l) for l in prefixes): continue
        add("WARNING", p, "File changed outside the Locations and Boundary of the affected design(s).", "Explain it in the PR description, or move the change inside the design's Locations.")

tests = [p for p in subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split("\n") if p and TEST.search(p)]
corpus = "\n".join(read(p) for p in tests)
for d in modules:
    spec = read(os.path.join(d, "spec.md"))
    ids = [rid for rid, title in re.findall(r"^### ([A-Z][A-Z0-9]*-\d{3})\b(.*)$", spec, re.M) if "Removed" not in title]
    uncited = [rid for rid in ids if not re.search(r"\b%s\b" % re.escape(rid), corpus)]
    if uncited:
        add("NIT", os.path.join(d, "spec.md"), "%d of %d requirement IDs are not cited literally by any test: %s." % (len(uncited), len(ids), ", ".join(uncited)),
            "None here: the behaviour gate looks for these by behavior. Citing the ID in the test name makes the trace mechanical.")

bp = read("docs/blueprint.md") if ("docs/blueprint.md" in changed or deleted) else ""
for row in re.findall(r"^\|.*\|[ \t]*$", bp, re.M):
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    if not cells or cells[0] in ("Kind", "Kind of test") or set(cells[0]) <= set("- "): continue
    for p in re.findall(r"`([^`<>]+)`", cells[-1]):
        if "/" in p and not os.path.exists(p) and ("docs/blueprint.md" in changed or p in deleted):
            add("WARNING", "docs/blueprint.md", "Exemplar `%s` does not exist." % p, "Point the blueprint row at an existing file through a Constitution issue.")

# rulings of earlier cycles on disputed findings, by location
rulings = {}
for chunk in re.split(r"\n\s*- severity:", read(rulings_file)):
    loc = re.search(r"^\s*location:\s*(\S+)", chunk, re.M); d = re.search(r"^\s*disputed:\s*(withdrawn|upheld)", chunk, re.M)
    if loc and d: rulings[loc.group(1).strip('"')] = d.group(1)
kept, upheld = [], set()
for f in findings:
    r = rulings.get(f[1])
    if r == "withdrawn": continue
    if r == "upheld": upheld.add(f[1])
    kept.append(f)
findings = kept
blocking = [f for f in findings if f[0] == "BLOCKER"]
status = "PASS" if not blocking else ("NEEDS_HUMAN" if all(f[1] in upheld for f in blocking) else "FAIL")
q = lambda s: '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
out = ["gate: mechanical", "issue: " + issue, "pr: " + pr, "commit: " + head, "status: " + status, "rework_cycle: " + cycle]
out.append("findings:" + ("" if findings else " []"))
for sev, loc, desc, action, req in findings:
    out.append("  - severity: " + sev)
    if req: out.append("    requirement: " + req)
    out += ["    location: " + loc, "    description: >", "      " + desc, "    required_action: " + q(action)]
    if loc in upheld: out.append("    disputed: upheld")
out += ["evidence:", "  - git diff origin/<base>...HEAD", "  - docs/blueprint.md"]
print("\n".join(out))
PY
rm -f "$diff" "$status" "$rulings"
