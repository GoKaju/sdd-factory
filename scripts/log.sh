#!/usr/bin/env bash
# Run log of an issue: what /sdd launched, when, with which model and outcome, and how long it waited for humans.
# Deterministic input of the learning document. Stored outside the repository: ~/.sdd/<owner>-<repo>/runs/<issue>.jsonl
#
#   sdd log add <issue> <event> [key=value ...]   → appends one JSON line with ts (UTC) and the pairs
#        events used by /sdd: phase-start (phase, model, attempt) · phase-end (phase, outcome) · review (cycle, verdict)
#                             wait-start (gate) · wait-end (gate, event) · gate (name, granted|withheld, why) · escalation (from, to)
#   sdd log show <issue>                          → the raw lines
#   sdd log summary <issue>                       → per phase: attempts, minutes, models, outcomes; per gate: minutes waited; totals
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; shift 2 || true
f="$(sdd_home)/runs/$issue.jsonl"; mkdir -p "$(dirname "$f")"

case "$cmd" in
  add)
    ev="${1:-}"; [ -n "$ev" ] || die "event required"; shift
    python3 - "$ev" "$@" >> "$f" <<'EOF'
import json, sys, datetime
d = {"ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "event": sys.argv[1]}
for kv in sys.argv[2:]:
    k, _, v = kv.partition("="); d[k] = v
print(json.dumps(d, ensure_ascii=False))
EOF
    tail -1 "$f"
    ;;
  show) [ -f "$f" ] && cat "$f" || true ;;
  summary)
    [ -f "$f" ] || { echo "no run log for #$issue"; exit 0; }
    python3 - "$f" <<'EOF'
import json, sys, datetime
from collections import OrderedDict
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
t = lambda r: datetime.datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%SZ")
phases, waits, gates, reviews, esc = OrderedDict(), OrderedDict(), [], [], []
open_p, open_w = {}, {}
for r in rows:
    e = r["event"]
    if e == "phase-start":
        p = r.get("phase", "?"); open_p[p] = r
        phases.setdefault(p, {"attempts": 0, "minutes": 0.0, "models": set(), "outcomes": []})
        phases[p]["attempts"] += 1; phases[p]["models"].add(r.get("model", "?"))
    elif e == "phase-end":
        p = r.get("phase", "?"); s = open_p.pop(p, None)
        ph = phases.setdefault(p, {"attempts": 0, "minutes": 0.0, "models": set(), "outcomes": []})
        if s: ph["minutes"] += (t(r) - t(s)).total_seconds() / 60
        ph["outcomes"].append(r.get("outcome", "?"))
    elif e == "wait-start": open_w[r.get("gate", "?")] = r
    elif e == "wait-end":
        g = r.get("gate", "?"); s = open_w.pop(g, None); w = waits.setdefault(g, {"minutes": 0.0, "events": []})
        if s: w["minutes"] += (t(r) - t(s)).total_seconds() / 60
        w["events"].append(r.get("event_", r.get("result", "?")))
    elif e == "gate": gates.append(r)
    elif e == "review": reviews.append(r)
    elif e == "escalation": esc.append(r)
first, last = t(rows[0]), t(rows[-1])
print("issue: #%s  ·  first event %s  ·  last event %s  ·  wall clock %.0f min" % (sys.argv[1].rsplit("/",1)[-1].split(".")[0], rows[0]["ts"], rows[-1]["ts"], (last-first).total_seconds()/60))
print("\nphase        attempts  minutes  models            outcomes")
for p, v in phases.items():
    print("%-12s %8d %8.1f  %-17s %s" % (p, v["attempts"], v["minutes"], ",".join(sorted(v["models"])), ",".join(v["outcomes"])))
if waits:
    print("\nwaited for a human   minutes  ended by")
    for g, v in waits.items(): print("%-20s %7.1f  %s" % (g, v["minutes"], ",".join(v["events"])))
if reviews:
    print("\nreview cycles: " + "; ".join("cycle %s → %s" % (r.get("cycle","?"), r.get("verdict","?")) for r in reviews))
if gates:
    print("\ndelegated gates: " + "; ".join("%s %s%s" % (g.get("name","?"), g.get("result","?"), (" ("+g["why"]+")") if g.get("why") else "") for g in gates))
if esc:
    print("\nescalations: " + "; ".join("%s → %s%s" % (e.get("from","?"), e.get("to","?"), (": "+e["reason"]) if e.get("reason") else "") for e in esc))
EOF
    ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
