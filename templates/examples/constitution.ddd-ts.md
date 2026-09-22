<!-- EXAMPLE: DDD · TypeScript · pnpm workspace · multi-tenant. Pairs with templates/examples/blueprint.ddd-ts.md:
     the rules below are what a review BLOCKS on; folders, base classes, naming and test shapes are in the blueprint. -->
# Constitution — <project name> · v1.0.0

The only rule file in the repository; `CLAUDE.md` points here. Rules are one line each with a stable ID and the Review Gates check them exactly as written. **How** things are built is shown in `docs/blueprint.md`. How the factory operates lives in `.sdd/config.yml`.

## Identity

- **Purpose:** <one sentence: what the system does and for whom>
- **Domains:** <list of `docs/<domain>/` names>
- **Blueprint:** `docs/blueprint.md`

## Stack

| Concern | Decision |
| --- | --- |
| Language · runtime | TypeScript (strict) · <Node version / serverless runtime> |
| Persistence | <engine> |
| Transport · messaging | <HTTP framework, RPC> · <queue, bus, outbox> |
| Frontend | <framework + design system package, or "none"> |

## Rules

- **A1** Dependencies flow `apps → contexts → libs`; a context never imports another context and talks to it only through domain events.
- **A2** Domain and application never import runtime, framework, cloud, HTTP or storage APIs; only `apps/` and `infrastructure/` do.
- **D1** Use cases orchestrate only: no business rules, no id generation, no catching domain errors. Business rules live in the domain.
- **D2** Persist first, publish events after; every event consumer is idempotent.
- **T1** The tenant is fixed when an infrastructure adapter is built, never passed through domain, application, events or method parameters; the tenant key is part of every stored identity and no read is unscoped.
- **E1** One named domain error per Rejection of a spec; domain raises, application propagates, the entry point translates once.
- **Q1** Ports are replaced by their fakes; module mocking is banned and third-party libraries and domain objects are never mocked.
- **Q2** Every requirement has a test asserting its observable outcome; every rejection is asserted by its exact type; every repository test proves tenant isolation.
- **Q3** Deleting, skipping or weakening a test is a BLOCKER unless the Spec changed.
- **C1** Everything in the repository is English — code, identifiers, comments, docstrings, test names, logs, developer-facing error text, READMEs and every document under `docs/` (constitution, blueprint, specs, designs, ADRs), so documents carry straight into code. Only end-user messages and tracker prose (issue and PR comments, PR descriptions, issue forms) use the language configured in `.sdd/config.yml`.
- **C2** Strict typing without escape hatches; no unused symbols; comments only for a non-obvious *why*.
- **W1** Branch from `main`, Draft PR immediately with `Closes #N`; never push to `main`. Conventional Commits scoped by package; never rewrite published history.
- **W2** Spec, Design, ADRs, the Blueprint and this Constitution change only through their own Issue types; agents never edit them in passing.
- **W3** Every architecturally significant decision is one immutable ADR under `docs/adrs/`; a reversal supersedes, never edits.

## Amendments

Issue of type `Constitution` (it also covers `docs/blueprint.md`) + human approval + version bump. Normal Issues never edit either file.
