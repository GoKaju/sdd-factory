#!/usr/bin/env bash
# sdd-factory installer: checks the prerequisites, installs the skills for your agent, puts a stable
# `sdd` on this machine and, when Orca is present, creates the scheduled automation that orchestrates
# one repository. Idempotent: run it again after an update or for another repository.
#
#   curl -fsSL https://raw.githubusercontent.com/GoKaju/sdd-factory/main/install.sh | bash -s -- [options]
#   ./install.sh [options]
#
#   --repo <path>        repository to orchestrate (default: the current directory when it is a git repo)
#   --agent claude|skills  how to install the skills: Claude Code plugin (default) or `npx skills add`
#                        (any agent that reads SKILL.md: Codex, Cursor, OpenCode, Gemini…)
#   --every <minutes>    orchestration cadence (default 5)
#   --no-orca            skip the Orca part (skills and `sdd` only)
#   --enable             enable the automation right away (default: created disabled, you review and enable)
set -euo pipefail

REPO_URL="https://github.com/GoKaju/sdd-factory"
MARKETPLACE="GoKaju/sdd-factory"
PLUGIN="sdd-factory@sdd-factory"
SDD_HOME="${SDD_HOME:-$HOME/.sdd}"
repo=""; agent=claude; every=5; orca_on=1; enable=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --agent) agent="$2"; shift 2 ;;
    --every) every="$2"; shift 2 ;;
    --no-orca) orca_on=0; shift ;;
    --enable) enable=1; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✖\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── 1. Prerequisites ─────────────────────────────────────────────────────────────────────────────
step "1. Prerequisites"
have git || fail "git is required"; ok "git $(git --version | awk '{print $3}')"
have python3 || fail "python3 is required (sdd next uses it for JSON)"; ok "python3"
have gh || fail "GitHub CLI (gh) is required: https://cli.github.com"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated: run  gh auth login"
ok "gh authenticated as $(gh api user --jq .login)"
if [ "$agent" = claude ]; then
  have claude || fail "Claude Code CLI not found (npm i -g @anthropic-ai/claude-code), or use --agent skills"
  ok "claude $(claude --version 2>/dev/null | head -1)"
else
  have npx || fail "npx is required for --agent skills"; ok "npx"
fi
ORCA=""
if [ "$orca_on" = 1 ]; then
  if have orca && orca status --json >/dev/null 2>&1; then ORCA="$(command -v orca)"
  elif [ -x /Applications/Orca.app/Contents/Resources/bin/orca ]; then ORCA=/Applications/Orca.app/Contents/Resources/bin/orca
  fi
  if [ -z "$ORCA" ]; then warn "Orca CLI not found; skipping the automation (install Orca from https://www.onorca.dev, or pass --no-orca)"; orca_on=0
  else
    have orca && [ "$ORCA" != "$(command -v orca || true)" ] && warn "/usr/local/bin/orca is broken; using $ORCA"
    if "$ORCA" status --json 2>/dev/null | grep -q '"running": *true'; then ok "Orca runtime running ($ORCA)"
    else warn "Orca is installed but not running; open Orca (or  orca serve ) and re-run to create the automation"; orca_on=0; fi
  fi
fi

# ── 2. Skills ────────────────────────────────────────────────────────────────────────────────────
step "2. Skills ($agent)"
mkdir -p "$SDD_HOME/bin"
if [ "$agent" = claude ]; then
  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then ok "marketplace $MARKETPLACE already configured"
  else claude plugin marketplace add "$MARKETPLACE" >/dev/null && ok "marketplace $MARKETPLACE added"; fi
  if claude plugin update "$PLUGIN" >/dev/null 2>&1; then ok "plugin $PLUGIN up to date"
  else claude plugin install "$PLUGIN" -y >/dev/null && ok "plugin $PLUGIN installed"; fi
  plugin_dir="$HOME/.claude/plugins/marketplaces/sdd-factory"
  [ -x "$plugin_dir/bin/sdd" ] || fail "cannot find $plugin_dir/bin/sdd after install"
