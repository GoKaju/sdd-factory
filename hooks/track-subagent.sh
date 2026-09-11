#!/usr/bin/env bash
# Claude Code SubagentStart / SubagentStop hook: records deterministically which agent ran for which issue, with
# which model, how long and how many tokens, into the issue's run log (`sdd log`). This is the evidence behind
# "control of cost, time and model per phase": it comes from the host, not from the agent's own report.
#
# Issue resolution: the hook's cwd inside `.sdd/worktrees/issue-<N>`, else the file ~/.sdd/<owner>-<repo>/current-issue
# that /sdd writes at start (`sdd log current N`). No issue → nothing is logged (a subagent outside the factory).
# Model and tokens: from the hook input when present, else summed from the subagent's transcript (every assistant
# message carries `message.model` and `message.usage`).
set -u
. "$(dirname "$0")/lib.sh"
read_stdin
command -v jq >/dev/null 2>&1 || exit 0
j() { printf '%s' "$INPUT" | jq -r "$1 // empty"; }

event="$(j .hook_event_name)"; agent="$(j .agent_type)"; agent_id="$(j .agent_id)"
cwd="$(call_cwd)"
case "$agent" in sdd-factory:*|"") ;; *) exit 0;; esac   # only the factory's agents (matcher already filters; belt and braces)

sdd="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}/bin/sdd"
issue="$(printf '%s' "$cwd" | sed -nE 's#.*/\.sdd/worktrees/issue-([0-9]+).*#\1#p')"
[ -z "$issue" ] && issue="$(cat "$(flag_dir "$cwd")/current-issue" 2>/dev/null || true)"
[ -n "$issue" ] || exit 0

phase="${agent#sdd-factory:}"
case "$event" in
  SubagentStart)
    (cd "$cwd" 2>/dev/null && "$sdd" log add "$issue" agent-start agent="$agent" phase="$phase" id="$agent_id" >/dev/null 2>&1) || true
    ;;
  SubagentStop)
    model="$(j .model)"; effort="$(j .effort.level)"; [ -z "$effort" ] && effort="$(j .effort)"
    in="$(j .usage.input_tokens)"; out="$(j .usage.output_tokens)"; cw="$(j .usage.cache_creation_input_tokens)"; cr="$(j .usage.cache_read_input_tokens)"
    tp="$(j .transcript_path)"
    if [ -f "$tp" ] && { [ -z "$model" ] || [ -z "$out" ]; }; then
      read -r tmodel tin tout tcw tcr < <(jq -rs '
        [.[] | select(.type=="assistant" and .message.usage) | .message] |
        "\(map(.model) | map(select(.!=null)) | last // "") \(map(.usage.input_tokens // 0) | add // 0) \(map(.usage.output_tokens // 0) | add // 0) \(map(.usage.cache_creation_input_tokens // 0) | add // 0) \(map(.usage.cache_read_input_tokens // 0) | add // 0)"' "$tp" 2>/dev/null || echo "    ")
      [ -z "$model" ] && model="$tmodel"
      [ -z "$out" ] && { in="$tin"; out="$tout"; cw="$tcw"; cr="$tcr"; }
    fi
    (cd "$cwd" 2>/dev/null && "$sdd" log add "$issue" agent-stop agent="$agent" phase="$phase" id="$agent_id" model="${model:-unknown}" effort="${effort:-}" \
        input="${in:-0}" output="${out:-0}" cache_write="${cw:-0}" cache_read="${cr:-0}" >/dev/null 2>&1) || true
    ;;
esac
exit 0
