---
name: sdd-status
description: Show the SDD state of one issue or of every open issue - type, state, PR, pending approval, next command. Read-only.
argument-hint: "[issue-number]"
disable-model-invocation: true
---

# /sdd-status [N]

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`.

If an issue number is given, report that issue; otherwise `gh issue list --state open --json number,title` and report each.

For each issue print one row: number · title · `sdd type get` · `sdd state get` · linked PR (`sdd pr find`) with draft/ready · open triage or task checkboxes (`sdd comment open <n> sdd:triage` / `sdd:task`) · pending `/rework` comments in `final-review` (`sdd rework pending <n>`) · **who acts next**:

| State | Next |
| --- | --- |
| none | `/sdd-triage N` |
| triage | author answers, then a human sets `sdd:ready` (or `/sdd-triage N` again) |
| ready | Feature/Change: `/sdd-spec N` · Bug/Task/Constitution: `/sdd-task N` |
| spec | human reviews the PR diff, sets `sdd:spec-approved` |
| spec-approved | `/sdd-design N` |
| design | human sets `sdd:design-approved` |
| design-approved | `/sdd-task N` (or `/sdd-review N` when the Task already exists with every step ticked: document-only amendment) |
| task | human reviews the Task comment, sets `sdd:task-approved` |
| task-approved, rework | `/sdd-implement N` |
| implementing | implementation in progress (resume with `/sdd-implement N`) |
| in-review | `/sdd-review N` |
| final-review | human: Approval Gate 4 on the PR — merge, or a `/rework` comment listing what must change; then `/sdd-implement N` turns the bullets into Task steps and continues |

Read-only. Change nothing.
