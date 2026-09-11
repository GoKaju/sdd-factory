#!/usr/bin/env bash
# What the factory should do next, per open issue, from the labels and comments on GitHub. Pure
# read; the rules are the state machine of the framework (see the table in skills/sdd-status).
#
#   sdd next [--all]        → one JSON object per line: issue, title, type, state, action, phase|gate, reason, pr
#                             action: run     — a phase to launch      (phase: triage|spec|design|task|implement|review)
#                                     approve — a delegated human gate the orchestrator may grant after verifying
#                                               the artifact (gate: Intake|Spec|Design|Task|Final; judged: true|false)
#                                     human   — waits for a person (only with --all)
#                                     busy    — a phase is running or just ran (only with --all)
#                             exit 0 when at least one run/approve line was printed, 1 otherwise
#                             (so `--precheck "sdd next"` in an Orca automation skips idle ticks for free)
#   STALE_MINUTES (env, default 45): an `implementing` issue idle longer than this is resumed
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"
all=0; [ "${1:-}" = "--all" ] && all=1
stale="${STALE_MINUTES:-45}"
r="$(repo)"
delegated="$(delegated_gates)"
delegated_mode() { printf '%s\n' "$delegated" | awk -v g="$1" '$1==g {print $2}'; }

json() { python3 -c 'import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2])), ensure_ascii=False))' "$@"; }
now_epoch="$(date -u +%s)"
to_epoch() { python3 -c 'import sys,datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1].replace("Z","+00:00")).timestamp()))' "$1"; }

# newer non-marker comment than the triage comment's last edit → the author answered
author_answered() {
  local id; id="$("$S/comment.sh" find "$1" sdd:triage 2>/dev/null || true)"; [ -n "$id" ] || return 1
  local edited; edited="$(gh api "repos/$r/issues/comments/$id" --jq .updated_at)"
  gh api "repos/$r/issues/$1/comments" --paginate --jq '.[] | select(.body | startswith("<!-- sdd:") | not) | .created_at' \
    | awk -v e="$edited" '$0 > e {found=1} END {exit found?0:1}'
}

found=0
gh issue list --repo "$r" --state open --limit 200 --json number,title,labels,updatedAt \
  --jq '.[] | [.number, (.labels | map(.name) | map(select(startswith("sdd:"))) | .[0] // "-"), .updatedAt, .title] | @tsv' \
| while IFS="$(printf '\t')" read -r n label updated title; do
  [ "$label" = "-" ] && label=""   # @tsv leaves an empty field, which `read` would collapse
  state="${label#sdd:}"; type="$("$S/type.sh" get "$n" 2>/dev/null || true)"
  action=human; what=""; reason=""; judged=false
  case "$state" in
    "") action=run; what=triage; reason="new issue without SDD state" ;;
    triage)
      if author_answered "$n"; then action=run; what=triage; reason="author answered"
      elif [ "$("$S/comment.sh" open "$n" sdd:triage 2>/dev/null || echo 1)" = 0 ] && [ -n "$(delegated_mode Intake)" ]; then action=approve; what=Intake; [ "$(delegated_mode Intake)" = judged ] && judged=true; reason="triage has no open question; Intake delegated"
      else reason="author answers the triage, then a human sets sdd:ready"; fi ;;
    ready)
      case "$type" in Feature|Change) action=run; what=spec; reason="ready, $type takes spec";; *) action=run; what=task; reason="ready, ${type:-untyped} skips spec and design";; esac ;;
    spec|design|task)
      case "$state" in spec) gate=Spec;; design) gate=Design;; *) gate=Task;; esac
      if [ -n "$(delegated_mode "$gate")" ]; then action=approve; what="$gate"; [ "$(delegated_mode "$gate")" = judged ] && judged=true; reason="$gate delegated; verify the artifact before approving"
      else reason="human approves $gate (sdd:$state-approved)"; fi ;;
    spec-approved) action=run; what=design; reason="spec approved" ;;
    design-approved)
      if [ -n "$("$S/comment.sh" find "$n" sdd:task 2>/dev/null || true)" ] && [ "$("$S/comment.sh" open "$n" sdd:task 2>/dev/null || echo 1)" = 0 ]; then action=run; what=review; reason="document-only amendment: Task already complete"
      else action=run; what=task; reason="design approved"; fi ;;
    task-approved) action=run; what=implement; reason="task approved" ;;
    rework) action=run; what=implement; reason="rework requested" ;;
    implementing)
      idle=$(( (now_epoch - $(to_epoch "$updated")) / 60 ))
      if [ "$idle" -ge "$stale" ]; then action=run; what=implement; reason="implementing idle for $idle min: resume"; else action=busy; reason="implementing for $idle min"; fi ;;
    in-review) action=run; what=review; reason="implementation finished, review pending" ;;
    final-review)
      if [ -n "$("$S/rework.sh" pending "$n" 2>/dev/null || true)" ]; then action=run; what=implement; reason="human asked for changes with /rework"
      elif [ "$type" != Constitution ] && [ -n "$(delegated_mode Final)" ]; then
        action=approve; what=Final; [ "$(delegated_mode Final)" = judged ] && judged=true
        pr_n="$("$S/pr.sh" find "$n" 2>/dev/null || true)"; cyc="$("$S/gate-result.sh" list "${pr_n:-0}" 2>/dev/null | wc -l | tr -d ' ')"; cyc=$(( cyc > 0 ? (cyc - 1) / 6 : 0 ))
        warn_n="$("$S/gate-result.sh" warnings "${pr_n:-0}" "$cyc" 2>/dev/null | grep -c . || true)"
        reason="Final delegated; every gate must be PASS; $warn_n WARNING(s), policy $(warnings_policy)"
      else reason="human merges the PR or comments /rework (Gate 4)"; fi ;;
    *) action=human; reason="unknown state sdd:$state" ;;
  esac
  case "$action" in run|approve) found=1;; *) [ "$all" = 1 ] || continue;; esac
  pr="$("$S/pr.sh" find "$n" 2>/dev/null || true)"
  key=phase; [ "$action" = approve ] && key=gate
  json issue "$n" title "$title" type "$type" state "$state" action "$action" "$key" "$what" judged "$judged" reason "$reason" pr "$pr"
  [ "$found" = 1 ] && touch "${TMPDIR:-/tmp}/sdd-next-found-$$"
done
[ -f "${TMPDIR:-/tmp}/sdd-next-found-$$" ] && { rm -f "${TMPDIR:-/tmp}/sdd-next-found-$$"; exit 0; } || exit 1
