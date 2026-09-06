#!/usr/bin/env bash
# Approval Gate 4 feedback: a human writes a `/rework` comment on the PR (or the issue) listing what
# must change — typically WARNINGs of the Review Gates they refuse to accept. The orchestrator turns
# each bullet into a new step of the Task comment and sends the issue back to `rework`, so
# /sdd-implement does exactly those steps and /sdd-review runs again. Nothing else is touched.
#
#   /rework                                 ← first line of the comment
#   - move TaskStatus to value-objects/     ← one bullet per step (also "* " or "1. ")
#   - split infrastructure/in-memory/       …
#
#   sdd-rework.sh pending <issue>   → one line per unapplied /rework comment: "<comment-id> <author>"
#   sdd-rework.sh apply   <issue>   → appends the steps to the Task, marks the comments applied (👀 by the
#                                     orchestrator account), sets sdd:rework. Idempotent; requires final-review.
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; r="$(repo)"
me="$(gh api user --jq .login)"

# Comments on the issue and on its linked PR (a PR is an issue for the comments API).
targets() { printf '%s\n' "$issue"; pr="$("$S/sdd-pr.sh" find "$issue" 2>/dev/null || true)"; [ -n "$pr" ] && printf '%s\n' "$pr"; }

applied() { gh api "repos/$r/issues/comments/$1/reactions" --jq ".[] | select(.content==\"eyes\" and .user.login==\"$me\") | .id" | grep -q .; }

pending() {
  for t in $(targets); do
    gh api "repos/$r/issues/$t/comments" --paginate \
      --jq '.[] | select(.user.type != "Bot") | select(.body | test("^\\s*/rework(\\s|$)")) | "\(.id) \(.user.login)"'
  done | while read -r id author; do applied "$id" || printf '%s %s\n' "$id" "$author"; done
}

steps_of() { # bullets after the /rework line, trimmed, one per line
  gh api "repos/$r/issues/comments/$1" --jq .body | awk '
    NR==1 && $0 ~ /^[[:space:]]*\/rework/ { next }
    /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+/ { sub(/^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]+/, ""); if (length($0)) print }'
}

case "$cmd" in
  pending) pending ;;
  apply)
    "$S/sdd-state.sh" require "$issue" final-review >/dev/null
    list="$(pending)"; [ -n "$list" ] || { echo "nothing pending"; exit 0; }
    task_id="$("$S/sdd-comment.sh" find "$issue" sdd:task)"; [ -n "$task_id" ] || die "no Task comment on #$issue; a /rework needs a Task to extend"
    body="$(gh api "repos/$r/issues/comments/$task_id" --jq .body)"
    last="$(printf '%s\n' "$body" | grep -Eo '^- \[[ x]\] \*\*T[0-9]+\*\*' | grep -Eo '[0-9]+' | sort -n | tail -1)"; n="${last:-0}"
    steps="$(mktemp)"
    printf '%s\n' "$list" | while read -r id author; do steps_of "$id" | sed "s/$/\t$author/"; done > "$steps"
    [ -s "$steps" ] || die "the /rework comment(s) carry no bullet; nothing to add"
    tmp="$(mktemp)"; printf '%s\n' "$body" > "$tmp"
    while IFS="$(printf '\t')" read -r step author; do n=$((n+1)); printf -- '- [ ] **T%s** %s _(Gate 4, @%s)_\n' "$n" "$step" "$author" >> "$tmp"; done < "$steps"
    "$S/sdd-comment.sh" upsert "$issue" sdd:task "$tmp" >/dev/null
    printf '%s\n' "$list" | while read -r id author; do gh api -X POST "repos/$r/issues/comments/$id/reactions" -f content=eyes --jq .id >/dev/null; done
    "$S/sdd-state.sh" set "$issue" rework
    printf 'added %s step(s) to the Task of #%s from /rework; state -> rework\n' "$(wc -l < "$steps" | tr -d ' ')" "$issue"; rm -f "$steps" "$tmp"
    ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
