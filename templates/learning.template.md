# Learning · issue #<N> · <type> · <title>

<!-- Written by the learning agent of the sdd-factory plugin when the issue reaches final-review; updated after each rework.
     For the people who maintain this project's rules and the plugin. /sdd never reads it. Facts only; numbers come from `sdd log summary`. -->

- **PR:** #<pr> · **cycles of review:** <n> · **wall clock:** <min> min · **waited for humans:** <min> min · **tokens:** <in>/<out> (cache <w>/<r>) · **cost:** <usd or "not priced">
- **Path:** <Spec → Design → Task → Implement → Review | Task → Implement → Review> · **delegated gates granted:** <list or none>

## Metrics

<!-- From `sdd log summary`: the "subagent runs" table is host evidence (SubagentStart/Stop hooks): real model, minutes, tokens. -->

| Phase | Runs | Minutes | Model (real) | Tokens in/out | Cache w/r | Cost | Outcomes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| triage | | | | | | | |
| spec | | | | | | | |
| design | | | | | | | |
| task | | | | | | | |
| implement | | | | | | | |
| reviewer | | | | | | | |
| learning | | | | | | | |
| **total** | | | | | | | |

| Waited for a human at | Minutes | Ended by |
| --- | --- | --- |
| <gate> | | <label · /approve · comment · timeout> |

## Findings and escalations

| Cycle | Gate | Severity | Finding (one line) | Recurred |
| --- | --- | --- | --- | --- |
| 0 | <gate> | BLOCKER | <what, where> | no |

- **Escalations:** <phase → phase: the gap, in one line> · or "none"
- **Human feedback:** <what the /rework or comments asked for, in one line each> · or "none"

## Frictions

<!-- Only what cost time or tokens or forced a judgement call. One bullet each, ending with the suggestion and its target. -->

- <what happened, where (agent step, sdd command, gate item)> → **suggestion:** <concrete change> · **target:** constitution | config | plugin: <agent|script|gate>

## What worked

- <one line each: a step, a rule or a check that saved a cycle or caught a real defect> · or "nothing notable"
