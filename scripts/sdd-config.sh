#!/usr/bin/env bash
# Reads the repository's SDD runtime configuration (.sdd/config.json) with the template as defaults.
#
#   sdd-config.sh get <jq-path>              → value (e.g. get .review.mode, get .review.maxReworkCycles)
#   sdd-config.sh auto-approvals             → space-separated gates the orchestrator may approve
#   sdd-config.sh phase-tier <phase> [issue] → light | standard | strong | frontier (floor; a phase may map by triage size)
#   Tiers: light (mechanical), standard (writing/coordination under clear rules), strong (adversarial judgement, synthesis), frontier (the best available; explicit floors only).
#   sdd-config.sh reviewer-tier <issue>      → tier for the Review Gate agents (type wins over triage size, then default)
#   sdd-config.sh tier-model <tier>          → model name for this machine (~/.sdd/models.json, else haiku/sonnet/opus)
#   sdd-config.sh init                       → writes .sdd/config.json from the template if missing
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"; TEMPLATE="$S/../templates/sdd.config.json"; FILE=".sdd/config.json"
command -v jq >/dev/null || die "jq is required"

merged() { if [ -f "$FILE" ]; then jq -s '.[0] * .[1]' "$TEMPLATE" "$FILE"; else cat "$TEMPLATE"; fi; }
tier_ok() { case "$1" in light|standard|strong|frontier) return 0;; *) return 1;; esac; }
raise_tier() { case "$1" in light) echo standard;; standard) echo strong;; *) echo "$1";; esac; }

cmd="${1:-}"; shift || true
case "$cmd" in
  get) [ -n "${1:-}" ] || die "jq path required"; merged | jq -r "$1" ;;
  auto-approvals) merged | jq -r '.approvals.auto // [] | .[]' | tr '\n' ' ' | sed 's/ $//'; echo ;;
  phase-tier)
    [ -n "${1:-}" ] || die "phase required"; size=""
    if [ -n "${2:-}" ]; then need_issue "$2"; size="$( { "$S/sdd-comment.sh" get "$2" sdd:triage 2>/dev/null || true; } | { grep -oE '\*\*(Tamaño|Size):\*\*[[:space:]]*[SML]\b' || true; } | { grep -oE '[SML]$' || true; } | head -1)"; fi
    t="$(merged | jq -r --arg p "$1" --arg sz "$size" '.intelligence[$p] // "standard" | if type == "object" then (.[$sz] // .default // "strong") else . end')"
    tier_ok "$t" || die "unknown tier '$t' for phase $1 in $FILE"; printf '%s\n' "$t" ;;
  reviewer-tier)
    need_issue "${1:-}"; issue="$1"
    type="$("$S/sdd-type.sh" get "$issue" 2>/dev/null || true)"; case "$type" in Feature|Change|Bug|Task|Constitution) ;; *) type="";; esac
    size="$( { "$S/sdd-comment.sh" get "$issue" sdd:triage 2>/dev/null || true; } | { grep -oE '\*\*(Tamaño|Size):\*\*[[:space:]]*[SML]\b' || true; } | { grep -oE '[SML]$' || true; } | head -1)"
    t="$(merged | jq -r --arg ty "$type" --arg sz "$size" '.review.reviewers as $r | ($r[$ty] // $r[$sz] // $r.default // "strong")')"
    tier_ok "$t" || die "unknown tier '$t' in .review.reviewers of $FILE"
    # mode auto: the floor is raised from the second review cycle on, and to strong on the last permitted cycle
    if [ "$(merged | jq -r '.intelligence.mode // "auto"')" = "auto" ]; then
      pr="$("$S/sdd-pr.sh" find "$issue" 2>/dev/null || true)"; cycles=0
      if [ -n "$pr" ]; then while [ "$cycles" -lt 10 ] && [ -n "$("$S/sdd-gate-result.sh" list "$pr" "$cycles" 2>/dev/null)" ]; do cycles=$((cycles+1)); done; fi
      max="$(merged | jq -r '.review.maxReworkCycles // 3')"
      [ "$cycles" -ge 1 ] && t="$(raise_tier "$t")"
      [ $((cycles+1)) -ge "$max" ] && [ "$t" != frontier ] && t=strong
    fi
    printf '%s\n' "$t" ;;
  tier-model)
    t="${1:-}"; tier_ok "$t" || die "tier must be light|standard|strong|frontier"
    map="$HOME/.sdd/models.json"
    if [ -f "$map" ]; then m="$(jq -r --arg t "$t" '.[$t] // empty' "$map")"; fi
    if [ -z "${m:-}" ]; then case "$t" in light) m=haiku;; standard) m=sonnet;; strong) m=opus;; frontier) m=fable;; esac; fi
    printf '%s\n' "$m" ;;
  init)
    if [ -f "$FILE" ]; then echo "$FILE exists"; else mkdir -p .sdd && jq 'del(.. | ."$comment"?)' "$TEMPLATE" > "$FILE" && echo "wrote $FILE"; fi ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
