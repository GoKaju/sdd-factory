#!/usr/bin/env bash
# Issues through REST only (`gh api`): what agents used to read with `gh issue view|list`, which are GraphQL underneath.
#
#   sdd issue show   <issue>            → title, state, type, labels, author, body and every comment, as text
#   sdd issue state  <issue>            → open | closed
#   sdd issue view   <issue> [jq]       → the issue as JSON (REST `issues/N`), or one field with a jq filter
#   sdd issue list   [open|closed|all]  → "number<TAB>state<TAB>title" per issue (no pull requests), default open
#   sdd issue search "<query>"          → "number<TAB>state<TAB>title" per match, issues of this repository only
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; r="$(repo)"
row='.[] | select(.pull_request | not) | "\(.number)\t\(.state)\t\(.title)"'

case "$cmd" in
  state) need_issue "${2:-}"; issue_state "$2" ;;
  view) need_issue "${2:-}"; gh api "repos/$r/issues/$2" ${3:+--jq "$3"} ;;
  show)
    need_issue "${2:-}"
    gh api "repos/$r/issues/$2" --jq '"# #\(.number) \(.title)\nstate: \(.state) · type: \(.type.name // "-") · labels: \((.labels | map(.name)) | join(", ")) · author: \(.user.login) · updated: \(.updated_at)\n\n\(.body // "")\n"'
    gh api "repos/$r/issues/$2/comments?per_page=100" --paginate --jq '.[] | "--- \(.user.login) · \(.created_at)\n\(.body)\n"'
    ;;
  list) st="${2:-open}"; gh api "repos/$r/issues?state=$st&per_page=100" --paginate --jq "$row" ;;
  search)
    q="${2:-}"; [ -n "$q" ] || die "query required"
    gh api --method GET search/issues -f q="repo:$r is:issue $q" --jq '.items[] | "\(.number)\t\(.state)\t\(.title)"'
    ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
