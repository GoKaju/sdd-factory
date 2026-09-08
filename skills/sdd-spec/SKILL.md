---
name: sdd-spec
description: Write or update the module spec for an issue - branch, Draft PR, spec.md with stable requirement IDs, completeness check. Requires state sdd:ready and type Feature or Change.
argument-hint: "<issue-number>"
disable-model-invocation: true
---

# /sdd-spec N

Produce the specification for issue **#N** and leave it in a Draft PR for Approval Gate 1.

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`. Spec template: `templates/spec.template.md`.

## Steps

1. **Preconditions.** `sdd state require N ready spec` and `sdd type require N Feature Change`. Read `docs/constitution.md`, the issue (`gh issue view N --comments`) and its triage comment (`sdd comment get N sdd:triage`) for the affected `docs/<domain>/<module>/`.

2. **Branch and Draft PR.** If `sdd pr find N` is empty: `git checkout main && git pull`, create `<feat|change>/N-<slug>`, then `sdd pr open N <branch> "<type>: <title>"`. Otherwise check out `sdd pr branch N`.

3. **Spec.** New module: copy the template to `docs/<domain>/<module>/spec.md`; existing: edit it.
   - Every requirement has a stable ID `<MODULE>-NNN`; never renumber or reuse. New requirements take the next number; a Change edits the text of existing IDs and marks superseded ones `Removed` rather than deleting them.
   - Observable behavior, not implementation. EARS forms where they add precision.
   - **Business language only.** The reader is the person who opened the Issue. Never: tenant, isolation, repository, persistence, database, fake, view, projection, event, publish, consumer, idempotent, concurrency, lock, HTTP, API, endpoint, frontend, test, class, layer, aggregate, use case. Restate as what the user observes or move it to `design.md`. Isolation between customers is the constitution's concern; the spec reads as if a single customer existed.
   - **Out of scope** lists excluded business capabilities, never deferred technical decisions. **Domain concepts** are business nouns only.
   - **Rejections, not errors.** Every business reason to refuse a request is one row of the Rejections table (stable English name, condition, user message, requirement ID) plus the checking order. The spec never says "error", "exception" or "class".
   - Edge cases and acceptance criteria per requirement.
   - **The spec is the current state of the module; git is the history.** `## Open questions` holds only what is open right now (normally nothing; anything there blocks Gate 1). Decisions taken while writing and notes for Design go to the **PR description** (`gh pr edit --body`), never into the spec. Set `status: draft`.

4. **Completeness check, one pass.** Run the gate `gates/completeness.md`: if your host can launch a fresh-context subagent, launch the plugin's `reviewer` agent with `gates: completeness`, the spec path, issue, PR and `rework_cycle: 0`; otherwise run the checklist yourself after re-reading the spec from disk. If it returns `FAIL`, fix the BLOCKERs once and deliver without rerunning; report what you fixed and what you left, so the human sees it at Gate 1. Never loop.

5. **Commit and push** per `templates/commits.md`: `docs(<module>): spec for #N`. Never push `main`.

6. **State.** `sdd state set N spec`. Report the PR URL, the requirement IDs added or changed, and the open questions in the spec, if any. The human reviews the PR diff and sets `sdd:spec-approved`; you never set it.

## Rules

- Never touch `design.md`, source code or tests in this phase.
- A Change that finds the current spec wrong about *existing* behavior corrects the spec and says so in the PR; that is the one place where the spec is edited to match reality, with a human approving it.
