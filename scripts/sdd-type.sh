#!/usr/bin/env bash
# Native GitHub Issue Type of an issue (organization repositories only).
#
#   sdd-type.sh get <issue>          → prints Feature | Change | Bug | Task | Constitution (empty if none)
#   sdd-type.sh set <issue> <type>   → assigns the type (the type must exist in the organization)
#   sdd-type.sh require <issue> <type>...
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; shift || true
case "$cmd" in
  get)
    need_issue "${1:-}"
    gh api "repos/$(repo)/issues/$1" --jq '.type.name // empty'
    ;;
  set)
    need_issue "${1:-}"; is_type "${2:-}" || die "unknown type '${2:-}'. Valid: $TYPES"
    gh api -X PATCH "repos/$(repo)/issues/$1" -f "type=$2" --jq '.type.name'
    ;;
  require)
    need_issue "${1:-}"; issue="$1"; shift
    current="$("$0" get "$issue")"
    for t in "$@"; do [ "$current" = "$t" ] && exit 0; done
    die "issue #$issue has type '${current:-none}'; expected one of: $*"
    ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
