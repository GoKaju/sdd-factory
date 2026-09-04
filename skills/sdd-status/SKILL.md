---
description: Show the SDD state of one issue or of every open issue - type, state, PR, pending approval, next command.
argument-hint: "[issue-number]"
disable-model-invocation: true
allowed-tools: Bash, Read
---

# /sdd-status $ARGUMENTS

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`.

If an issue number is given, report that issue; otherwise `gh issue list --state open --json number,title` and report each.

For each issue print one row: number · title · `sdd-type.sh get` · `sdd-state.sh get` · linked PR (`sdd-pr.sh find`) with draft/ready · open triage or task checkboxes (`sdd-comment.sh open <n> sdd:triage` / `sdd:task`) · **who acts next**:

| State | Next |
| --- | --- |
| none | `/sdd-triage <n>` |
| (+ `sdd:working`) | the worker is running a phase on it right now; wait |
| triage | author answers, then human sets `sdd:ready` (or `/sdd-triage <n>` again) |
| ready | Feature/Change: `/sdd-spec <n>` · Bug/Task/Constitution: `/sdd-task <n>` |
| spec | human reviews the PR diff, sets `sdd:spec-approved` |
| spec-approved | `/sdd-design <n>` |
| design | human sets `sdd:design-approved` |
| design-approved | `/sdd-task <n>` (or `/sdd-review <n>` when the Task already exists with every step ticked: document-only amendment) |
| task | human reviews the Task comment, sets `sdd:task-approved` |
| task-approved, rework | `/sdd-implement <n>` |
| implementing | implementation in progress |
| in-review | `/sdd-review <n>` |
| final-review | human: Approval Gate 4 on the PR, then merge |

Read-only. Change nothing.
