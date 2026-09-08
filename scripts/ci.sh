#!/usr/bin/env bash
# Runs the project's deterministic checks: the ```bash block of the "## Commands" section of docs/constitution.md, in order, fail-fast.
#
#   sdd ci            → runs every command; prints "ci: PASS | FAIL | BLOCKED" last, the failing command's output before it
#   sdd ci list       → prints the commands without running them
# Review Gates never run on a red build. Never installs, never fixes: it reports.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; c="$root/docs/constitution.md"
[ -f "$c" ] || { echo "ci: BLOCKED (no docs/constitution.md)"; exit 2; }
cmds="$(awk '/^## Commands/{s=1;next} s&&/^## /{exit} s&&/^```/{f=!f;next} s&&f' "$c" | sed -E 's/[[:space:]]+#.*$//' | grep -vE '^[[:space:]]*(#|$)')"
[ -n "$cmds" ] || { echo "ci: BLOCKED (docs/constitution.md has no \`\`\`bash block under '## Commands')"; exit 2; }
[ "${1:-}" = list ] && { printf '%s\n' "$cmds"; exit 0; }
cd "$root"
while IFS= read -r line; do
  printf '\n$ %s\n' "$line"
  if ! bash -c "$line"; then printf '\nci: FAIL (%s)\n' "$line"; exit 1; fi
done <<< "$cmds"
echo; echo "ci: PASS"
