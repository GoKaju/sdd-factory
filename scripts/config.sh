#!/usr/bin/env bash
# Operation config of the factory for this repository: .sdd/config.yml (template: templates/config.template.yml).
# A small YAML subset is enough: nested maps by indentation, scalars, lists of scalars, comments.
#
#   sdd config path                          → prints the path (exit 1 if the file does not exist)
#   sdd config get <key>                     → prints a scalar, or a list one item per line (dot keys: models.spec, gates.delegated)
#   sdd config set <key> <value>...          → sets a scalar (one value) or a list (several values, or none = empty list); keeps comments
#   sdd config show                          → prints the whole file
#   sdd config init [--from-constitution]    → creates .sdd/config.yml from the template if missing; --from-constitution migrates
#                                              Language, Rework budget, Delegated gates, Warnings at Final and Commands from docs/constitution.md
#   sdd config validate                      → checks keys and values; exit 1 with one line per problem
set -euo pipefail
die() { printf 'sdd: %s\n' "$*" >&2; exit 1; }
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
file="${SDD_CONFIG:-$root/.sdd/config.yml}"
tpl="$(cd "$(dirname "$0")/.." && pwd -P)/templates/config.template.yml"

PY='
import sys, re, json

def scalar(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\x27\x22": return v[1:-1]
    return v

def parse2(text):
    """Two-pass: mark keys whose children are list items."""
    lines = text.splitlines(); listkeys = set()
    for i, raw in enumerate(lines):
        s = raw.strip()
        if not s or s.startswith("#") or s.startswith("- "): continue
        m = re.match(r"^([A-Za-z0-9_.-]+)\s*:\s*$", re.sub(r"\s+#.*$", "", s))
        if not m: continue
        for nxt in lines[i+1:]:
            if not nxt.strip() or nxt.strip().startswith("#"): continue
            if nxt.strip().startswith("- ") and len(nxt) - len(nxt.lstrip(" ")) > len(raw) - len(raw.lstrip(" ")): listkeys.add(i)
            break
    root = {}; stack = [(-1, root, None)]
    for i, raw in enumerate(lines):
        line = "" if raw.lstrip().startswith("#") else re.sub(r"\s+#.*$", "", raw)
        if not line.strip(): continue
        indent = len(line) - len(line.lstrip(" ")); body = line.strip()
        while stack and indent <= stack[-1][0]: stack.pop()
        _, cont, key = stack[-1]
        if body.startswith("- "):
            if not isinstance(cont, list): raise SystemExit("config: list item without a list key at: " + raw)
            cont.append(scalar(body[2:])); continue
        m = re.match(r"^([A-Za-z0-9_.-]+)\s*:\s*(.*)$", body)
        if not m or not isinstance(cont, dict): raise SystemExit("config: cannot parse line: " + raw)
        k, val = m.group(1), m.group(2).strip()
        if val == "":
            cont[k] = [] if i in listkeys else {}
            stack.append((indent, cont[k], k))
        elif val in ("[]", "none", "None", "~", "null"): cont[k] = []
        else: cont[k] = scalar(val)
    return root

def get(cfg, path):
    node = cfg
    for p in path.split("."):
        if not isinstance(node, dict) or p not in node: return None
        node = node[p]
    return node

def set_value(text, path, values):
    """Rewrite the scalar or list at path, keeping every other line and comment. Appends when missing."""
    lines = text.splitlines(); parts = path.split(".")
    # locate the line of each key along the path
    def find(start, end, indent, key):
        for i in range(start, end):
            l = lines[i]
            if not l.strip() or l.lstrip().startswith("#"): continue
            ind = len(l) - len(l.lstrip(" "))
            if ind < indent: return None
            if ind == indent and re.match(r"^" + re.escape(key) + r"\s*:", l.strip()): return i
        return None
    def block_end(i, indent):
        j = i + 1
        while j < len(lines):
            l = lines[j]
            if l.strip() and not l.lstrip().startswith("#") and len(l) - len(l.lstrip(" ")) <= indent: break
            j += 1
        # do not swallow trailing comment lines that belong to the next key
        while j - 1 > i and (lines[j-1].lstrip().startswith("#") or not lines[j-1].strip()): j -= 1
        return j
    start, end, indent = 0, len(lines), 0
    for depth, key in enumerate(parts):
        i = find(start, end, indent, key)
        if i is None:
            # append the missing key (and the rest of the path) at the end of the current block
            ins = end
            new = []
            for d, k in enumerate(parts[depth:]):
                ind = " " * (indent + 2*d)
                if d == len(parts[depth:]) - 1: new += render(ind, k, values, path)
                else: new.append(ind + k + ":")
            lines[ins:ins] = new
            return "\n".join(lines) + "\n"
        if depth == len(parts) - 1:
            j = block_end(i, indent)
            lines[i:j] = render(" " * indent, key, values, path)
            return "\n".join(lines) + "\n"
        start, end, indent = i + 1, block_end(i, indent), indent + 2

def render(ind, key, values, path):
    def q(v):
        return v if re.match(r"^[A-Za-z0-9_./:-]+$", v) else json.dumps(v)
    is_list = VALID.get(path, ("",))[0] == "list" or len(values) != 1 or values[0] == "[]"
    if not is_list:
        return [ind + key + ": " + q(values[0])]
    vals = values if not (len(values) == 1 and values[0] == "[]") else []
    return [ind + key + ":" + (" []" if not vals else "")] + [ind + "  - " + q(v) for v in vals]

VALID = {
  "language": ("scalar", ["en", "es"]),
  "models.triage": ("scalar", ["haiku", "sonnet", "opus", "inherit"]), "models.spec": ("scalar", ["haiku", "sonnet", "opus", "inherit"]),
  "models.design": ("scalar", ["haiku", "sonnet", "opus", "inherit"]), "models.task": ("scalar", ["haiku", "sonnet", "opus", "inherit"]),
  "models.implement": ("scalar", ["haiku", "sonnet", "opus", "inherit"]), "models.reviewer": ("scalar", ["haiku", "sonnet", "opus", "inherit"]),
  "models.learning": ("scalar", ["haiku", "sonnet", "opus", "inherit"]),
  "gates.delegated": ("list", None), "gates.warnings_at_final": ("scalar", ["human", "merge", "rework"]), "gates.rework_budget": ("int", None),
  "await.interval_seconds": ("int", None), "await.max_minutes": ("int", None), "commands": ("list", None),
}

def validate(cfg):
    problems = []
    for key, (kind, allowed) in VALID.items():
        v = get(cfg, key)
        if v is None: problems.append("missing: " + key); continue
        if kind == "list" and not isinstance(v, list): problems.append("must be a list: " + key)
        if kind == "scalar" and (not isinstance(v, str) or (allowed and v not in allowed)): problems.append("%s must be one of %s (got %r)" % (key, ", ".join(allowed), v))
        if kind == "int" and (not isinstance(v, str) or not v.isdigit() or int(v) < 1): problems.append("%s must be a positive integer (got %r)" % (key, v))
    for g in get(cfg, "gates.delegated") or []:
        name = re.sub(r"\s*\(judged\)\s*$", "", g).strip()
        if name not in ("Intake", "Spec", "Design", "Task", "Final"): problems.append("gates.delegated: unknown gate %r" % g)
    for c in get(cfg, "commands") or []:
        if c.startswith("<") and c.endswith(">"): problems.append("commands: placeholder still present: " + c)
    return problems

cmd = sys.argv[1]; text = sys.stdin.read()
if cmd == "get":
    v = get(parse2(text), sys.argv[2])
    if v is None: sys.exit(1)
    if isinstance(v, list): print("\n".join(v)) if v else None
    elif isinstance(v, dict): print("\n".join("%s: %s" % kv for kv in v.items()))
    else: print(v)
elif cmd == "set":
    sys.stdout.write(set_value(text, sys.argv[2], sys.argv[3:] or ["[]"]))
elif cmd == "validate":
    p = validate(parse2(text)); print("\n".join(p)); sys.exit(1 if p else 0)
elif cmd == "json":
    print(json.dumps(parse2(text), ensure_ascii=False, indent=1))
'

py() { python3 -c "$PY" "$@"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  path) [ -f "$file" ] || { printf '%s\n' "$file" >&2; exit 1; }; printf '%s\n' "$file" ;;
  show) [ -f "$file" ] || die "no $file: run /sdd-init (or sdd config init)"; cat "$file" ;;
  json) [ -f "$file" ] || die "no $file"; py json < "$file" ;;
  get)
    [ -n "${1:-}" ] || die "key required, e.g. models.spec"
    [ -f "$file" ] || die "no $file: run /sdd-init (or sdd config init)"
    py get "$1" < "$file" || die "no key '$1' in $file"
    ;;
  set)
    [ -n "${1:-}" ] || die "key required"; key="$1"; shift
    [ -f "$file" ] || die "no $file: run sdd config init first"
    tmp="$(mktemp)"; py set "$key" "$@" < "$file" > "$tmp" && mv "$tmp" "$file"
    printf '%s = %s\n' "$key" "$(py get "$key" < "$file" | tr '\n' ' ')"
    ;;
  validate) [ -f "$file" ] || die "no $file"; py validate < "$file" ;;
  init)
    mkdir -p "$(dirname "$file")"
    if [ -f "$file" ]; then printf 'exists   %s\n' "$file"; else cp "$tpl" "$file"; printf 'created  %s\n' "$file"; fi
    if [ "${1:-}" = "--from-constitution" ] && [ -f "$root/docs/constitution.md" ]; then
      c="$root/docs/constitution.md"
      lang="$(grep -oE '\*\*Language:\*\*[[:space:]]*(en|es)' "$c" | grep -oE '(en|es)$' | head -1 || true)"
      [ -n "$lang" ] && "$0" set language "$lang"
      budget="$(grep -oE '\*\*Rework budget:\*\*[[:space:]]*[0-9]+' "$c" | grep -oE '[0-9]+$' | head -1 || true)"
      [ -n "$budget" ] && "$0" set gates.rework_budget "$budget"
      pol="$(grep -oE '\*\*Warnings at Final:\*\*[[:space:]]*(rework|merge|human)' "$c" | grep -oE '(rework|merge|human)$' | head -1 || true)"
      [ -n "$pol" ] && "$0" set gates.warnings_at_final "$pol"
      del="$(grep -oE '\*\*Delegated gates:\*\*[^—]*' "$c" | head -1 | sed 's/\*\*Delegated gates:\*\*//; s/[`*]//g' | tr ',;·' '\n\n\n' | sed 's/^ *//; s/ *$//' | grep -E '^(Intake|Spec|Design|Task|Final)( \(judged\))?$' || true)"
      if [ -n "$del" ]; then set -- ; while read -r g; do set -- "$@" "$g"; done <<< "$del"; "$0" set gates.delegated "$@"; fi
      cmds="$(awk '/^## Commands/{s=1;next} s&&/^## /{exit} s&&/^```/{f=!f;next} s&&f' "$c" | sed -E 's/[[:space:]]+#.*$//' | grep -vE '^[[:space:]]*(#|$)' || true)"
      if [ -n "$cmds" ]; then set -- ; while IFS= read -r l; do set -- "$@" "$l"; done <<< "$cmds"; "$0" set commands "$@"; fi
    fi
    ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
