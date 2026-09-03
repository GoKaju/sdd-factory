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

# Flags live in <repo>/.claude/sdd/ (gitignored). Writing inside .git/ is denied to agents, so
# .git/sdd/ is only honoured as a legacy location set by hand.
flag_dir() { printf '%s/.claude/sdd' "$(project_dir)"; }

has_flag() { [ -f "$(flag_dir)/$1" ] || [ -f "$(project_dir)/.git/sdd/$1" ]; }

block() { printf 'sdd-factory: %s\n' "$1" >&2; exit 2; }
