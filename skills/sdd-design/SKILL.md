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

3. **Design.** Fill the template. Every element must trace to requirement IDs. Respect the constitution's rules: aggregates with `create`/`rehydrate`, value objects, one `DomainError` per scenario, use cases that orchestrate only, read repositories for queries, every port with its `InMemory` fake, `tenantId` only in adapter constructors, contexts communicating by events only. Record decisions and the alternatives rejected. Set `status: draft`.

4. **Self-review.** Run the `design-reviewer` agent on the design file with the spec as context. Fix BLOCKERs; report WARNINGs.

5. **Commit.** Delegate to `committer`: `docs(<module>): design for #$1`. Push the branch.

6. **State.** `sdd-state.sh set $1 design`. Report the PR URL, the variant, the main design decisions and any WARNING. The human sets `sdd:design-approved`; you never set it.

## Rules

- Do not edit `spec.md`. If the design reveals a gap in the spec, stop and report it; the issue may need to go back to `spec`.
- No source code or tests in this phase.
