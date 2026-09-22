# Constitution — <project name> · v1.0.0

The only rule file in the repository; `CLAUDE.md` points here. Rules are one line each with a stable ID and the Review Gates check them exactly as written: a rule that is not here is not enforced. Keep it short: a rule belongs here only when breaking it is a BLOCKER. **How** things are built (folders, base classes, naming, the shape of a test) is shown, not written, in `docs/blueprint.md`. How the factory *operates* (language, models, delegated gates, check commands) lives in `.sdd/config.yml`.

## Identity

- **Purpose:** <one sentence: what the system does and for whom>
- **Domains:** <list of `docs/<domain>/` names>
- **Blueprint:** `docs/blueprint.md`

## Stack

| Concern | Decision |
| --- | --- |
| Language · runtime | <e.g. TypeScript · Node 22> |
| Persistence | <engine, or "none"> |
| Transport · messaging | <HTTP framework, RPC> · <queue, bus, or "none"> |
| Frontend | <framework, or "none"> |

## Rules

<!-- Only what fails a review when broken; aim for ten to fifteen lines. Keep the IDs; add or drop lines as the project
     needs. Conventions a reader learns from an example go in docs/blueprint.md, not here. The Workflow block and
     C1 / Q3 are the framework's own. A filled example for DDD / TypeScript / multi-tenant is in templates/examples/. -->

- **A1** <boundaries: which parts may depend on which, and what the core must never import>
- **E1** One named error per Rejection of a spec; <who raises it, who translates it for the user>.
- **Q1** <test-double policy: what may be faked, what may never be mocked>
- **Q2** Every requirement has a test asserting its observable outcome; every rejection is asserted by its exact name.
- **Q3** Deleting, skipping or weakening a test is a BLOCKER unless the Spec changed.
- **C1** Everything in the repository is English — code, identifiers, comments, docstrings, test names, logs, developer-facing error text, READMEs and every document under `docs/` (constitution, blueprint, specs, designs, ADRs), so documents carry straight into code. Only end-user messages and tracker prose (issue and PR comments, PR descriptions, issue forms) use the language configured in `.sdd/config.yml`.
- **W1** Branch from `main`, Draft PR immediately with `Closes #N`; never push to `main`. Conventional Commits; never rewrite published history.
- **W2** Spec, Design, ADRs, the Blueprint and this Constitution change only through their own Issue types; agents never edit them in passing.
- **W3** Every architecturally significant decision is one immutable ADR under `docs/adrs/`; a reversal supersedes, never edits.

## Amendments

Issue of type `Constitution` (it also covers `docs/blueprint.md`) + human approval + version bump (major: a rule removed or relaxed; minor: a rule added; patch: wording or blueprint). Normal Issues never edit either file.
