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

1. **Preconditions.** `sdd-state.sh require $1 spec-approved design`. Check out the PR branch (`sdd-pr.sh branch $1`). Read `docs/constitution.md`, the approved `spec.md` and the existing `design.md` if any. Survey the affected context under `contexts/` to reuse existing aggregates, ports and fakes rather than inventing parallel ones.

2. **Variant.** Full when the change touches aggregates, use cases, ports or context boundaries. Light when it is reporting, integration glue or tooling with no domain-model impact. Say which and why.

3. **Design.** Fill the template. Every element must trace to requirement IDs. Follow the constitution's rules but **never restate them**: the design records decisions specific to this module and cites a rule ID in parentheses when a decision exists because of it ("`Today` enters through the `Clock` port (D5)"). Delete any sentence that merely repeats a rule (naming conventions, layering, tenancy mechanics). Rules for the content:
   - **Bounded Context** is three lines: context and what it owns; relations with other contexts; multi-tenant yes or no.
   - **Domain Errors** map one to one to the spec's Rejections, same names, messages in English with context values as params; the client shows and translates the spec's user message.
   - **Layout** states only placement decisions specific to this module. **No file inventory, no test list**: they belong to the Task.
   - **Prefer the simplest structure that satisfies the rules.** Loading an aggregate by id and throwing its NotFound error is orchestration and stays in the use case; do not wrap it in a "finder" domain service. Domain services exist for rules that need more than one aggregate (uniqueness across a collection) or pure calculations worth naming (a planner). Every extra class must earn its place in a Decisions row.
   - Record decisions and the alternatives rejected. Set `status: draft`.

4. **Self-review.** Run the `design-reviewer` agent on the design file with the spec as context. Fix BLOCKERs; report WARNINGs.

5. **Commit.** Delegate to `committer`: `docs(<module>): design for #$1`. Push the branch.

6. **State.** `sdd-state.sh set $1 design`. Report the PR URL, the variant, the main design decisions and any WARNING. The human sets `sdd:design-approved`; you never set it.

## Rules

- Do not edit `spec.md`. If the design reveals a gap in the spec, stop and report it; the issue may need to go back to `spec`.
- No source code or tests in this phase.
