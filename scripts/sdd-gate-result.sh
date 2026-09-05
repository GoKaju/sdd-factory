#!/usr/bin/env bash
# Publishes a Review Gate result on the pull request as a collapsible comment, and reads them back.
#
#   sdd-gate-result.sh post <pr> <yaml-file>          → comment "<!-- sdd:gate:<name>:<cycle> -->" + YAML
#   sdd-gate-result.sh list <pr> [cycle]              → "<gate> <status>" per gate result found
#   sdd-gate-result.sh aggregate <pr> <cycle>         → PASS | FAIL | NEEDS_HUMAN | BLOCKED for that cycle
#   sdd-gate-result.sh skip <pr> <gate> <cycle> <why> → posts a PASS with not_applicable: true (gate has nothing to judge, e.g. documentation-only PR)
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; pr="${2:-}"; printf '%s' "$pr" | grep -Eq '^[0-9]+$' || die "pr number required"
r="$(repo)"

yaml_val() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1 | tr -d '"'; }

case "$cmd" in
  post)
    f="${3:-}"; [ -f "$f" ] || die "yaml file required"
    gate="$(yaml_val "$f" gate)"; status="$(yaml_val "$f" status)"; cycle="$(yaml_val "$f" rework_cycle)"; cycle="${cycle:-0}"
    [ -n "$gate" ] && [ -n "$status" ] || die "yaml must contain gate: and status:"
    blockers="$(grep -c 'severity: BLOCKER' "$f" || true)"; warnings="$(grep -c 'severity: WARNING' "$f" || true)"
    tmp="$(mktemp)"
    {
      printf '<!-- sdd:gate:%s:%s -->\n' "$gate" "$cycle"
      printf '<details><summary><b>Gate %s</b> · <b>%s</b> · cycle %s · %s blocker(s), %s warning(s)</summary>\n\n' "$gate" "$status" "$cycle" "$blockers" "$warnings"
      printf '```yaml\n'; cat "$f"; printf '\n```\n</details>\n'
    } > "$tmp"
    gh api -X POST "repos/$r/issues/$pr/comments" -F body=@"$tmp" --jq .html_url; rm -f "$tmp"
    ;;
  skip)
    gate="${3:-}"; cycle="${4:-0}"; why="${5:-not applicable}"; [ -n "$gate" ] || die "gate name required"
    f="$(mktemp)"
    printf 'gate: %s\npr: %s\nstatus: PASS\nrework_cycle: %s\nnot_applicable: true\nreason: "%s"\nfindings: []\n' "$gate" "$pr" "$cycle" "$why" > "$f"
    "$0" post "$pr" "$f"; rm -f "$f"
    ;;
  list)
    cycle="${3:-}"
    gh api "repos/$r/issues/$pr/comments" --paginate --jq '.[].body' \
      | awk -v want="$cycle" '
          /^<!-- sdd:gate:/ { split($2, a, ":"); gate=a[3]; c=a[4]; keep = (want=="" || c==want); next }
          keep && /^status:/ { print gate, $2; keep=0 }'
    ;;
  aggregate)
    cycle="${3:-0}"; results="$("$0" list "$pr" "$cycle")"
    [ -n "$results" ] || { echo BLOCKED; exit 0; }
    echo "$results" | grep -q ' BLOCKED$' && { echo BLOCKED; exit 0; }
    echo "$results" | grep -q ' FAIL$' && { echo FAIL; exit 0; }
    echo "$results" | grep -q ' NEEDS_HUMAN$' && { echo NEEDS_HUMAN; exit 0; }
    echo PASS
    ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac
