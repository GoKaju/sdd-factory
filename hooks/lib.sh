# Shared helpers for PreToolUse hooks. Sourced, not executed.
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

# Flags live OUTSIDE the repository, in ~/.sdd/<owner>-<repo>/ (see scripts/sdd-flag.sh): agents
# cannot write inside .git/ and .claude/ counts as a sensitive path in headless runs.
# <repo>/.claude/sdd/ and <repo>/.git/sdd/ are still honoured as legacy locations set by hand.
repo_slug() {
  local url; url="$(git -C "$(project_dir)" config --get remote.origin.url 2>/dev/null || true)"
  url="${url%.git}"; url="${url##*github.com[:/]}"; url="${url//\//-}"
  [ -n "$url" ] || url="$(basename "$(project_dir)")"
  printf '%s' "$url"
}
flag_dir() { printf '%s/%s' "${SDD_FLAG_HOME:-$HOME/.sdd}" "$(repo_slug)"; }

has_flag() { [ -f "$(flag_dir)/$1" ] || [ -f "$(project_dir)/.claude/sdd/$1" ] || [ -f "$(project_dir)/.git/sdd/$1" ]; }

block() { printf 'sdd-factory: %s\n' "$1" >&2; exit 2; }
