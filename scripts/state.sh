#!/usr/bin/env bash
# SDD workflow state of an issue, stored as an exclusive `sdd:<state>` label.
#
#   sdd state get <issue>                 → prints the state (empty if none)
#   sdd state set <issue> <state>         → replaces any sdd:* label with sdd:<state>
#   sdd state require <issue> <state>...  → exit 1 unless current state is one of the given
#   sdd state ensure-labels               → creates every sdd:* label in the repo (idempotent)
#   sdd state list                        → prints the canonical state sequence
. "$(dirname "$0")/lib.sh"

label_color() {
  case "$1" in
    triage) echo "ededed";; ready) echo "c2e0c6";;
    spec|design|task) echo "fef2c0";; *-approved) echo "0e8a16";;
    implementing) echo "1d76db";; in-review) echo "5319e7";; rework) echo "d93f0b";; final-review) echo "b60205";;
    *) echo "cccccc";;
  esac
}

# Create or update the sdd:<state> label (REST: GET → POST | PATCH); idempotent.
ensure_label() {
  local r; r="$(repo)"
  if gh api "repos/$r/labels/$(urlenc "sdd:$1")" >/dev/null 2>&1; then
    gh api -X PATCH "repos/$r/labels/$(urlenc "sdd:$1")" -f "color=$(label_color "$1")" -f "description=SDD state: $1" >/dev/null
  else
    gh api -X POST "repos/$r/labels" -f "name=sdd:$1" -f "color=$(label_color "$1")" -f "description=SDD state: $1" >/dev/null
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  get)
    need_issue "${1:-}"
    # Several sdd:* labels can coexist for a moment while a human adds the next state before
    # removing the previous one; report the most advanced one in the canonical order.
    found="$(issue_labels "$1" | sed -n 's/^sdd://p')"
    best=""; for s in $STATES; do printf '%s\n' "$found" | grep -qx "$s" && best="$s"; done
    [ -n "$best" ] && printf '%s\n' "$best"; exit 0
    ;;
  set)
    need_issue "${1:-}"; is_state "${2:-}" || die "unknown state '${2:-}'. Valid: $STATES"
    r="$(repo)"; ensure_label "$2"
    current="$(issue_labels "$1" | grep '^sdd:' || true)"
    gh api -X POST "repos/$r/issues/$1/labels" -f "labels[]=sdd:$2" >/dev/null
    for l in $current; do [ "$l" != "sdd:$2" ] && { gh api -X DELETE "repos/$r/issues/$1/labels/$(urlenc "$l")" >/dev/null 2>&1 || true; }; done
    printf '%s\n' "$2"
    ;;
  require)
    need_issue "${1:-}"; issue="$1"; shift
    current="$("$0" get "$issue")"
    for s in "$@"; do [ "$current" = "$s" ] && exit 0; done
    die "issue #$issue is in state '${current:-none}'; this phase requires: $*"
    ;;
  ensure-labels)
    r="$(repo)"
    for s in $STATES; do ensure_label "$s" && printf 'label sdd:%s\n' "$s"; done
    ;;
  list) printf '%s\n' $STATES ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
