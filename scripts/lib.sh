# Shared helpers for the sdd-* scripts. Sourced, not executed. Requires `gh` authenticated.
set -euo pipefail

die() { printf 'sdd: %s\n' "$*" >&2; exit 1; }

SDD_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

repo() {
  # nameWithOwner of the repo in the current directory, or $SDD_REPO if set
  if [ -n "${SDD_REPO:-}" ]; then printf '%s' "$SDD_REPO"; return; fi
  gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || die "not inside a GitHub repository (set SDD_REPO=owner/name)"
}

org() { repo | cut -d/ -f1; }

# Per-repository scratch directory outside the repository: ~/.sdd/<owner>-<repo>/ (flags, review packs, run logs,
# await marks, current issue). Slug from the git remote (no network), same as the hooks and `sdd flag`.
repo_slug() {
  local url; url="${SDD_REPO:-}"
  [ -n "$url" ] || { url="$(git config --get remote.origin.url 2>/dev/null || true)"; url="${url%.git}"; url="${url##*github.com[:/]}"; }
  [ -n "$url" ] || url="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  printf '%s' "${url//\//-}"
}
sdd_home() { local d; d="${SDD_HOME:-$HOME/.sdd}/$(repo_slug)"; mkdir -p "$d"; printf '%s' "$d"; }

STATES="triage ready spec spec-approved design design-approved task task-approved implementing in-review rework final-review"
TYPES="Feature Change Bug Task Constitution"
PHASES="triage spec design task implement review learning"

is_state() { for s in $STATES; do [ "$s" = "$1" ] && return 0; done; return 1; }
is_type()  { for t in $TYPES;  do [ "$t" = "$1" ] && return 0; done; return 1; }

need_issue() { [ "${1:-}" ] || die "issue number required"; printf '%s' "$1" | grep -Eq '^[0-9]+$' || die "issue must be a number: $1"; }

# ── .sdd/config.yml ──────────────────────────────────────────────────────────────────────────────
# cfg <key> [default] → the value (scalar, or list one per line); the default when the file or key is missing
cfg() { bash "$SDD_SCRIPTS/config.sh" get "$1" 2>/dev/null || printf '%s\n' "${2:-}"; }

constitution_lang() { cfg language en | head -1; }
rework_budget() { cfg gates.rework_budget 3 | head -1; }
warnings_policy() { cfg gates.warnings_at_final human | head -1; }
model_for() { cfg "models.$1" inherit | head -1; }

delegated_gates() {
  # `gates.delegated` of .sdd/config.yml: human approval gates /sdd may grant on its own.
  # Prints one gate per line as `<Gate> <plain|judged>`; nothing when the list is empty.
  cfg gates.delegated "" | while read -r g; do
    g="$(printf '%s' "$g" | sed 's/[`*"]//g; s/^ *//; s/ *$//')"; [ -n "$g" ] || continue
    mode=plain; case "$g" in *"(judged)"*) mode=judged; g="$(printf '%s' "$g" | sed 's/ *(judged)//')";; esac
    case "$g" in Intake|Spec|Design|Task|Final) printf '%s %s\n' "$g" "$mode";; esac
  done
}

# The next state a human approval produces from the current one (empty when the state is not a gate)
approved_state_after() {
  case "$1" in
    triage) echo ready;; spec) echo spec-approved;; design) echo design-approved;; task) echo task-approved;;
    final-review) echo merge;; *) echo "";;
  esac
}
