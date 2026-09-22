#!/usr/bin/env bash
# Review Gate results on the pull request: ONE comment per cycle ("<!-- sdd:review:<cycle> -->") with a summary table
# and one collapsible section per gate, edited in place as gates report. Cycles are 0, 1, 2… for the code review and
# `plan` for the completeness gate of the plan phase, so the two never mix.
#
#   sdd gate-result post <pr> <yaml-file>            → adds or replaces the gate's section in its cycle comment (cycle = rework_cycle:)
#   sdd gate-result skip <pr> <gate> <cycle> <why>   → posts a PASS with not_applicable: true (nothing to judge, e.g. docs-only PR)
#   sdd gate-result list <pr> [cycle]                → "<gate> <status>" per gate (latest result per gate and cycle)
#   sdd gate-result aggregate <pr> <cycle>           → PASS | FAIL | NEEDS_HUMAN | BLOCKED for that cycle
#   sdd gate-result warnings <pr> <cycle>            → one line per WARNING: "<gate>\t<location>\t<description>" (docs/ locations first)
#   sdd gate-result last <pr>                        → highest numeric cycle with results (empty when none)
#   sdd gate-result next <pr>                        → the cycle the next code review uses: last + 1, or 0
#   sdd gate-result commit <pr> <cycle>              → the head commit that cycle reviewed
#   sdd gate-result dispute <pr> <cycle> <yaml-file> → records implement's disputes of that cycle's BLOCKERs in its comment
#   sdd gate-result disputes <pr> <cycle>            → prints the recorded disputes (YAML), empty when none
#   sdd gate-result show <pr> <cycle>                → prints that cycle's comment (summary, every gate, disputes)
#   sdd gate-result carry <pr> <gate> <from> <to>    → re-posts a gate's result of cycle <from> as cycle <to> (carried_from: <from>)
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; pr="${2:-}"; printf '%s' "$pr" | grep -Eq '^[0-9]+$' || die "pr number required"
r="$(repo)"

yaml_val() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1 | tr -d '"'; }
bodies() { gh api "repos/$r/issues/$pr/comments" --paginate --jq '.[].body'; }
cycle_comment_id() { gh api "repos/$r/issues/$pr/comments" --paginate --jq ".[] | select(.body | startswith(\"<!-- sdd:review:$1 -->\")) | .id" | head -1; }

# upsert_section <cycle> <marker> <section-file>: replace the section opened by <marker> in the cycle comment, or append it
upsert_section() {
  local cycle="$1" marker="$2" section="$3" id old new
  id="$(cycle_comment_id "$cycle")"
  old="$(mktemp)"; new="$(mktemp)"
  if [ -n "$id" ]; then gh api "repos/$r/issues/comments/$id" --jq .body > "$old"; else : > "$old"; fi
  python3 - "$cycle" "$marker" "$section" "$old" > "$new" <<'PY'
import re, sys
cycle, marker, section_file, old_file = sys.argv[1:]
section = open(section_file).read().rstrip("\n")
old = open(old_file).read()
parts = re.findall(r"(<!-- sdd:(?:gate|dispute):[^\n]*? -->\n.*?<!-- /sdd:section -->)", old, re.S)
sections = {p.split("\n", 1)[0]: p for p in parts}
sections[marker] = section
order = [p.split("\n", 1)[0] for p in parts]
if marker not in order: order.append(marker)
rows, verdict = [], []
for m in order:
    if not m.startswith("<!-- sdd:gate:"): continue
    body = sections[m]
    g = re.search(r"^gate:\s*(\S+)", body, re.M); s = re.search(r"^status:\s*(\S+)", body, re.M)
    b = len(re.findall(r"severity:\s*BLOCKER", body)); w = len(re.findall(r"severity:\s*WARNING", body))
    na = " (n/a)" if re.search(r"^not_applicable:\s*true", body, re.M) else ""
    rows.append("| %s | %s%s | %d | %d |" % (g.group(1) if g else "?", s.group(1) if s else "?", na, b, w))
    verdict.append(s.group(1) if s else "BLOCKED")
v = next((x for x in ("BLOCKED", "FAIL", "NEEDS_HUMAN") if x in verdict), "PASS")
title = "plan · completeness" if cycle == "plan" else "cycle %s" % cycle
header = ["<!-- sdd:review:%s -->" % cycle, "**SDD review · %s · %s**" % (title, v), "",
          "| Gate | Status | Blockers | Warnings |", "| --- | --- | --- | --- |"] + rows
print("\n".join(header) + "\n\n" + "\n\n".join(sections[m] for m in order))
PY
  if [ -n "$id" ]; then gh api -X PATCH "repos/$r/issues/comments/$id" -F body=@"$new" --jq .html_url
  else gh api -X POST "repos/$r/issues/$pr/comments" -F body=@"$new" --jq .html_url; fi
  rm -f "$old" "$new"
}

