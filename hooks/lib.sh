# Shared helpers for the plugin's PreToolUse hooks. Sourced, not executed.
# Hooks receive the tool call as JSON on stdin and block by exiting 2 (stderr is shown to the user).

read_stdin() { INPUT="$(cat)"; }

json_field() {
  # json_field <key>  → prints the string value of tool_input.<key>, or empty
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r ".tool_input.${key} // empty"
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('tool_input',{}).get('$key',''); print(v if isinstance(v,str) else '')"
  else
    printf '%s' "$INPUT" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}

project_dir() { printf '%s' "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"; }

# The working directory of the tool call (follows the issue worktree; CLAUDE_PROJECT_DIR stays at the main checkout)
call_cwd() {
  local c
  if command -v jq >/dev/null 2>&1; then c="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"
  else c="$(printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || true)"; fi
  printf '%s' "${c:-$(project_dir)}"
}

# Top-level directory of the git checkout that holds <path> (a worktree under .sdd/worktrees/ or the main checkout)
repo_top_of() {
  local d="$1"; [ -d "$d" ] || d="$(dirname "$d")"
  git -C "$d" rev-parse --show-toplevel 2>/dev/null || project_dir
}

# Flags live OUTSIDE the repository, in ~/.sdd/<owner>-<repo>/ (see `sdd flag`): agents
# cannot write inside .git/ and .claude/ counts as a sensitive path in headless runs.
# <repo>/.claude/sdd/ and <repo>/.git/sdd/ are still honoured as legacy locations set by hand.
repo_slug() { # repo_slug [dir] → <owner>-<repo> from the remote of <dir> (default: the project dir); honours SDD_REPO like bin/sdd
  local d="${1:-$(project_dir)}" url="${SDD_REPO:-}"
  [ -n "$url" ] || { url="$(git -C "$d" config --get remote.origin.url 2>/dev/null || true)"; url="${url%.git}"; url="${url##*github.com[:/]}"; }
  [ -n "$url" ] || url="$(basename "$d")"
  printf '%s' "${url//\//-}"
}
flag_dir() { printf '%s/%s' "${SDD_FLAG_HOME:-${SDD_HOME:-$HOME/.sdd}}" "$(repo_slug "${1:-}")"; }

has_flag() { [ -f "$(flag_dir)/$1" ] || [ -f "$(project_dir)/.claude/sdd/$1" ] || [ -f "$(project_dir)/.git/sdd/$1" ]; }

block() { printf 'sdd-factory: %s\n' "$1" >&2; exit 2; }
