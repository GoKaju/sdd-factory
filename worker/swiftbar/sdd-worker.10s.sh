#!/usr/bin/env bash
# SwiftBar / xbar plugin: shows the sdd worker in the macOS menu bar. Reads http://127.0.0.1:4777/status.
# Install: copy (or symlink) into your SwiftBar plugins folder. Refreshes every 10 s (file name).
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
PORT="${SDD_STATUS_PORT:-4777}"
s="$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/status" 2>/dev/null)" || { echo "⚙︎ sdd ✗"; echo "---"; echo "worker not reachable on 127.0.0.1:$PORT"; exit 0; }
j() { printf '%s' "$s" | jq -r "$1"; }
running="$(j '.running | length')"; waiting="$(j '.waiting | length')"; paused="$(j '.pausedUntil // empty')"
if [ -n "$paused" ]; then top="⚙︎ sdd ⏸ $(date -j -f '%Y-%m-%dT%H:%M:%S' "${paused%%.*}" +%H:%M 2>/dev/null || echo paused)"
elif [ "$running" -gt 0 ]; then top="⚙︎ sdd ▶ $(j '.running[0].phase') #$(j '.running[0].issue')"
elif [ "$waiting" -gt 0 ]; then top="⚙︎ sdd ✋ $waiting"
else top="⚙︎ sdd ✓"; fi
echo "$top"
echo "---"
echo "sdd worker v$(j '.version') · $(j '.repos | join(", ")') · tick $(j '.lastTickAt // "—" | if . == "—" then . else .[11:19] end') | size=12"
[ -n "$paused" ] && echo "⏸ paused until ${paused:11:5} — $(j '.pauseReason') | color=orange"
echo "---"
echo "Running ($running)"
printf '%s' "$s" | jq -r '.running[] | "-- \(.repo)#\(.issue) · \(.phase) · \(((now*1000 - (.startedAt | sub("\\.[0-9]+Z$"; "Z") | fromdate * 1000)) / 60000 | floor)) / \(.budgetMinutes) min | href=https://github.com/\(.repo)/issues/\(.issue)"'
echo "Waiting for you ($waiting)"
printf '%s' "$s" | jq -r '.waiting[] | "-- #\(.number) \(.title[0:48]) · \(.waitingFor) | href=\(.url) color=#b45309"'
echo "---"
echo "Open issues"
printf '%s' "$s" | jq -r '.issues[] | "-- #\(.number) \(.title[0:48]) · \(.type // "?") \(.size // "") · \(.state // "none") | href=\(.url)"'
echo "---"
echo "Today: $(j '.today.phases') phases · \$$(j '.today.usd') · $(j '.today.minutes') min"
echo "Open status page | href=http://127.0.0.1:$PORT/"
