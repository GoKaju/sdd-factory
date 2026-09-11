#!/usr/bin/env bash
# sdd-factory installer, per machine: checks the prerequisites, installs the skills for your agent and
# puts a stable `sdd` on this machine. Idempotent: run it again after an update.
#
#   curl -fsSL https://raw.githubusercontent.com/GoKaju/sdd-factory/main/install.sh | bash -s -- [options]
#   ./install.sh [options]
#
#   --agent claude|skills  how to install the skills: Claude Code plugin (default) or `npx skills add`
#                        (any agent that reads SKILL.md: Codex, Cursor, OpenCode, Gemini…)
#
# Per-repository setup is not this script's job: `/sdd-init` prepares a repository, `sdd orca enable`
# (run inside it) creates the Orca automation that orchestrates it.
set -euo pipefail

REPO_URL="https://github.com/GoKaju/sdd-factory"
MARKETPLACE="GoKaju/sdd-factory"
PLUGIN="sdd-factory@sdd-factory"
SDD_HOME="${SDD_HOME:-$HOME/.sdd}"
agent=claude
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
if [ -x /Applications/Orca.app/Contents/Resources/bin/orca ] || command -v orca >/dev/null 2>&1; then ok "Orca found (optional: \`sdd orca enable\` in a repository schedules the orchestrator)"
else warn "Orca not found (optional): https://www.onorca.dev"; fi

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

step "Done"
cat <<MSG
  Next, per repository:
  - new repository:      open it with your agent and run  /sdd-init
  - orchestrate with Orca:  cd <repo> && $SDD_HOME/bin/sdd orca enable     (creates the disabled automation; --on to turn it on)
MSG
