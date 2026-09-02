#!/usr/bin/env bash
# The Draft PR linked to an issue ("Closes #N" on the first line of the body).
#
#   sdd-pr.sh find   <issue>                     → prints the PR number, or nothing
#   sdd-pr.sh open   <issue> <branch> <title>    → pushes the branch and opens the Draft PR with "Closes #N"
#   sdd-pr.sh ready  <issue>                     → marks the linked PR ready for review
#   sdd-pr.sh branch <issue>                     → prints the linked PR's head branch
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; r="$(repo)"

find_pr() { gh pr list --repo "$r" --state open --search "Closes #$issue in:body" --json number,body -q ".[] | select(.body | test(\"(?m)^Closes #$issue\\\\b\")) | .number" | head -1; }

case "$cmd" in
  find) find_pr ;;
  branch) n="$(find_pr)"; [ -n "$n" ] || die "no PR linked to #$issue"; gh pr view "$n" --repo "$r" --json headRefName -q .headRefName ;;
  open)
    branch="${3:-}"; title="${4:-}"; [ -n "$branch" ] && [ -n "$title" ] || die "branch and title required"
    case "$branch" in main|master) die "refusing to open a PR from $branch";; esac
    existing="$(find_pr)"; [ -z "$existing" ] || { printf '%s\n' "$existing"; exit 0; }
    git push -u origin "$branch" >/dev/null 2>&1 || git push -u origin "$branch"
    body="$(printf 'Closes #%s\n\n## Resumen\n\n_Generado por sdd-factory; se completa al final de la implementación._\n' "$issue")"
    gh pr create --repo "$r" --draft --head "$branch" --title "$title" --body "$body" >/dev/null
    find_pr
    ;;
  ready) n="$(find_pr)"; [ -n "$n" ] || die "no PR linked to #$issue"; gh pr ready "$n" --repo "$r" && printf '%s\n' "$n" ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
