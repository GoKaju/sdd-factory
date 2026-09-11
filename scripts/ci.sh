#!/usr/bin/env bash
# Runs the project's deterministic checks: the `commands` list of .sdd/config.yml, in order, fail-fast.
#
#   sdd ci            → runs every command; prints "ci: PASS | FAIL | BLOCKED" last, the failing command's output before it
#   sdd ci list       → prints the commands without running them
# Review Gates never run on a red build. Never installs, never fixes: it reports.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cmds="$(bash "$(dirname "$0")/config.sh" get commands 2>/dev/null | grep -vE '^[[:space:]]*(#|$)')"
[ -n "$cmds" ] || { echo "ci: BLOCKED (.sdd/config.yml has no commands list; run /sdd-config)"; exit 2; }
printf '%s\n' "$cmds" | grep -Eq '^<.*>$' && { echo "ci: BLOCKED (.sdd/config.yml commands still carry a <placeholder>; run /sdd-config)"; exit 2; }
[ "${1:-}" = list ] && { printf '%s\n' "$cmds"; exit 0; }
cd "$root"
while IFS= read -r line; do
  printf '\n$ %s\n' "$line"
  if ! bash -c "$line"; then printf '\nci: FAIL (%s)\n' "$line"; exit 1; fi
done <<< "$cmds"
echo; echo "ci: PASS"
