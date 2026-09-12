#!/usr/bin/env bash
# Run log of an issue: what /sdd launched, when, with which model, how many tokens and how long, and how long it
# waited for humans. Deterministic input of the learning document and of the per-phase report /sdd prints.
# Stored outside the repository: ~/.sdd/<owner>-<repo>/runs/<issue>.jsonl
#
#   sdd log add <issue> <event> [key=value ...]   → appends one JSON line with ts (UTC) and the pairs
#        written by /sdd:    phase-start (phase, model, attempt) · phase-end (phase, outcome) · review (cycle, verdict)
#                            wait-start (gate) · wait-end (gate, result) · gate (name, result, why) · escalation (from, to)
#        written by the plugin's SubagentStart/SubagentStop hooks (host evidence, not the agent's word):
#                            agent-start (agent, phase, id) · agent-stop (agent, phase, id, model, effort, input, output, cache_write, cache_read)
#   sdd log current <issue>                       → marks the issue /sdd is driving (the hooks use it when cwd is not the issue worktree)
#   sdd log last <issue> [phase]                  → one line for the last finished subagent: agent, model, minutes, tokens, cost
#   sdd log show <issue>                          → the raw lines
#   sdd log summary <issue>                       → per phase: runs, minutes, model, tokens, cost; waits; review cycles; gates; totals
#   Cost is estimated with the list prices embedded below; a `pricing:` block in .sdd/config.yml overrides them per family.
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; need_issue "${2:-}"; issue="$2"; shift 2 || true
home="$(sdd_home)"; f="$home/runs/$issue.jsonl"; mkdir -p "$(dirname "$f")"

pricing_json() { bash "$SDD_SCRIPTS/config.sh" json 2>/dev/null | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin).get("pricing") or {}))' 2>/dev/null || echo '{}'; }

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
  current) printf '%s\n' "$issue" > "$home/current-issue"; printf 'current issue: #%s\n' "$issue" ;;
  show) [ -f "$f" ] && cat "$f" || true ;;
  last|summary)
    [ -f "$f" ] || { echo "no run log for #$issue"; exit 0; }
    python3 - "$cmd" "$f" "$(pricing_json)" "${1:-}" <<'EOF'
import json, sys, datetime
from collections import OrderedDict
mode, path, pricing, want_phase = sys.argv[1], sys.argv[2], json.loads(sys.argv[3] or "{}"), sys.argv[4]
rows = [json.loads(l) for l in open(path) if l.strip()]
t = lambda r: datetime.datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%SZ")
num = lambda v: int(float(v)) if str(v).strip() not in ("", "None") else 0

# Default list prices, USD per million tokens, from https://platform.claude.com/docs/en/about-claude/pricing (2026-09-11):
# base input · output · 5-minute cache write · cache read. A `pricing:` block in .sdd/config.yml overrides a family.
DEFAULT_DATE = "2026-09-11"
DEFAULT_PRICING = {
    "fable":  {"input": 10.0, "output": 50.0, "cache_write": 12.50, "cache_read": 0.25},
    "mythos": {"input": 10.0, "output": 50.0, "cache_write": 12.50, "cache_read": 0.25},
    "opus":   {"input": 5.0,  "output": 25.0, "cache_write": 6.25,  "cache_read": 0.50},
    "sonnet": {"input": 2.0,  "output": 10.0, "cache_write": 2.50,  "cache_read": 0.20},
    "haiku":  {"input": 1.0,  "output": 5.0,  "cache_write": 1.25,  "cache_read": 0.10},
}
user_pricing = pricing
pricing = dict(DEFAULT_PRICING); pricing.update(user_pricing)

def family(model):
    m = (model or "").lower()
    for k in ("haiku", "sonnet", "opus", "fable", "mythos"):
        if k in m: return k
    return m or "unknown"

def cost(model, i, o, cw, cr):
    p = pricing.get(family(model)) or {}
    if not p: return None
    g = lambda k: float(p.get(k, 0) or 0)
    return (i*g("input") + o*g("output") + cw*g("cache_write") + cr*g("cache_read")) / 1e6

# pair agent-start / agent-stop by id → one run each
starts, runs, unattributed = {}, [], 0
for r in rows:
    if r["event"] in ("agent-start", "agent-stop") and not r.get("agent"):
        unattributed += 1; continue   # stops without agent_type, recorded by hook versions before 2.2.1: not factory runs
    if r["event"] == "agent-start": starts[r.get("id", "")] = r
    elif r["event"] == "agent-stop":
        s = starts.pop(r.get("id", ""), None)
        mins = (t(r) - t(s)).total_seconds()/60 if s else None
        i, o, cw, cr = (num(r.get(k, 0)) for k in ("input", "output", "cache_write", "cache_read"))
        runs.append({"ts": r["ts"], "agent": r.get("agent", "?"), "phase": r.get("phase", "?"), "model": r.get("model", "?"), "effort": r.get("effort", ""),
                     "minutes": mins, "input": i, "output": o, "cache_write": cw, "cache_read": cr, "cost": cost(r.get("model"), i, o, cw, cr)})

def fmt_min(m): return "-" if m is None else "%.1f" % m
def fmt_cost(c): return "-" if c is None else "$%.3f" % c
def fmt_tok(n): return "%dk" % round(n/1000) if n >= 1000 else str(n)

