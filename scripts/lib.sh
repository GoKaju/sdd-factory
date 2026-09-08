# Shared helpers for the sdd-* scripts. Sourced, not executed. Requires `gh` authenticated.
set -euo pipefail

die() { printf 'sdd: %s\n' "$*" >&2; exit 1; }

repo() {
  # nameWithOwner of the repo in the current directory, or $SDD_REPO if set
  if [ -n "${SDD_REPO:-}" ]; then printf '%s' "$SDD_REPO"; return; fi
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || die "not inside a GitHub repository (set SDD_REPO=owner/name)"
}

org() { repo | cut -d/ -f1; }

STATES="triage ready spec spec-approved design design-approved task task-approved implementing in-review rework final-review"
TYPES="Feature Change Bug Task Constitution"

is_state() { for s in $STATES; do [ "$s" = "$1" ] && return 0; done; return 1; }
is_type()  { for t in $TYPES;  do [ "$t" = "$1" ] && return 0; done; return 1; }

need_issue() { [ "${1:-}" ] || die "issue number required"; printf '%s' "$1" | grep -Eq '^[0-9]+$' || die "issue must be a number: $1"; }

constitution_lang() {
  # `Language` of docs/constitution.md (Identity section): en | es; default en
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  { grep -oE '\*\*Language:\*\*[[:space:]]*(en|es)' "$root/docs/constitution.md" 2>/dev/null || true; } | grep -oE '(en|es)$' | head -1 | grep . || printf 'en'
}

rework_budget() {
  # `Rework budget` of docs/constitution.md (Verification section); default 3
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  { grep -oE '\*\*Rework budget:\*\*[[:space:]]*[0-9]+' "$root/docs/constitution.md" 2>/dev/null || true; } | grep -oE '[0-9]+$' | head -1 | grep . || printf '3'
}
