#!/usr/bin/env bash
# Runtime flags read by the plugin hooks, stored OUTSIDE the repository so no agent permission
# rule blocks them: ~/.sdd/<owner>-<repo>/<flag>. Flags: lock-docs, allow-constitution.
#
#   sdd-flag.sh dir                 → prints the flag directory for the current repository
#   sdd-flag.sh set <flag>          → creates the flag
#   sdd-flag.sh clear <flag>        → removes the flag
#   sdd-flag.sh has <flag>          → exit 0 if present
set -euo pipefail
slug() {
  local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
  url="${url%.git}"; url="${url##*github.com[:/]}"; url="${url//\//-}"
  [ -n "$url" ] || url="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  printf '%s' "$url"
}
dir="${SDD_FLAG_HOME:-$HOME/.sdd}/$(slug)"
case "${1:-}" in
  dir) printf '%s\n' "$dir" ;;
  set) [ -n "${2:-}" ] || { echo "flag name required" >&2; exit 1; }; mkdir -p "$dir"; : > "$dir/$2"; printf '%s/%s\n' "$dir" "$2" ;;
  clear) [ -n "${2:-}" ] || { echo "flag name required" >&2; exit 1; }; rm -f "$dir/$2"; echo "cleared $2" ;;
  has) [ -f "$dir/${2:-}" ] ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
