---
name: sdd-status
description: Show the SDD state of one issue or of every open issue - type, state, PR, pending approval, who acts next, run log. Read-only.
argument-hint: "[issue-number]"
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /sdd-status [N]

Conventions: `sdd` = `${CLAUDE_PLUGIN_ROOT}/bin/sdd` (`sdd help` lists its commands).

If an issue number is given, report that issue; otherwise `gh issue list --state open --json number` and report each (`sdd next <n>` per issue).

For each issue print one row: number · title · type · state · linked PR (`sdd pr find`) with draft/ready · open triage or task checkboxes (`sdd comment open <n> sdd:triage` / `sdd:task`) · pending `/rework` comments (`sdd rework pending <n>`) · live worktree (`sdd worktree list`) · **who acts next**, from the `action` of `sdd next`:

| `sdd next` | Who | What |
| --- | --- | --- |
| `run <phase>` | `/sdd N` | launches the phase (`triage`, `spec`, `design`, `task`, `implement`, `review`) |
| `approve <gate>` | `/sdd N` | verifies the artifact and grants the delegated gate (`judged`: after the reviewer) |
| `human` | a person | sets `waits_for` (label or `/approve` comment); in `final-review`: merges the PR, comments `/approve`, or comments `/rework` with one bullet per change |
| `busy` | — | a `/sdd N` run is implementing; `/sdd N` resumes it once idle |

For one issue also print `sdd log summary N` (phases, minutes, models, waits) and, if it exists, the path of `.sdd/learning/N.md` on the PR branch.

Read-only. Change nothing.