if mode == "last":
    sel = [x for x in runs if not want_phase or x["phase"] == want_phase]
    if not sel: print("no finished subagent" + (" for phase " + want_phase if want_phase else "")); sys.exit(0)
    x = sel[-1]
    print("%s · model %s%s · %s min · tokens in %s / out %s / cache write %s / cache read %s · cost %s" % (
        x["agent"], x["model"], (" (" + x["effort"] + ")") if x["effort"] else "", fmt_min(x["minutes"]),
        fmt_tok(x["input"]), fmt_tok(x["output"]), fmt_tok(x["cache_write"]), fmt_tok(x["cache_read"]), fmt_cost(x["cost"])))
    sys.exit(0)

phases, waits, gates, reviews, esc = OrderedDict(), OrderedDict(), [], [], []
open_p, open_w = {}, {}
for r in rows:
    e = r["event"]
    if e == "phase-start":
        p = r.get("phase", "?"); open_p[p] = r
        ph = phases.setdefault(p, {"attempts": 0, "minutes": 0.0, "models": set(), "outcomes": []}); ph["attempts"] += 1
        if r.get("model"): ph["models"].add(r["model"])
    elif e == "phase-end":
        p = r.get("phase", "?"); s = open_p.pop(p, None)
        ph = phases.setdefault(p, {"attempts": 0, "minutes": 0.0, "models": set(), "outcomes": []})
        if s: ph["minutes"] += (t(r) - t(s)).total_seconds()/60
        ph["outcomes"].append(r.get("outcome", "?"))
    elif e == "wait-start": open_w[r.get("gate", "?")] = r
    elif e == "wait-end":
        g = r.get("gate", "?"); s = open_w.pop(g, None); w = waits.setdefault(g, {"minutes": 0.0, "events": []})
        if s: w["minutes"] += (t(r) - t(s)).total_seconds()/60
        w["events"].append(r.get("result", "?"))
    elif e == "gate": gates.append(r)
    elif e == "review": reviews.append(r)
    elif e == "escalation": esc.append(r)

first, last = t(rows[0]), t(rows[-1])
print("issue: #%s  ·  first event %s  ·  last event %s  ·  wall clock %.0f min" % (path.rsplit("/",1)[-1].split(".")[0], rows[0]["ts"], rows[-1]["ts"], (last-first).total_seconds()/60))

# subagent runs grouped by phase: the host's evidence of model, time and tokens
if runs:
    print("\nsubagent runs (host evidence via SubagentStart/Stop hooks)")
    print("phase        runs  minutes  model                          tokens in/out       cache w/r          cost")
    byp = OrderedDict()
    for x in runs:
        g = byp.setdefault(x["phase"], {"runs": 0, "minutes": 0.0, "models": set(), "input": 0, "output": 0, "cw": 0, "cr": 0, "cost": 0.0, "priced": True})
        g["runs"] += 1; g["minutes"] += x["minutes"] or 0; g["models"].add(x["model"]); g["input"] += x["input"]; g["output"] += x["output"]; g["cw"] += x["cache_write"]; g["cr"] += x["cache_read"]
        if x["cost"] is None: g["priced"] = False
        else: g["cost"] += x["cost"]
    tot = {"runs": 0, "minutes": 0.0, "input": 0, "output": 0, "cw": 0, "cr": 0, "cost": 0.0, "priced": True}
    for p, g in byp.items():
        print("%-12s %4d %8.1f  %-30s %8s/%-8s   %8s/%-8s  %s" % (p, g["runs"], g["minutes"], ",".join(sorted(g["models"]))[:30], fmt_tok(g["input"]), fmt_tok(g["output"]), fmt_tok(g["cw"]), fmt_tok(g["cr"]), fmt_cost(g["cost"] if g["priced"] else None)))
        for k in ("runs", "minutes", "input", "output", "cw", "cr", "cost"): tot[k] += g[k]
        tot["priced"] = tot["priced"] and g["priced"]
    print("%-12s %4d %8.1f  %-30s %8s/%-8s   %8s/%-8s  %s" % ("total", tot["runs"], tot["minutes"], "", fmt_tok(tot["input"]), fmt_tok(tot["output"]), fmt_tok(tot["cw"]), fmt_tok(tot["cr"]), fmt_cost(tot["cost"] if tot["priced"] else None)))
    if unattributed: print("(ignored %d agent rows without agent type, logged by a hook older than 2.2.1)" % unattributed)
    src = "list prices of %s" % DEFAULT_DATE if not user_pricing else "`pricing:` in .sdd/config.yml over list prices of %s" % DEFAULT_DATE
    print("(cost: USD per million tokens, %s; families without a price show -)" % src)

if phases:
    print("\nphases as /sdd logged them")
    print("phase        attempts  minutes  configured model  outcomes")
    for p, v in phases.items():
        print("%-12s %8d %8.1f  %-17s %s" % (p, v["attempts"], v["minutes"], ",".join(sorted(v["models"])), ",".join(v["outcomes"])))
if waits:
    print("\nwaited for a human   minutes  ended by")
    for g, v in waits.items(): print("%-20s %7.1f  %s" % (g, v["minutes"], ",".join(v["events"])))
if reviews: print("\nreview cycles: " + "; ".join("cycle %s → %s" % (r.get("cycle","?"), r.get("verdict","?")) for r in reviews))
if gates: print("\ndelegated gates: " + "; ".join("%s %s%s" % (g.get("name","?"), g.get("result","?"), (" ("+g["why"]+")") if g.get("why") else "") for g in gates))
if esc: print("\nescalations: " + "; ".join("%s → %s%s" % (e.get("from","?"), e.get("to","?"), (": "+e["reason"]) if e.get("reason") else "") for e in esc))
EOF
    ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac
