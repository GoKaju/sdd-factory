#!/usr/bin/env bash
# Resolves which model the Review Gate agents run on for an issue, from the constitution's
# Verification line:   - **Review model:** sonnet for S, M · opus for L, Constitution
# Tokens: sizes S/M/L and issue types (Feature, Change, Bug, Task, Constitution). A type match wins
# over a size match. No line, or no match → opus (the agents' own default).
#
#   sdd-review-model.sh <issue>     → sonnet | opus | haiku
. "$(dirname "$0")/lib.sh"
S="$(dirname "$0")"
need_issue "${1:-}"; issue="$1"

line="$( { grep -iE '^[[:space:]]*-[[:space:]]*\*\*Review model:\*\*' docs/constitution.md 2>/dev/null || true; } | head -1 | sed -E 's/^[^:]*:\*\*[[:space:]]*//')"
[ -n "$line" ] || { printf 'opus\n'; exit 0; }

type="$("$S/sdd-type.sh" get "$issue" 2>/dev/null || true)"; case "$type" in Feature|Change|Bug|Task|Constitution) ;; *) type="" ;; esac
size="$( { "$S/sdd-comment.sh" get "$issue" sdd:triage 2>/dev/null || true; } | { grep -oE '\*\*(Tamaño|Size):\*\*[[:space:]]*[SML]\b' || true; } | { grep -oE '[SML]$' || true; } | head -1)"

by_type=""; by_size=""
# clauses are separated by "·" or ";" : "<model> for <tokens>"
while IFS= read -r clause; do
  model="$(printf '%s' "$clause" | awk '{print tolower($1)}')"
  case "$model" in sonnet|opus|haiku) ;; *) continue ;; esac
  tokens="$(printf '%s' "$clause" | sed -E 's/^[[:alpha:]]+[[:space:]]+for[[:space:]]+//' | tr ',' ' ')"
  for t in $tokens; do
    [ -n "$type" ] && [ "$(printf '%s' "$t" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$type" | tr '[:upper:]' '[:lower:]')" ] && by_type="$model"
    [ -n "$size" ] && [ "$t" = "$size" ] && by_size="$model"
  done
done < <(printf '%s\n' "$line" | perl -CSD -pe 's/[·;]/\n/g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')

printf '%s\n' "${by_type:-${by_size:-opus}}"
