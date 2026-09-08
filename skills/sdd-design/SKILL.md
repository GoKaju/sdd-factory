---
name: sdd-design
description: Write or update design.md for an issue from its approved spec - full variant (domain model) or light variant. Requires state sdd:spec-approved.
argument-hint: "<issue-number>"
disable-model-invocation: true
---

# /sdd-design N

Produce the technical design for issue **#N** and leave it in the Draft PR for Approval Gate 2.

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`. Design template: `templates/design.template.md`; ADR template: `templates/adr.template.md`.

## Steps

1. **Preconditions.** `sdd state require N spec-approved design`. When the issue comes back from implementation (a design gap was escalated), the issue comment says what must change: amend only that, record the new decision as an ADR (superseding the old one if it reverses it), keep everything else. Check out `sdd pr branch N`. Read `docs/constitution.md`, the approved `spec.md` and the existing `design.md` if any. Survey the module's existing code (the paths the current design's Layout names, or the module's package) to reuse existing building blocks, ports and fakes rather than inventing parallel ones.

1b. **Record the Spec approval.** The human set `spec-approved`; the document must say so: set `status: approved` in `spec.md` and commit it (`docs(<module>): spec approved for #N`). This is the only edit to the spec this phase makes.

2. **Variant.** Full when the change touches the domain model, use cases, ports or module boundaries; light for reporting, integration glue or tooling with no domain-model impact. Say which and why.

3. **Design.** Fill the template. Every element traces to requirement IDs. Follow the constitution's rules but **never restate them**: record decisions specific to this module and cite the rule ID in parentheses when a decision exists because of it. Delete any sentence that merely repeats a rule.
   - **Boundary** is three lines: the module and what it owns; relations with other modules; whether it is scoped per customer.
   - **Errors** map one to one to the spec's Rejections, same names; messages in English with context values as params.
   - **Layout** follows the constitution's folder rules and fixes every placement decision and every file-level name the rules do not determine. The Task never decides names; if it needs one you did not fix, the issue comes back here.
   - **Prefer the simplest structure that satisfies the rules.** Every extra class or indirection must earn its place in a decision.
   - **Decisions are ADRs.** A real decision (a choice between alternatives with consequences) is one file `docs/adrs/<NNNN>-<slug>.md` (next free number). The design's `### Decisions` only links them. Reversing a decision never edits the old ADR: write a new one and mark the old `Superseded by ADR-<NNNN>`.
   - **The design is the current state of the module; git is the history.** No "changes to existing code", no "not in this change", no per-issue annotations. What this change touches, leaves out or leaves for Task goes in the **PR description** (`gh pr edit --body`). Set `status: draft`.

4. **One pass, no self-review.** Do not launch a reviewer on the document: the human judges it at Approval Gate 2 and the Review Gates judge it again against the code. Report in the PR description what you left open for the human.

5. **Commit and push** per `templates/commits.md`: `docs(<module>): design for #N` (ADRs in the same commit).

6. **State.** `sdd state set N design`. Report the PR URL, the variant, the ADRs created or superseded and any concern. The human sets `sdd:design-approved`; you never set it.

7. **Say what comes next.** If the issue came back for a **document-only amendment** (the Task comment exists with every step ticked and the amendment needs no code change), say that after `design-approved` the next command is `/sdd-review N`, not `/sdd-task N`. Otherwise it is `/sdd-task N`.

## Rules

- Do not edit `spec.md` beyond step 1b. If the design reveals a gap in the spec, stop and report it; the issue may need to go back to `spec`.
- No source code or tests in this phase.
