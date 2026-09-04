#!/usr/bin/env bash
# SDD workflow state of an issue, stored as an exclusive `sdd:<state>` label.
#
#   sdd-state.sh get <issue>                 → prints the state (empty if none)
#   sdd-state.sh set <issue> <state>         → replaces any sdd:* label with sdd:<state>
#   sdd-state.sh require <issue> <state>...  → exit 1 unless current state is one of the given
#   sdd-state.sh ensure-labels               → creates every sdd:* label in the repo (idempotent)
#   sdd-state.sh working <issue> on|off      → activity marker `sdd:working` (worker running a phase); not a state
#   sdd-state.sh list                        → prints the canonical state sequence
. "$(dirname "$0")/lib.sh"

label_color() {
  case "$1" in
    triage) echo "ededed";; ready) echo "c2e0c6";;
    spec|design|task) echo "fef2c0";; *-approved) echo "0e8a16";;
    implementing) echo "1d76db";; in-review) echo "5319e7";; rework) echo "d93f0b";; final-review) echo "b60205";;
    *) echo "cccccc";;
  esac
}

cmd="${1:-}"; shift || true
case "$cmd" in
  get)
    need_issue "${1:-}"
    # Several sdd:* labels can coexist for a moment while a human adds the next state before
    # removing the previous one; report the most advanced one in the canonical order.
    found="$(gh issue view "$1" --repo "$(repo)" --json labels -q '.labels[].name' | sed -n 's/^sdd://p')"
    best=""; for s in $STATES; do printf '%s\n' "$found" | grep -qx "$s" && best="$s"; done
    [ -n "$best" ] && printf '%s\n' "$best"
    ;;
  set)
    need_issue "${1:-}"; is_state "${2:-}" || die "unknown state '${2:-}'. Valid: $STATES"
    r="$(repo)"
    gh label create "sdd:$2" --repo "$r" --color "$(label_color "$2")" --description "SDD state: $2" --force >/dev/null
    current="$(gh issue view "$1" --repo "$r" --json labels -q '.labels[].name' | grep '^sdd:' || true)"
    args=(--add-label "sdd:$2")
    # sdd:working is an activity marker set by the worker, not a state: never remove it here.
    for l in $current; do [ "$l" != "sdd:$2" ] && [ "$l" != "sdd:working" ] && args+=(--remove-label "$l"); done
    gh issue edit "$1" --repo "$r" "${args[@]}" >/dev/null
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
    for s in $STATES; do gh label create "sdd:$s" --repo "$r" --color "$(label_color "$s")" --description "SDD state: $s" --force >/dev/null && printf 'label sdd:%s\n' "$s"; done
    gh label create "sdd:working" --repo "$r" --color "fbca04" --description "SDD: the worker is running a phase on this issue" --force >/dev/null && printf 'label sdd:working\n'
    ;;
  working)
    # working <issue> on|off — activity marker used by the worker; independent of the state label
    need_issue "${1:-}"; r="$(repo)"
    gh label create "sdd:working" --repo "$r" --color "fbca04" --description "SDD: the worker is running a phase on this issue" --force >/dev/null
    if [ "${2:-}" = "on" ]; then gh issue edit "$1" --repo "$r" --add-label "sdd:working" >/dev/null
    else gh issue edit "$1" --repo "$r" --remove-label "sdd:working" >/dev/null 2>&1 || true; fi
    ;;
  list) printf '%s\n' $STATES ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
