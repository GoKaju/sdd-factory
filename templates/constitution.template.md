# Constitution — <project name> · v1.0.0

This file is the only rule file in the repository. `CLAUDE.md` points here and contains nothing else. Rules are one line each with a stable ID; the Review Gates of the `sdd-factory` plugin check them exactly as written, so a rule that is not here is not enforced. How the factory *operates* (language, models, delegated gates, rework budget, check commands) is not a rule: it lives in `.sdd/config.yml`.

## Identity

- **Purpose:** <one sentence: what the system does and for whom>
- **Domains:** <list of `docs/<domain>/` names>
- **Issue types:** Feature · Change · Bug · Task · Constitution (native tracker types; the type decides the SDD path)

## Rules

<!-- One rule per line, `<Letter><n>` IDs unique within their block. Add the blocks your stack needs
     (Architecture, Domain, Errors, Tests, Code…) and keep the Workflow block: it is what the SDD flow relies on.
     A ready-made rule set for DDD / TypeScript / multi-tenant is in the plugin's templates/examples/. -->

### Architecture
- **A1** <packages or layers and the allowed dependency direction>
- **A2** <what may know the runtime, framework, storage; what may not>

### Domain
- **D1** <how business rules are modelled and where they live>

### Errors
- **E1** <one named error per rejection of a spec; who throws, who translates>

### Tests
- **Q1** <test-double policy: what may be faked, what may never be mocked>
- **Q2** <what every requirement's test must assert: state or result, exact rejection type>
- **Q3** Deleting, skipping or weakening a test is a BLOCKER unless the Spec changed.

### Code
- **C1** Everything inside code is English — identifiers, comments, test names, log and developer-facing error text; only end-user messages and prose documents use the language configured in `.sdd/config.yml`.
- **C2** <typing, lint and comment policy>

### Workflow
- **W1** Branch from `main`, Draft PR immediately with `Closes #N`; never push to `main`.
- **W2** Conventional Commits scoped by package; never rewrite published history.
- **W3** Spec, Design, ADRs and this Constitution change only through their own Issue types; agents never edit them in passing.
- **W4** Every design decision with alternatives is one immutable ADR under `docs/adrs/`; a reversal supersedes, never edits.

## Decisions

| Concern | Decision |
| --- | --- |
| Runtime(s) | <cloud provider / on-premise / desktop> |
| Persistence | <engine> |
| Transport / messaging | <HTTP framework, RPC protocol> / <queue, bus, outbox> |
| Frontend | <framework, or "none"> |
| Deployment | <how and from where> |

## Verification

- **Review Gates:** Spec Compliance · Design & Architecture · Test Strategy · Security · Regression · Code Quality
- **Test exemplars:** <one test file per kind the gates should hold new tests to, or "none yet">
- The deterministic checks (`sdd ci`), the rework budget and the delegated gates are configured in `.sdd/config.yml` (`/sdd-config`).

## Amendments

Issue of type `Constitution` + human approval + version bump (major: a rule removed or relaxed; minor: a rule added; patch: wording). Normal Issues never edit this file.
