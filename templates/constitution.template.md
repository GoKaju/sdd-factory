# Constitution — <project name> · v1.0.0

This file is the only rule file in the repository. `CLAUDE.md` and `AGENTS.md` point here and contain nothing else. Rules are one line each; how each rule is checked lives in the reviewer agents of the `sdd-factory` plugin, not here.

## Identity

- **Purpose:** <one sentence: what the system does and for whom>
- **Domains:** <list of `docs/<domain>/` names>
- **Issue types:** Feature · Change · Bug · Task · Constitution (native tracker types; the type decides the SDD path)
- **Language:** <en | es> — prose, issue forms and tracker comments (rule C4)

## Rules

### Architecture
- **A1** Packages are `apps/`, `contexts/`, `libs/`; dependencies flow `apps → contexts → libs`, never sideways or upward.
- **A2** A context never imports another context; contexts communicate only through domain events.
- **A3** Only `apps/` and `infrastructure/` know the runtime; domain and application never import cloud, OS, HTTP or framework APIs.

### Domain and application
- **D1** Every building block extends the shared base: `AggregateRoot`, `Entity`, `ValueObject`, `DomainEvent`, `DomainError`.
- **D2** Aggregates expose `create()` (invariants, ids, defaults, events) and `rehydrate()` (exact reconstruction, nothing else); both accept only domain objects.
- **D3** Value Objects are immutable, validate on construction and offer `fromOptional()` for nullable input; never pass `null` to `create()`.
- **D4** Aggregates expose getters, never serialization methods; persistence mappers read the getters.
- **D5** Use cases orchestrate only: no id generation, no default derivation, no business rules, no catching domain errors, no `Result` wrappers.
- **D6** Commands and queries are plain data without validation libraries; input is validated at the entry point.
- **D7** Queries go through read repositories that return Views; a use case never hydrates an aggregate to build a view.
- **D8** Persist first, publish events after; every event consumer is idempotent.

### Errors
- **E1** One `DomainError` subclass per scenario, `name` equals the class name, business message, no infrastructure detail.
- **E2** Domain throws, application propagates, the entry point translates once.

### Multi-tenancy
- **T1** `tenantId` appears only in infrastructure adapter constructors; never in domain, application, events or method parameters.
- **T2** Tenant-scoped adapters are built per request and never shared; stateless adapters may be.
- **T3** The tenant key is part of every record's identity; uniqueness is per tenant; no unscoped reads.
- **T4** Every repository test proves tenant isolation.

### Tests
- **Q1** Doubles hierarchy: real object > Fake > stub > spy > mock; every port ships its `InMemory` fake.
- **Q2** Module mocking is banned; third-party libraries and domain objects are never mocked.
- **Q3** Assert state or results, not interactions; each use case has at least one zero-mock test.
- **Q4** Every `DomainError` has a test asserting its exact type.
- **Q5** Deleting, skipping or weakening a test is a BLOCKER unless the Spec changed.

### Code
- **C1** Strict typing, no escape hatches, no unused symbols, named exports only (config files excepted).
- **C2** kebab-case files without type suffixes; infrastructure files are `{technology}-{port}`.
- **C3** No comments, except one line explaining a non-obvious *why*.
- **C4** Domain identifiers in English; prose in the team's language.

### Workflow
- **W1** Branch from `main`, Draft PR immediately with `Closes #N`; never push to `main`.
- **W2** Conventional Commits scoped by package; never rewrite published history.
- **W3** Shared dependency versions live in the workspace catalog.
- **W4** Spec, Design and this Constitution change only through their own Issue types; agents never edit them in passing.

## Decisions

| Concern | Decision |
| --- | --- |
| Runtime(s) | <cloud provider / on-premise / desktop> |
| Persistence | <engine>; tenant mapping in each context's `infrastructure/persistence/README.md` |
| Transport / messaging | <HTTP framework, RPC protocol> / <queue, bus, outbox> |
| Frontend | <framework + design system package, or "none"> |
| Deployment | <serverless / container / monolith / installer>; procedure in `infra/` |

## Commands

```bash
pnpm install --frozen-lockfile
pnpm lint          # 1
pnpm typecheck     # 2
pnpm build         # 3
pnpm coverage      # 4  runs the tests; CI order is fixed
```

## Verification

- **Review Gates:** Spec Compliance · Design & Architecture · Test Strategy · Security · Regression · Code Quality
- **max_rework_cycles:** 3
- **Test exemplars:** <domain test> · <zero-mock use-case test> · <tenant-isolation test>

## Agents

Provided by the `sdd-factory` plugin: `completeness-checker`, `spec-reviewer`, `design-reviewer`, `test-reviewer`, `security-reviewer`, `regression-reviewer`, `quality-reviewer` (all read-only), `ci-runner` (runs the Commands above), `committer` (git only, no push to `main`).

## Amendments

Issue of type `Constitution` + human approval + version bump. Normal Issues never edit this file.
