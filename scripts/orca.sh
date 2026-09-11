#!/usr/bin/env bash
# Orca automation that orchestrates this repository: every N minutes Orca runs `sdd next` as a free
# precheck and, only when an issue has a runnable phase or a delegated gate, wakes /sdd-orchestrate in
# a dedicated worktree on the default branch. Run from inside the repository. Idempotent.
#
#   sdd orca enable [--every <min>] [--on]   → creates or updates the automation "SDD factory · <repo>"
#                                             (disabled unless --on), the orchestrator worktree and the
#                                             Orca registration of the repository
#   sdd orca show                            → prints the automation (JSON) or "none"
#   sdd orca disable | sdd orca remove       → pauses or deletes the automation (the worktree stays)
#   sdd orca run                             → triggers one run now (manual runs skip the precheck)
#   SDD_HOME (env, default ~/.sdd): where install.sh linked the stable `sdd` used by the precheck
. "$(dirname "$0")/lib.sh"

cmd="${1:-}"; shift || true
every=5; on=0
while [ $# -gt 0 ]; do case "$1" in --every) every="$2"; shift 2;; --on) on=1; shift;; *) die "unknown option $1";; esac; done

orca_bin() {
  if command -v orca >/dev/null 2>&1 && orca status --json >/dev/null 2>&1; then command -v orca; return; fi
  [ -x /Applications/Orca.app/Contents/Resources/bin/orca ] && { printf '/Applications/Orca.app/Contents/Resources/bin/orca'; return; }
  die "Orca CLI not found; install Orca (https://www.onorca.dev) and open it"
}
ORCA="$(orca_bin)"
"$ORCA" status --json 2>/dev/null | grep -q '"running": *true' || die "Orca is not running; open Orca (or \`orca serve\`) first"
root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this inside the repository"
name="$(basename "$root")"; auto_name="SDD factory · $name"
SDD_HOME="${SDD_HOME:-$HOME/.sdd}"; sdd_bin="$SDD_HOME/bin/sdd"; [ -x "$sdd_bin" ] || sdd_bin="$(cd "$(dirname "$0")/.." && pwd -P)/bin/sdd"

py() { python3 -c "$@"; }
find_auto() { "$ORCA" automations list --json 2>/dev/null | py 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); items=r.get("automations") or r.get("items") or []; n=sys.argv[1]; print(next((a.get("id","") for a in items if a.get("name")==n), ""))' "$auto_name"; }

case "$cmd" in
  show)
    id="$(find_auto)"; [ -n "$id" ] || { echo none; exit 0; }
    "$ORCA" automations show "$id" --json | py 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); a=r.get("automation",r); print(json.dumps({k:a.get(k) for k in ("id","name","enabled","precheck","prompt","provider","workspaceId","reuseSession") if k in a}, indent=1))'
    ;;
  disable) id="$(find_auto)"; [ -n "$id" ] || die "no automation for $name"; "$ORCA" automations edit "$id" --disabled --json >/dev/null && echo "disabled $auto_name" ;;
  remove)  id="$(find_auto)"; [ -n "$id" ] || die "no automation for $name"; "$ORCA" automations remove "$id" --json >/dev/null && echo "removed $auto_name" ;;
  run)     id="$(find_auto)"; [ -n "$id" ] || die "no automation for $name; run \`sdd orca enable\` first"; "$ORCA" automations run "$id" --json | py 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); print("run", r.get("run",{}).get("id",""))' ;;
  enable)
    [ -f "$root/docs/constitution.md" ] || die "no docs/constitution.md: run /sdd-init in this repository first"
    grep -q 'Delegated gates' "$root/docs/constitution.md" || printf 'note: no "Delegated gates" line in the constitution; every approval gate stays with a human\n'
    "$ORCA" repo list --json 2>/dev/null | grep -q "\"path\": *\"$root\"" || { "$ORCA" repo add --path "$root" --json >/dev/null && echo "registered $name in Orca"; }
    wt_name="sdd-orchestrator"
    wt_path="$("$ORCA" worktree list --repo "path:$root" --json 2>/dev/null | py 'import json,sys,os; d=json.load(sys.stdin); r=d.get("result",d); n=sys.argv[1]
print(next((w.get("path","") for w in r.get("worktrees",[]) if os.path.basename(w.get("path",""))==n or w.get("displayName")==n), ""))' "$wt_name")"
    if [ -z "$wt_path" ] || [ ! -d "$wt_path" ]; then
      base="$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"; base="${base:-main}"
      out="$("$ORCA" worktree create --repo "path:$root" --name "$wt_name" --no-parent --setup skip --base-branch "$base" --json 2>/dev/null || "$ORCA" worktree create --repo "path:$root" --name "$wt_name" --no-parent --setup skip --json)"
      wt_path="$(printf '%s' "$out" | py 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); print(r.get("worktree",r).get("path",""))')"
      [ -n "$wt_path" ] || die "could not create the orchestrator worktree"
      echo "orchestrator worktree: $wt_path (from $base)"
    fi
    precheck="cd '$wt_path' && git pull -q --ff-only 2>/dev/null; '$sdd_bin' next"
    flag=--disabled; [ "$on" = 1 ] && flag=--enabled
    id="$(find_auto)"
    if [ -n "$id" ]; then
      "$ORCA" automations edit "$id" --trigger "*/$every * * * *" --precheck "$precheck" --precheck-timeout 180 --prompt "/sdd-orchestrate" --provider claude --workspace "path:$wt_path" --reuse-session $flag --json >/dev/null
      echo "updated $auto_name ($id)"
    else
      id="$("$ORCA" automations create --name "$auto_name" --trigger "*/$every * * * *" --precheck "$precheck" --precheck-timeout 180 --prompt "/sdd-orchestrate" --provider claude --workspace "path:$wt_path" --reuse-session $flag --json \
        | py 'import json,sys; d=json.load(sys.stdin); r=d.get("result",d); print(r.get("automation",r).get("id",""))')"
      echo "created $auto_name ($id)"
    fi
    [ "$on" = 1 ] && echo "enabled: every $every min" || echo "disabled: review it in Orca → Automations, try \`sdd orca run\`, then \`sdd orca enable --on\`"
    ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
