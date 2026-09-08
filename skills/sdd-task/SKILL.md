---
name: sdd-task
description: Write the execution plan for an issue as the marked Task comment with a step checklist. Requires sdd:design-approved (Feature, Change) or sdd:ready (Bug, Task, Constitution).
argument-hint: "<issue-number>"
disable-model-invocation: true
---

# /sdd-task N

Write the Task for issue **#N** as a single marked comment on the issue, for Approval Gate 3. Read-only on the repository except for recording the design approval (step 1b).

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`. Comment template: `templates/comments/<lang>/task.md` with `lang=$(sdd lang)`; the whole comment is written in that language; the marker, the `- [ ] **T<n>**` step syntax and identifiers stay as they are.

## Steps

1. **Preconditions.** `sdd type get N`. Feature/Change: `sdd state require N design-approved task`. Bug/Task/Constitution: `sdd state require N ready task`. Read `docs/constitution.md`, the issue and its triage comment, and for Feature/Change the approved `spec.md` and `design.md` on the PR branch (`sdd pr branch N`; `git show origin/<branch>:docs/...` if not checked out).

1a. **Document-only loop.** If a Task comment already exists with every step ticked and the approved amendment requires no code change, do not rewrite the Task: record the design approval (1b), `sdd state set N in-review`, and report that `/sdd-review N` is next. An identical Task is never re-approved.

1b. **Record the Design approval** (Feature/Change only). Set `status: approved` in `design.md` and commit it on the PR branch (`docs(<module>): design approved for #N`, per `templates/commits.md`). This is the only repository write this phase makes.

2. **Bug and Task path.** There is no PR yet. Confirm from the triage which requirement is violated (Bug) or that no behavior changes (Task). If the root cause is in the spec or the design, **stop**: `sdd type set N Change`, `sdd state set N triage`, and explain in the issue why.

3. **Task.** Fill the template. The Task is an **execution plan and nothing else**: objective as observable outcome, and an ordered checklist of steps, each naming the design element it realizes and the requirement IDs it covers, ordered so the build stays green after every step.
   - **The Task never decides.** File names, test suites, exclusions, defaults: if the plan needs one the design does not fix, stop, `sdd state set N design`, and comment on the issue exactly what the design must add.
   - No file inventory, test list, verification commands, definition of done or constraints: the design, the constitution and the implement skill carry them.

4. **Comment.** `sdd comment upsert N sdd:task -` fed by a heredoc on stdin. Re-running edits the same comment.

5. **State.** `sdd state set N task`. Report the steps and ask the human to review the comment and set `sdd:task-approved`. You never set it.

## Rules

- The Task never redefines requirements or design and never decides what they left open: it sends the issue back to `design` with the exact gap.
- Keep it executable by a fresh agent with no memory of this conversation.