case "$cmd" in
  post)
    f="${3:-}"; [ -f "$f" ] || die "yaml file required"
    gate="$(yaml_val "$f" gate)"; status="$(yaml_val "$f" status)"; cycle="$(yaml_val "$f" rework_cycle)"; cycle="${cycle:-0}"
    [ -n "$gate" ] && [ -n "$status" ] || die "yaml must contain gate: and status:"
    printf '%s' "$cycle" | grep -Eq '^([0-9]+|plan)$' || die "rework_cycle must be a number or plan (got '$cycle')"
    blockers="$(grep -c 'severity: BLOCKER' "$f" || true)"; warnings="$(grep -c 'severity: WARNING' "$f" || true)"
    sec="$(mktemp)"
    {
      printf '<!-- sdd:gate:%s:%s -->\n' "$gate" "$cycle"
      printf '<details><summary><b>Gate %s</b> · <b>%s</b> · %s blocker(s), %s warning(s)</summary>\n\n' "$gate" "$status" "$blockers" "$warnings"
      printf '```yaml\n'; cat "$f"; printf '\n```\n</details>\n<!-- /sdd:section -->\n'
    } > "$sec"
    upsert_section "$cycle" "<!-- sdd:gate:$gate:$cycle -->" "$sec"; rm -f "$sec"
    ;;
  skip)
    gate="${3:-}"; cycle="${4:-0}"; why="${5:-not applicable}"; [ -n "$gate" ] || die "gate name required"
    f="$(mktemp)"
    printf 'gate: %s\npr: %s\nstatus: PASS\nrework_cycle: %s\nnot_applicable: true\nreason: "%s"\nfindings: []\n' "$gate" "$pr" "$cycle" "$why" > "$f"
    "$0" post "$pr" "$f"; rm -f "$f"
    ;;
  dispute)
    cycle="${3:-}"; f="${4:-}"; [ -n "$cycle" ] && [ -f "$f" ] || die "usage: sdd gate-result dispute <pr> <cycle> <yaml-file>"
    sec="$(mktemp)"
    { printf '<!-- sdd:dispute:%s -->\n<details><summary><b>Disputed by implement</b></summary>\n\n```yaml\n' "$cycle"; cat "$f"; printf '\n```\n</details>\n<!-- /sdd:section -->\n'; } > "$sec"
    upsert_section "$cycle" "<!-- sdd:dispute:$cycle -->" "$sec"; rm -f "$sec"
    ;;
  disputes)
    cycle="${3:-}"; [ -n "$cycle" ] || die "cycle required"
    bodies | awk -v m="<!-- sdd:dispute:$cycle -->" '$0==m {on=1; next} on && /^```yaml$/ {y=1; next} on && y && /^```$/ {exit} on && y {print}'
    ;;
  list)
    cycle="${3:-}"
    bodies | awk -v want="$cycle" '
        /^<!-- sdd:gate:/ { split($2, a, ":"); gate=a[3]; c=a[4]; keep = (want=="" || c==want); key=gate ":" c; next }
        keep && /^status:/ { if (!(key in st)) order[++n]=key; st[key]=$2; name[key]=gate; keep=0 }
        END { for (i=1; i<=n; i++) print name[order[i]], st[order[i]] }'
    ;;
  carry)
    gate="${3:-}"; from="${4:-}"; to="${5:-}"; [ -n "$gate" ] && [ -n "$from" ] && [ -n "$to" ] || die "usage: sdd gate-result carry <pr> <gate> <from> <to>"
    f="$(mktemp)"
    bodies | awk -v m="<!-- sdd:gate:$gate:$from -->" '$0==m {on=1; next} on && /^```yaml$/ {y=1; next} on && y && /^```$/ {exit} on && y {print}' \
      | sed "s/^rework_cycle:.*/rework_cycle: $to\ncarried_from: $from/" > "$f"
    [ -s "$f" ] || die "no $gate result in cycle $from"
    "$0" post "$pr" "$f"; rm -f "$f"
    ;;
  show)
    cycle="${3:-}"; [ -n "$cycle" ] || die "cycle required"
    gh api "repos/$r/issues/$pr/comments" --paginate --jq ".[] | select(.body | startswith(\"<!-- sdd:review:$cycle -->\")) | .body"
    ;;
  last)
    bodies | sed -n 's/^<!-- sdd:review:\([0-9][0-9]*\) -->.*/\1/p' | sort -n | tail -1
    ;;
  next)
    l="$("$0" last "$pr")"; if [ -n "$l" ]; then echo $(( l + 1 )); else echo 0; fi
    ;;
  commit)
    cycle="${3:-}"; [ -n "$cycle" ] || die "cycle required"
    bodies | awk -v want="$cycle" '/^<!-- sdd:gate:/ { split($2, a, ":"); keep=(a[4]==want); next } keep && /^commit:/ { print $2; exit }' | tr -d '"'
    ;;
  warnings)
    cycle="${3:-0}"
    bodies | awk -v want="$cycle" '
          /^<!-- sdd:gate:/ { split($2, a, ":"); gate=a[3]; c=a[4]; keep=(c==want); w=0; next }
          !keep { next }
          /^  - severity:/ { if (w && loc!="") print gate "\t" loc "\t" desc; w=0; d=0; if ($0 ~ /WARNING/) { w=1; loc=""; desc="" }; next }
          w && /^    location:/ { sub(/^    location:[ ]*/, ""); loc=$0; next }
          w && /^    description: >/ { d=1; next }
          w && d && /^      / { sub(/^      /, ""); desc = desc (desc==""?"":" ") $0; next }
          w && /^    (required_action|requirement|disputed):/ { d=0; next }
          /^```$/ { if (w && loc!="") print gate "\t" loc "\t" desc; w=0; d=0 }' \
      | sort -t"$(printf '\t')" -k2,2 | awk -F"\t" '$2 ~ /^docs\// {print; next} {rest = rest $0 "\n"} END {printf "%s", rest}'
    ;;
  aggregate)
    cycle="${3:-0}"; results="$("$0" list "$pr" "$cycle")"
    [ -n "$results" ] || { echo BLOCKED; exit 0; }
    echo "$results" | grep -q ' BLOCKED$' && { echo BLOCKED; exit 0; }
    echo "$results" | grep -q ' FAIL$' && { echo FAIL; exit 0; }
    echo "$results" | grep -q ' NEEDS_HUMAN$' && { echo NEEDS_HUMAN; exit 0; }
    echo PASS
    ;;
  *) sed -n '2,17p' "$0"; exit 1 ;;
esac
