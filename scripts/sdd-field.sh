#!/usr/bin/env bash
# Organization-level Issue Fields (GitHub GraphQL: issueFields / setIssueFieldValue).
# Single-select fields only (Effort, Priority, …). Values set by an agent go in as SUGGESTIONS by
# default so a human accepts them in the UI; pass --apply to set the value directly.
#
#   sdd-field.sh list                                   → fields of the organization with their options
#   sdd-field.sh get <issue> <field>                    → current value (or empty)
#   sdd-field.sh set <issue> <field> <option> [--apply] [--rationale "<≤280 chars>"] [--confidence LOW|MEDIUM|HIGH]
. "$(dirname "$0")/lib.sh"

gql() { gh api graphql "$@"; }
org_fields() {
  gql -f query="{ organization(login:\"$(org)\") { issueFields(first:50) { nodes { __typename ... on IssueFieldSingleSelect { id name options { id name } } } } } }" \
    --jq '.data.organization.issueFields.nodes[] | select(.__typename=="IssueFieldSingleSelect")'
}
field_json() { org_fields | jq -c "select(.name==\"$1\")" | head -1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  list) org_fields | jq -r '"\(.name): \([.options[].name] | join(", "))"' ;;
  get)
    need_issue "${1:-}"; [ -n "${2:-}" ] || die "field name required"
    gql -f query="{ repository(owner:\"$(org)\", name:\"$(repo | cut -d/ -f2)\") { issue(number:$1) { issueFieldValues(first:20) { nodes { ... on IssueFieldSingleSelectValue { name field { ... on IssueFieldSingleSelect { name } } } } } } } }" \
      --jq ".data.repository.issue.issueFieldValues.nodes[] | select(.field.name==\"$2\") | .name"
    ;;
  set)
    need_issue "${1:-}"; issue="$1"; field="${2:-}"; option="${3:-}"; shift 3 || die "usage: set <issue> <field> <option>"
    [ -n "$field" ] && [ -n "$option" ] || die "field and option required"
    suggest=true; rationale=""; confidence="MEDIUM"
    while [ $# -gt 0 ]; do case "$1" in
      --apply) suggest=false; shift ;;
      --rationale) rationale="${2:-}"; shift 2 ;;
      --confidence) confidence="${2:-MEDIUM}"; shift 2 ;;
      *) die "unknown flag $1" ;;
    esac; done
    f="$(field_json "$field")"; [ -n "$f" ] || die "the organization has no single-select issue field named '$field' (see: sdd-field.sh list)"
    fid="$(printf '%s' "$f" | jq -r .id)"; oid="$(printf '%s' "$f" | jq -r ".options[] | select(.name==\"$option\") | .id")"
    [ -n "$oid" ] || die "field '$field' has no option '$option' (options: $(printf '%s' "$f" | jq -r '[.options[].name] | join(", ")'))"
    node_id="$(gh api "repos/$(repo)/issues/$issue" --jq .node_id)"
    rationale="${rationale:0:280}"
    gql -f query='mutation($issueId: ID!, $fieldId: ID!, $optionId: ID!, $suggest: Boolean!, $rationale: String, $confidence: IssueEventConfidenceLevel) {
        setIssueFieldValue(input: { issueId: $issueId, issueFields: [{ fieldId: $fieldId, singleSelectOptionId: $optionId, suggest: $suggest, rationale: $rationale, confidence: $confidence }] }) { clientMutationId } }' \
      -f issueId="$node_id" -f fieldId="$fid" -f optionId="$oid" -F suggest="$suggest" -f rationale="$rationale" -f confidence="$confidence" >/dev/null
    printf '%s %s=%s (%s)\n' "#$issue" "$field" "$option" "$([ "$suggest" = true ] && echo suggested || echo applied)"
    ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
