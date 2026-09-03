#!/usr/bin/env bash
# Marked comments on an issue: exactly one comment per marker, created once and edited afterwards.
# Markers used by the factory: sdd:triage, sdd:task
#
#   sdd-comment.sh find   <issue> <marker>           → prints the comment id, or nothing
#   sdd-comment.sh get    <issue> <marker>           → prints the comment body
#   sdd-comment.sh upsert <issue> <marker> <file>    → creates or edits the comment with the file's body
#   sdd-comment.sh check  <issue> <marker> <T7>      → ticks the step whose line carries **T7**; refuses if an
#                                                      earlier step is still unchecked (steps are done in order)
#   sdd-comment.sh next   <issue> <marker>           → prints the id of the first unchecked step (empty if none)
#   sdd-comment.sh open   <issue> <marker>           → prints the number of unchecked boxes
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; marker="${3:-}"; [ -n "$marker" ] || die "marker required (e.g. sdd:task)"
r="$(repo)"; tag="<!-- $marker -->"

find_id() { gh api "repos/$r/issues/$issue/comments" --paginate --jq ".[] | select(.body | startswith(\"$tag\")) | .id" | head -1; }
body_of() { gh api "repos/$r/issues/comments/$1" --jq .body; }

case "$cmd" in
  find) find_id ;;
  get) id="$(find_id)"; [ -n "$id" ] || die "no $marker comment on #$issue"; body_of "$id" ;;
  upsert)
    f="${4:-}"; [ -f "$f" ] || die "body file required"
    head -1 "$f" | grep -qF "$tag" || die "body must start with '$tag'"
    id="$(find_id)"
    if [ -n "$id" ]; then gh api -X PATCH "repos/$r/issues/comments/$id" -F body=@"$f" --jq .id
    else gh api -X POST "repos/$r/issues/$issue/comments" -F body=@"$f" --jq .id; fi
    ;;
  check)
    step="${4:-}"; printf '%s' "$step" | grep -Eq '^T[0-9]+$' || die "step id required, e.g. T7 (steps are ticked by identifier, never by position)"
    id="$(find_id)"; [ -n "$id" ] || die "no $marker comment on #$issue"
    body="$(body_of "$id")"
    printf '%s\n' "$body" | grep -Eq "^- \[[ x]\] \*\*$step\*\*" || die "no step $step in the $marker comment"
    printf '%s\n' "$body" | grep -Eq "^- \[x\] \*\*$step\*\*" && { printf '%s already ticked\n' "$step"; exit 0; }
    earlier="$(printf '%s\n' "$body" | awk -v s="$step" '/^- \[ \] \*\*T[0-9]+\*\*/ { match($0, /T[0-9]+/); t=substr($0, RSTART, RLENGTH); if (t==s) exit; print t }' | head -1)"
    [ -z "$earlier" ] || die "cannot tick $step: $earlier is still unchecked. Steps are completed in order."
    tmp="$(mktemp)"; printf '%s\n' "$body" | awk -v s="$step" 'index($0, "- [ ] **" s "**")==1 { sub(/^- \[ \]/, "- [x]") } { print }' > "$tmp"
    gh api -X PATCH "repos/$r/issues/comments/$id" -F body=@"$tmp" --jq .id >/dev/null; rm -f "$tmp"; printf '%s ticked\n' "$step"
    ;;
  next)
    id="$(find_id)"; [ -n "$id" ] || die "no $marker comment on #$issue"
    body_of "$id" | grep -Eo '^- \[ \] \*\*T[0-9]+\*\*' | head -1 | grep -Eo 'T[0-9]+' || true
    ;;
  open) id="$(find_id)"; [ -n "$id" ] || { echo 0; exit 0; }; body_of "$id" | grep -c '^- \[ \]' || true ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
