# Constitution — <project name> · v1.0.0

This file is the only rule file in the repository. `CLAUDE.md` and `AGENTS.md` point here and contain nothing else. Rules are one line each with a stable ID; the Review Gates of the `sdd-factory` plugin check them exactly as written, so a rule that is not here is not enforced.

## Identity

- **Purpose:** <one sentence: what the system does and for whom>
- **Domains:** <list of `docs/<domain>/` names>
- **Issue types:** Feature · Change · Bug · Task · Constitution (native tracker types; the type decides the SDD path)
- **Language:** <en | es> — prose, issue forms and tracker comments (rule C1)

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
- **C1** Everything inside code is English — identifiers, comments, test names, log and developer-facing error text; only end-user messages and prose documents use `Language`.
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

## Commands

The deterministic checks, in CI order. `sdd ci` runs exactly this block, fail-fast; Review Gates never run on a red build.

```bash
<install with a frozen lockfile>
<lint>
<typecheck>
<build>
<tests with coverage>
```

## Verification

- **Review Gates:** Spec Compliance · Design & Architecture · Test Strategy · Security · Regression · Code Quality
- **Rework budget:** 3 — review cycles before the issue stops as NEEDS_HUMAN
- **Delegated gates:** none — human approval gates an orchestrator may grant on its own once the artifact is verifiably clean: any of `Intake`, `Spec`, `Design`, `Task`, `Final`; add `(judged)` to require the reviewer's verdict first, e.g. `Intake, Spec (judged), Task`. A Constitution issue is never merged by a machine.
- **Warnings at Final:** human — what a delegated `Final` does when every gate is PASS but WARNINGs remain: `human` holds the PR for a person (default); `rework` files a `/rework` with the code WARNINGs (bounded by the Rework budget; documentation WARNINGs are listed for a Change instead); `merge` merges and lists them on the PR.
- **Test exemplars:** <one test file per kind the gates should hold new tests to, or "none yet">

## Agents

Provided by the `sdd-factory` plugin: `reviewer` (read-only, runs the gates in `gates/`). Everything else is done by the main agent through the `/sdd-*` skills.

## Amendments

Issue of type `Constitution` + human approval + version bump (major: a rule removed or relaxed; minor: a rule added; patch: wording). Normal Issues never edit this file.
