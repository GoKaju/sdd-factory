---
description: Write the execution contract for an issue as the marked Task comment with a step checklist. Requires sdd:design-approved (Feature, Change) or sdd:ready (Bug, Task, Constitution).
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
---

# /sdd-task $1

Write the Task for issue **#$1** as a single marked comment on the issue, for Approval Gate 3. Read-only on the repository.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Template: `${CLAUDE_PLUGIN_ROOT}/templates/task.template.md`.

## Steps

1. **Preconditions.** Type via `sdd-type.sh get $1`. Feature/Change: `sdd-state.sh require $1 design-approved task`. Bug/Task/Constitution: `sdd-state.sh require $1 ready task`. Read `docs/constitution.md`, the issue and its triage comment, and for Feature/Change the approved `spec.md` and `design.md` on the PR branch (`sdd-pr.sh branch $1`; `git show origin/<branch>:docs/...` if not checked out).

2. **Bug and Task path.** There is no PR yet. Confirm from the triage comment which spec requirement is violated (Bug) or that no behavior changes (Task). If you find the root cause is in the spec or the design, **stop**: run `sdd-type.sh set $1 Change`, `sdd-state.sh set $1 triage`, and explain in the issue why (escalation rule).

3. **Task.** Fill `task.template.md`. The Task contains **only what constitution, spec and design do not already say**:
   - **Objective** as observable outcome.
   - **Steps** as an ordered checklist, each naming the design element it realizes and the requirement IDs it covers, ordered so the build stays green after every step.
   - **Decisions the design left open** (file names it did not fix, defaults the spec allows either way). Decide them here so a fresh agent does not improvise.
   - **Tests not derivable** from the spec's acceptance criteria, the design's error table or the constitution's Q/T rules (e.g. a shared contract suite). Do not list the derivable ones.
   - **Constraints specific to this issue**: only what does not follow from constitution, spec or design ("no real clock adapter in this feature"). Never restate rules; never repeat the implementation skill's own guardrails.
   - No file inventory: the design's Layout fixes where things live and the naming rules fix the names. No verification commands: the constitution's Commands section is the verification.

4. **Comment.** `sdd-comment.sh upsert $1 sdd:task <file>`. Re-running edits the same comment.

5. **State.** `sdd-state.sh set $1 task`. Report the steps and ask the human to review the comment and set `sdd:task-approved`. You never set it.

## Rules

- The Task never redefines requirements or design. If either is insufficient, say so instead of filling the gap with your own decisions.
- Keep it executable by a fresh agent with no memory of this conversation.
