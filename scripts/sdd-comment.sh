#!/usr/bin/env bash
# Marked comments on an issue: exactly one comment per marker, created once and edited afterwards.
# Markers used by the factory: sdd:triage, sdd:task
#
#   sdd-comment.sh find   <issue> <marker>           → prints the comment id, or nothing
#   sdd-comment.sh get    <issue> <marker>           → prints the comment body
#   sdd-comment.sh upsert <issue> <marker> <file>    → creates or edits the comment with the file's body
#   sdd-comment.sh check  <issue> <marker> <n>       → ticks the n-th checkbox ("- [ ]" → "- [x]")
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
    n="${4:-}"; printf '%s' "$n" | grep -Eq '^[0-9]+$' || die "checkbox index required"
    id="$(find_id)"; [ -n "$id" ] || die "no $marker comment on #$issue"
    tmp="$(mktemp)"; body_of "$id" | awk -v n="$n" '/^- \[ \]/ { c++; if (c==n) sub(/^- \[ \]/, "- [x]") } { print }' > "$tmp"
    gh api -X PATCH "repos/$r/issues/comments/$id" -F body=@"$tmp" --jq .id; rm -f "$tmp"
    ;;
  open) id="$(find_id)"; [ -n "$id" ] || { echo 0; exit 0; }; body_of "$id" | grep -c '^- \[ \]' || true ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