else
  checkout="$SDD_HOME/sdd-factory"
  if [ -d "$checkout/.git" ]; then git -C "$checkout" pull -q --ff-only && ok "plugin checkout updated ($checkout)"
  else git clone -q "$REPO_URL" "$checkout" && ok "plugin cloned to $checkout"; fi
  for d in "$checkout"/skills/*/; do
    n="$(basename "$d")"; npx -y skills add "$REPO_URL" --skill "$n" --global >/dev/null 2>&1 && ok "skill $n" || warn "skill $n could not be added with npx skills"
  done
  plugin_dir="$checkout"
fi
ln -sfn "$plugin_dir/bin/sdd" "$SDD_HOME/bin/sdd"; ok "sdd → $SDD_HOME/bin/sdd (stable path; add $SDD_HOME/bin to your PATH)"
"$SDD_HOME/bin/sdd" help >/dev/null || fail "sdd does not run"

# ── 3. Repository ────────────────────────────────────────────────────────────────────────────────
step "3. Repository"
[ -n "$repo" ] || repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo" ]; then warn "no repository given (--repo <path>) and the current directory is not a git repo; skills installed, nothing orchestrated"; exit 0; fi
repo="$(cd "$repo" && pwd -P)"; name="$(basename "$repo")"
[ -d "$repo/.git" ] || fail "$repo is not a git repository"
if [ -f "$repo/docs/constitution.md" ]; then ok "$name has docs/constitution.md"
else warn "$name has no docs/constitution.md yet: run  /sdd-init  in it first; the automation will skip until then"; fi
if ! grep -q 'Delegated gates' "$repo/docs/constitution.md" 2>/dev/null; then warn "no 'Delegated gates' line in the constitution: every approval gate stays with a human (that is the safe default)"; fi
(cd "$repo" && "$SDD_HOME/bin/sdd" next --all >/dev/null 2>&1) && ok "sdd next runs against $(cd "$repo" && gh repo view --json nameWithOwner -q .nameWithOwner)" || ok "sdd next runs (nothing runnable right now)"

# ── 4. Orca automation ───────────────────────────────────────────────────────────────────────────
[ "$orca_on" = 1 ] || { step "4. Orca"; warn "skipped"; exit 0; }
step "4. Orca automation"
if "$ORCA" repo list --json 2>/dev/null | grep -q "\"path\": *\"$repo\""; then ok "Orca already knows $name"
else "$ORCA" repo add --path "$repo" --json >/dev/null && ok "repository added to Orca"; fi
# The orchestrator gets its own Orca worktree on the default branch, so it never shares a checkout with a phase.
wt_name="sdd-orchestrator"
wt_path="$("$ORCA" worktree list --repo "path:$repo" --json 2>/dev/null | python3 -c 'import json,sys,os; d=json.load(sys.stdin); r=d.get("result",d); n=sys.argv[1]
print(next((w.get("path","") for w in r.get("worktrees",[]) if os.path.basename(w.get("path",""))==n or w.get("displayName")==n), ""))' "$wt_name")"
if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then ok "orchestrator worktree: $wt_path"
else
  default_branch="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"; default_branch="${default_branch:-main}"
  out="$("$ORCA" worktree create --repo "path:$repo" --name "$wt_name" --no-parent --setup skip --base-branch "$default_branch" --json 2>/dev/null || "$ORCA" worktree create --repo "path:$repo" --name "$wt_name" --no-parent --setup skip --json)"
  wt_path="$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); print(r.get("worktree",r).get("path",""))')"
  [ -n "$wt_path" ] || fail "could not create the orchestrator worktree in Orca"
  ok "orchestrator worktree created: $wt_path (from $default_branch)"
fi
auto_name="SDD factory · $name"
precheck="cd '$wt_path' && git pull -q --ff-only 2>/dev/null; '$SDD_HOME/bin/sdd' next"
existing="$("$ORCA" automations list --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); items=r.get("automations") or r.get("items") or []; n=sys.argv[1]; print(next((a.get("id","") for a in items if a.get("name")==n), ""))' "$auto_name")"
state_flag=--disabled; [ "$enable" = 1 ] && state_flag=--enabled
if [ -n "$existing" ]; then
  "$ORCA" automations edit "$existing" --trigger "*/$every * * * *" --precheck "$precheck" --precheck-timeout 180 --prompt "/sdd-orchestrate" --provider claude --workspace "path:$wt_path" --reuse-session $state_flag --json >/dev/null \
    && ok "automation updated: $auto_name ($existing)"
  auto_id="$existing"
else
  out="$("$ORCA" automations create --name "$auto_name" --trigger "*/$every * * * *" --precheck "$precheck" --precheck-timeout 180 --prompt "/sdd-orchestrate" --provider claude \
        --workspace "path:$wt_path" --reuse-session $state_flag --json)"
  auto_id="$(printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); a=r.get("automation",r); print(a.get("id",""))')"
  ok "automation created: $auto_name (${auto_id:-see Orca → Automations})"
fi

step "Done"
cat <<MSG
  Every $every min Orca runs the precheck \`sdd next\` in $name; when an issue has a runnable phase or a
  delegated gate, the orchestrator (/sdd-orchestrate) wakes in its own worktree ($wt_path), launches each
  phase as a supervised Orca worker in the issue's worktree and reports. Idle ticks cost nothing.

  Next:
  - review the automation in Orca → Automations${auto_id:+ (or:  orca automations show $auto_id --json)}
  - dry run:  orca automations run ${auto_id:-<id>} --json
  - enable:   orca automations edit ${auto_id:-<id>} --enabled --json   (or re-run this installer with --enable)
  - delegate gates when you trust them: a constitution line  - **Delegated gates:** Intake, Task
MSG
