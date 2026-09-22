# Gate · structure

**Question:** is the code built the way the approved design, the constitution and the blueprint say, and is it as simple as it can be? Look for drift from the design, broken boundaries, misplaced logic, over-engineering and code that is hard to maintain. A BLOCKER points at a design element, a constitution rule or code that is objectively wrong; preference is a NIT; formatting is never a finding.

## Procedure

1. Read the constitution's rules and the blueprint; then `design.md`, `spec.md` (its vocabulary is the naming reference) and the ADRs the design links or the PR adds.
2. Read the diff, then every changed file **in full** plus its neighbors (package index, mappers, wiring, tests) and the sibling files it duplicates or could reuse: a violation often lives in the file that was not changed.
3. Walk the checklist; cite `path:line` and give the concrete fix or the simpler alternative.

## Checklist

### 1. Conformance to design.md — BLOCKER
- Every element the Design names (each row of Components with its Location, each Error, each Contract) exists with that name, in that place.
- No element the Design does not declare: a new port, event, use case, table or entry point is BLOCKER; a purely internal helper is WARNING.
- Decisions recorded in the linked ADRs are honored; a decision reversed in code without a superseding ADR is a deviation.
- Any element implemented differently from the Design (placement, collaborator, shape, name) without the design amended through the plan phase → BLOCKER. A note in the PR body does not count: merged code and design must say the same thing.
- Files changed outside the Design's Locations and Boundary: the `mechanical` result lists them as WARNINGs; raise one to BLOCKER only when the file adds behavior the design does not declare.

### 2. Constitution rules — BLOCKER when the constitution states the rule
Check each rule as written; where the constitution is silent, the item does not apply. Typical checks:
- Dependency direction and forbidden imports between the packages or layers it names (grep imports across boundaries); code that must not know the runtime, framework, cloud SDK or storage driver.
- Domain and application rules: orchestration-only use cases, persistence before publication, validation at the entry point, and whatever else the constitution states.
- Errors: one per rejection of the Spec, same name, no infrastructure detail in the message; raised, propagated and translated where the rule says.
- Isolation boundary (tenant, organization, workspace): the key placed where the rule says, never in method parameters, domain objects or events; scoped adapters built per request; the key part of every stored identity; no unscoped reads.
- Language: anything added to the repository in a language other than English (comments, docstrings, identifiers, test names, logs, developer-facing errors, READMEs) breaks C1 → BLOCKER; the `mechanical` result lists suspect lines. End-user message strings are exempt.
- Type and lint strictness: type escapes (`any`, `# type: ignore`, `@ts-ignore`), lint-disable directives, casts used to silence the compiler.

### 3. Blueprint — WARNING
- An element placed, named or shaped differently from the blueprint's row for its kind (location, file name, base class or shape), or built unlike its exemplar, when the design does not fix it otherwise. A kind the blueprint does not list → NIT proposing a Constitution issue to add it. Never BLOCKER.

### 4. Simplicity — WARNING (NIT when arguable)
- A service or abstraction whose only job is orchestration the caller could do; interfaces with a single implementation and no port role; helpers, base classes or utilities used once; indirection not traceable to a requirement or a rule.
- Parameters or configuration for values that never vary; flags with one state; caches, batching or memoization without a requirement or a measurement; clever code where a plain conditional would do.
- Same logic twice in the diff, or copied from an existing file when a shared function exists.

### 5. Clarity — WARNING (NIT for taste)
- Names that mislead or diverge from the Spec's vocabulary (Spec says `Payslip`, code says `PayDoc`); abbreviations, `data`/`info`/`manager`/`helper`/`util`; booleans not phrased as predicates.
- Comments that describe what a line does, section separators, docstrings restating a signature; longer than the constitution's comment rule allows. (`TODO`/`FIXME` are flagged by `mechanical`.)

### 6. Dead code and error handling — BLOCKER when objectively wrong
- Commented-out code, unreachable branches, leftover debug output: BLOCKER. Unused exports, parameters and imports: WARNING.
- `catch` blocks that swallow, log-and-continue or rethrow adding nothing; catch-alls that turn a specific error into a generic failure before the translation point; lost promise or future rejections: BLOCKER. Messages mixing business meaning with infrastructure detail: WARNING.

### 7. Observability — WARNING
- Entry points log structured events with a correlation id; errors logged once at the translation point; new scheduled or long-running work can be seen to have run.

### 8. Documents in the PR — WARNING, NIT if minor
- When the PR edits `design.md`: sentences restating a constitution rule, a file inventory or test list, error names not matching the Spec's Rejections, narration of history.
- When the PR adds or edits ADRs: an ADR failing any of the four tests of `templates/adr.template.md` → `required_action: fold into design.md as a one-line note`; a boundary, contract, persisted format or repository-wide library chosen with no ADR; more than two ADRs without justification in the PR description.

`NEEDS_HUMAN` when the Design and the constitution genuinely conflict and you cannot rank them.
