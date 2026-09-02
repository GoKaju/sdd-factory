#!/usr/bin/env bash
# Ensures the five SDD Issue Types exist in the organization. Feature, Bug and Task are GitHub
# defaults; Change and Constitution are created here (organization admin required).
#
#   sdd-org-types.sh ensure [org]    → creates the missing types; prints one line per type
#   sdd-org-types.sh list   [org]
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; o="${2:-$(org)}"

existing() { gh api "orgs/$o/issue-types" --jq '.[] | select(.is_enabled) | .name' 2>/dev/null; }

case "$cmd" in
  list) existing ;;
  ensure)
    have="$(existing)" || die "cannot read issue types of '$o'. Is it an organization? Issue Types do not exist on personal accounts."
    if ! gh api -i user 2>/dev/null | grep -i '^x-oauth-scopes' | grep -q 'admin:org'; then
      printf 'NOTE     creating types needs the admin:org scope on your gh token. Run once:\n         gh auth refresh -h github.com -s admin:org\n'
    fi
    create() {
      out="$(gh api -X POST "orgs/$o/issue-types" -f "name=$1" -f "description=$2" -F is_enabled=true -f "color=$3" 2>&1)" \
        && printf 'created  %s\n' "$1" \
        || printf 'MANUAL   %s — %s\n         create it at https://github.com/organizations/%s/settings/issue-types (name: %s, description: %s)\n' \
             "$1" "$(printf '%s' "$out" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p' | head -1)" "$o" "$1" "$2"
    }
    for t in $TYPES; do
      if printf '%s\n' "$have" | grep -qx "$t"; then printf 'exists   %s\n' "$t"; else
        case "$t" in
          Change)       create Change "Modify behavior the system already has (updates an approved Spec)" blue ;;
          Constitution) create Constitution "Amendment to docs/constitution.md" purple ;;
          *)            printf 'MANUAL   %s — default GitHub type is disabled; enable it in the organization settings\n' "$t" ;;
        esac
      fi
    done
    ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
