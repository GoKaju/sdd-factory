#!/usr/bin/env bash
# Waits for a human on an issue without an agent turn: pure bash polling of GitHub. /sdd calls it after a
# phase whose gate is not delegated and reacts to the one JSON event it prints.
#
#   sdd await mark <issue>                         → remembers the newest comment on the issue and its PR; call it right after
#                                                    a phase finishes so the phase's own comments are never reported as human input
#   sdd await <issue> [--timeout <s>] [--interval <s>]
#       → polls every --interval seconds (default: await.interval_seconds of .sdd/config.yml, 30) for at most --timeout
#         seconds (default 590: the host's Bash tool allows 600) and prints ONE JSON line, then exits:
#         {"event":"approved","state":"<new state>","by":"<login>"}   a human set the next state label, or commented `/approve`
#                                                                     (write permission required; the label is set here)
#         {"event":"merge","by":"<login>"}                            `/approve` while in final-review: the human asks to merge
#         {"event":"state","state":"<new state>"}                     any other sdd:* label change (e.g. a human sent it back)
#         {"event":"rework","comment":<id>,"by":"<login>"}            a `/rework` comment on the issue or the PR
#         {"event":"comment","comment":<id>,"by":"<login>","on":"issue|pr","body":"..."}   any other human comment
#         {"event":"merged"} | {"event":"pr-closed"} | {"event":"closed"}                  the PR was merged / closed, the issue closed
#         {"event":"timeout","waited":<s>}                             nothing happened (exit 3)
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"

cmd="${1:-}"; [ "$cmd" = mark ] && shift
need_issue "${1:-}"; issue="$1"; shift
r="$(repo)"; home="$(sdd_home)"; markf="$home/await-$issue.mark"
timeout=590; interval="$(cfg await.interval_seconds 30 | head -1)"
while [ $# -gt 0 ]; do case "$1" in --timeout) timeout="$2"; shift 2;; --interval) interval="$2"; shift 2;; *) die "unknown option $1";; esac; done

pr="$("$S/pr.sh" find "$issue" 2>/dev/null || true)"
json() { python3 -c 'import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2])), ensure_ascii=False))' "$@"; }
# The issue-comments endpoint ignores sort/direction: paginate everything and take the highest id.
newest_comment() { # highest comment id across the issue and its PR
  { gh api "repos/$r/issues/$issue/comments?per_page=100" --paginate --jq '[.[].id] | max // 0' 2>/dev/null
    [ -n "$pr" ] && gh api "repos/$r/issues/$pr/comments?per_page=100" --paginate --jq '[.[].id] | max // 0' 2>/dev/null; true
  } | sort -n | tail -1; }
can_approve() { gh api "repos/$r/collaborators/$1/permission" --jq .permission 2>/dev/null | grep -Eq '^(admin|write|maintain)$'; }

if [ "$cmd" = mark ]; then newest_comment > "$markf"; printf 'mark %s\n' "$(cat "$markf")"; exit 0; fi

since="$( [ -f "$markf" ] && cat "$markf" || newest_comment )"; since="${since:-0}"
state0="$("$S/state.sh" get "$issue")"
start="$(date +%s)"

while :; do
  # 1. issue / PR closed or merged
  st="$(gh api "repos/$r/issues/$issue" --jq '.state' 2>/dev/null || echo open)"
  [ "$st" = closed ] && { json event closed; exit 0; }
  if [ -n "$pr" ]; then
    prst="$(gh pr view "$pr" --repo "$r" --json state -q .state 2>/dev/null || echo OPEN)"
    [ "$prst" = MERGED ] && { json event merged; exit 0; }
    [ "$prst" = CLOSED ] && { json event pr-closed; exit 0; }
  fi
  # 2. state label
  state="$("$S/state.sh" get "$issue")"
  if [ "$state" != "$state0" ]; then
    if [ "$state" = "$(approved_state_after "$state0")" ]; then json event approved state "$state" by label; else json event state state "$state"; fi
    exit 0
  fi
  # 3. the oldest new human comment (id > mark) on the issue or the PR
  evt="$(mktemp)"
  for t in "$issue" ${pr:+$pr}; do
    on=issue; [ -n "$pr" ] && [ "$t" = "$pr" ] && [ "$t" != "$issue" ] && on=pr
    gh api "repos/$r/issues/$t/comments?per_page=100" --paginate \
      --jq ".[] | select(.id > $since) | select(.user.type != \"Bot\") | select(.body | startswith(\"<!-- sdd:\") | not) | \"\(.id)\t\(.user.login)\t\(.body | gsub(\"[\\n\\r\\t]\"; \" \") | .[0:400])\"" 2>/dev/null \
      | sort -n | head -1 | while IFS="$(printf '\t')" read -r id who body; do
          printf '%s\n' "$id" > "$markf"
          case "$body" in
            /approve*)
              if ! can_approve "$who"; then json event comment comment "$id" by "$who" on "$on" body "$body (no write permission: /approve ignored)"
              else
                next="$(approved_state_after "$state0")"
                if [ -z "$next" ]; then json event comment comment "$id" by "$who" on "$on" body "$body"
                elif [ "$next" = merge ]; then json event merge by "$who"
                else "$S/state.sh" set "$issue" "$next" >/dev/null; json event approved state "$next" by "$who"; fi
              fi ;;
            /rework*) json event rework comment "$id" by "$who" ;;
            *) json event comment comment "$id" by "$who" on "$on" body "$body" ;;
          esac
        done > "$evt"
    [ -s "$evt" ] && { cat "$evt"; rm -f "$evt"; exit 0; }
  done
  rm -f "$evt"
  # 4. timeout
  now="$(date +%s)"; [ $((now - start + interval)) -gt "$timeout" ] && { json event timeout waited "$((now - start))"; exit 3; }
  sleep "$interval"
done
