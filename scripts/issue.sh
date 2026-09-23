#!/usr/bin/env bash
# An issue's title, body and comments through the REST API. `gh issue view N --comments` returns nothing in some
# repositories and gh versions; every phase reads the issue through this command instead.
#
#   sdd issue show <issue>   → title, state, labels, body, then every comment (author, date, body), oldest first
. "$(dirname "$0")/lib.sh"
cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; r="$(repo)"
case "$cmd" in
  show)
    gh api "repos/$r/issues/$issue" --jq '"# #\(.number) \(.title)\nstate: \(.state) · labels: \([.labels[].name] | join(", "))\n\n\(.body // "")"'
    gh api "repos/$r/issues/$issue/comments" --paginate --jq '.[] | "\n---\n**@\(.user.login)** · \(.created_at)\n\n\(.body)"'
    ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
