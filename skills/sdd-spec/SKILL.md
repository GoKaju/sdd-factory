---
description: Write or update the module spec for an issue - branch, Draft PR, spec.md with stable requirement IDs, completeness check. Requires state sdd:ready and type Feature or Change.
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /sdd-spec $1

Produce the specification for issue **#$1** and leave it in a Draft PR for Approval Gate 1.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Template: `${CLAUDE_PLUGIN_ROOT}/templates/spec.template.md`.

## Steps

1. **Preconditions.** `sdd-state.sh require $1 ready spec` and `sdd-type.sh require $1 Feature Change`. Read `docs/constitution.md`, the issue (`gh issue view $1 --comments`) and its triage comment (`sdd-comment.sh get $1 sdd:triage`) for the affected `docs/<domain>/<module>/`.

2. **Branch and Draft PR.** If `sdd-pr.sh find $1` is empty: `git checkout main && git pull`, create `<type>/$1-<slug>` (`feat/` or `change/`), then `sdd-pr.sh open $1 <branch> "<type>: <title>"`. Otherwise check out the PR's branch (`sdd-pr.sh branch $1`).

3. **Spec.** For a new module copy `spec.template.md` to `docs/<domain>/<module>/spec.md`; for an existing one edit it. Rules:
   - Every requirement has a stable ID `<MODULE>-NNN`; never renumber or reuse an ID. New requirements take the next number; a Change edits the text of existing IDs and marks superseded ones as `Removed` rather than deleting them.
   - Describe observable behavior, not implementation. Use EARS forms where they add precision.
   - **Business language only.** The reader is the person who opened the Issue. These words and ideas MUST NOT appear anywhere in the spec: tenant, tenancy, isolation, `tenantId`, repository, persistence, database, engine, fake, `InMemory`, view, read model, projection, event, publish, consumer, idempotent, delivery, concurrency, lock, HTTP, API, endpoint, frontend, test, class, layer, aggregate, use case. If a behavior needs one of them to be stated, restate it as what the user observes ("completing the same task twice never produces two next occurrences") or move it to `design.md`. Multi-tenancy is a separate concern governed by the constitution; the spec is written as if a single customer existed.
   - **Out of scope** lists business capabilities deliberately excluded (e.g. "renaming lists", "reminders"). Never deferred technical decisions (pagination, concurrency control, HTTP, storage engine).
   - **Domain concepts** are business nouns only. No projections, DTOs, views, records or ports.
   - **Rejections, not errors.** Every business reason to refuse a request is one row of the "Rejections" table: stable English name (`TaskAlreadyCompleted`), condition in business terms, message to the user, requirement ID. Plus the checking order when several apply. The spec never says "error", "DomainError", "class" or "exception"; the design maps each rejection to one domain error.
   - Cover edge cases and acceptance criteria per requirement. List open questions explicitly.
   - Set `status: draft`.

4. **Completeness check.** Run the `completeness-checker` agent on the spec. If it returns `FAIL`, fix the spec and rerun until `PASS`, or list the questions the human must answer.

5. **Commit.** Delegate to the `committer` agent: `docs(<module>): spec for #$1`. Push the branch (never `main`).

6. **State.** `sdd-state.sh set $1 spec`. Report the PR URL, the requirement IDs added or changed, and the open questions. The human reviews the diff in the PR and sets `sdd:spec-approved`; you never set it.

## Rules

- Never touch `design.md`, source code or tests in this phase.
- A Change that finds the current spec wrong about *existing* behavior corrects the spec and says so in the PR; that is the one place where the spec is edited to match reality, with a human approving it.
