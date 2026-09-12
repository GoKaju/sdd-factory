# Shared helpers for the sdd-* scripts. Sourced, not executed. Requires `gh` authenticated.
set -euo pipefail

die() { printf 'sdd: %s\n' "$*" >&2; exit 1; }

SDD_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

repo() {
  # owner/name of the repository in the current directory, or $SDD_REPO if set. Read from the git remote, never from
  # the network: `gh repo view` goes through GraphQL, which some sandboxes block; only REST (`gh api repos/…`) is used.
  if [ -n "${SDD_REPO:-}" ]; then printf '%s' "$SDD_REPO"; return; fi
  local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
  url="${url%.git}"; url="${url%/}"
  case "$url" in
    *github.com[:/]*) url="${url##*github.com[:/]}" ;;
    *) url="" ;;
  esac
  [ -n "$url" ] && printf '%s' "$url" || die "not inside a GitHub repository (set SDD_REPO=owner/name)"
}

# ── GitHub through REST only ─────────────────────────────────────────────────────────────────────
# Every GitHub call of the factory is `gh api` on a REST endpoint. The `gh issue|pr|label|repo` subcommands are
# GraphQL underneath (api.github.com/graphql), and Claude's cloud sandboxes block that endpoint while allowing REST.
urlenc() { printf '%s' "$1" | python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))'; }
issue_labels() { gh api "repos/$(repo)/issues/$1" --jq '.labels[].name'; }                 # one label per line
issue_state()  { gh api "repos/$(repo)/issues/$1" --jq '.state'; }                         # open | closed
pr_state()     { gh api "repos/$(repo)/pulls/$1" --jq 'if .merged then "MERGED" elif .state == "closed" then "CLOSED" else "OPEN" end'; }
default_branch() { gh api "repos/$(repo)" --jq '.default_branch'; }

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
