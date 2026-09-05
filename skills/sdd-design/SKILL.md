---
description: Write or update design.md for an issue from its approved spec - full DDD variant or light variant. Requires state sdd:spec-approved.
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /sdd-design $1

Produce the technical design for issue **#$1** and leave it in the Draft PR for Approval Gate 2.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Template: `${CLAUDE_PLUGIN_ROOT}/templates/design.template.md`.

## Steps

1. **Preconditions.** `sdd-state.sh require $1 spec-approved design`. When the issue comes back from implementation (a design gap was escalated), the issue comment says what must change: amend only that, record the new decision as an ADR (superseding the old one if it reverses it), and keep everything else untouched. Check out the PR branch (`sdd-pr.sh branch $1`). Read `docs/constitution.md`, the approved `spec.md` and the existing `design.md` if any. Survey the affected context under `contexts/` to reuse existing aggregates, ports and fakes rather than inventing parallel ones.

1b. **Record the Spec approval.** The human set `spec-approved`; the document must say so: set `status: approved` in `spec.md`'s front matter and commit it (`docs(<module>): spec approved for #$1`). This is the only edit to the spec this phase makes.

2. **Variant.** Full when the change touches aggregates, use cases, ports or context boundaries. Light when it is reporting, integration glue or tooling with no domain-model impact. Say which and why.

3. **Design.** Fill the template. Every element must trace to requirement IDs. Follow the constitution's rules but **never restate them**: the design records decisions specific to this module and cites a rule ID in parentheses when a decision exists because of it ("`Today` enters through the `Clock` port (D5)"). Delete any sentence that merely repeats a rule (naming conventions, layering, tenancy mechanics). Rules for the content:
   - **Bounded Context** is three lines: context and what it owns; relations with other contexts; multi-tenant yes or no.
   - **Domain Errors** map one to one to the spec's Rejections, same names, messages in English with context values as params; the client shows and translates the spec's user message.
   - **Layout** follows the folder rule of the constitution (A4: subfolders per kind inside each aggregate, adapter families in infrastructure, one folder per use case) and states placement decisions and every file-level name the naming rules do not determine (mapper files, contract suites, shared helpers). The Task never decides names; if it needs one you did not fix, the issue comes back here.
   - **Prefer the simplest structure that satisfies the rules.** Loading an aggregate by id and throwing its NotFound error is orchestration and stays in the use case; do not wrap it in a "finder" domain service. Domain services exist for rules that need more than one aggregate (uniqueness across a collection) or pure calculations worth naming (a planner). Every extra class must earn its place in a Decisions row.
   - **Decisions are ADRs, not table rows.** A real decision — a choice between alternatives with consequences — becomes one file `docs/adrs/<NNNN>-<slug>.md` from `templates/adr.template.md` (next free number, four digits). The design's `### Decisions` section only lists the ADRs it relies on, one line each with a link. Reversing an earlier decision never edits the old ADR: write a new one and mark the old `Superseded by ADR-<NNNN>`. ADRs are immutable history; the design is the current truth.
   - **The design is the current state of the module; git is the history.** No "changes to existing code", no "not in this change", no "corrected after Gate 4", no per-Issue annotations inside the document. What this change touches in existing code, what it deliberately leaves out and what Design leaves for Task go in the **PR description** (`gh pr edit --body`), where the human, the Task phase and the reviewers read them. Set `status: draft`.

4. **Self-review, one pass.** Run the `design-reviewer` agent once, giving it only `design.md`, `spec.md` and the constitution (no code tree: this is a document review). Fix its BLOCKERs once and deliver without rerunning; report WARNINGs and anything you left for the human at Gate 2. Never loop.

5. **Commit.** Delegate to `committer`: `docs(<module>): design for #$1`. Push the branch.

6. **State.** `sdd-state.sh set $1 design`. Report the PR URL, the variant, the ADRs created or superseded and any WARNING. The human sets `sdd:design-approved`; you never set it.

7. **Say what comes next.** If the issue came back from review or implementation for a **document-only amendment** (the Task comment exists with every step ticked and no code changes are required by the amendment), state explicitly that after `design-approved` the next command is `/sdd-review $1`, not `/sdd-task $1`: an identical Task is not re-approved. Otherwise the next command is `/sdd-task $1`.

## Rules

- Do not edit `spec.md`. If the design reveals a gap in the spec, stop and report it; the issue may need to go back to `spec`.
- No source code or tests in this phase.
