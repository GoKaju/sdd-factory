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

3. **Task.** Fill `task.template.md`. The Task is an **execution plan and nothing else**: objective as observable outcome, and an ordered checklist of steps, each naming the design element it realizes and the requirement IDs it covers, ordered so the build stays green after every step.
   - **The Task never decides.** File names, test suites, exclusions, defaults: if the plan needs one and the design does not fix it, stop, `sdd-state.sh set $1 design`, and comment on the issue exactly what the design must add. Do not fill the gap yourself.
   - No file inventory, no test list, no verification commands, no definition of done, no constraints: the design, the constitution and the implementation skill already carry them.

4. **Comment.** `sdd-comment.sh upsert $1 sdd:task <file>`. Re-running edits the same comment.

5. **State.** `sdd-state.sh set $1 task`. Report the steps and ask the human to review the comment and set `sdd:task-approved`. You never set it.

## Rules

- The Task never redefines requirements or design, and never decides what they left open: it sends the issue back to `design` with the exact gap.
- Keep it executable by a fresh agent with no memory of this conversation.
