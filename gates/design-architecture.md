# Gate · design-architecture

**Question:** does the implementation conform to the approved `design.md` and to the constitution's architectural rules? Look for misplaced logic, broken boundaries and drift from the Design.

## Procedure

1. Read the constitution's architecture, domain, error and naming rules; then `design.md`, then `spec.md`. Read the ADRs the design links and the ones the PR adds.
2. Read the diff, then every changed file **in full** plus its neighbors (package index, mappers, wiring, tests): a violation often lives in the file that was not changed.
3. Walk the checklist. Cite `path:line` and give the concrete fix.

## Checklist

### A. Conformance to design.md — BLOCKER
- Every element the Design names (components, aggregates, services, use cases, ports, adapters, events, endpoints, files named in Layout) exists with that name, in that place.
- No element the Design does not declare: a new port, event, use case, table or entry point is BLOCKER; a purely internal helper is WARNING.
- Decisions recorded in the linked ADRs are honored. A decision reversed in code without a superseding ADR is a deviation.
- Any element implemented differently from the Design (placement, collaborator, shape, name) without the design amended in the same PR through the design phase → BLOCKER. A note in the PR body does not count: merged code and design must say the same thing.

### B. Boundaries and layering — BLOCKER when the constitution states the rule
Check each architecture rule of the constitution as written. Typical checks:
- Dependency direction between the packages or layers the constitution names (grep imports across package boundaries).
- Modules that must not import each other and how they may communicate instead.
- Code that must not know the runtime, framework, cloud SDK or storage driver (grep those imports in the protected layers).
- Placement of files by kind and the folder rules (flat folders, one unit per folder).

### C. Domain and application rules — BLOCKER when the constitution states the rule
Verify each domain rule of the constitution as written: base classes to extend, factory and rehydration contracts, immutability and validation of value objects, absence of serialization on domain objects, orchestration-only services, plain commands and queries, persistence before publication, read side served by projections. Where the constitution has no such rule, do not invent one; report over-engineering under E instead.

### D. Errors — BLOCKER when the constitution states the rule
- One error per rejection of the Spec, same name, message without infrastructure detail; domain throws, application propagates, the entry point translates once. Generic errors thrown where a named one is required.

### E. Isolation boundary — BLOCKER when the constitution has a tenancy or isolation rule
- The boundary key (tenant, organization, workspace) is placed where the rule says (typically adapter construction, never method parameters, domain objects or events); scoped adapters built per request, never shared; the key is part of every stored identity and unique constraint; no unscoped reads.

### F. Naming and conventions — WARNING (NIT for pure style)
- File and identifier conventions the constitution states; language of identifiers, comments, test names and logs (the constitution's code-language rule); named exports or module surface rules.

### G. Over-engineering — WARNING
- A service or abstraction whose only job is orchestration the caller could do (a "finder" that loads by id or throws NotFound); abstractions with a single implementation and no port role; indirection not traceable to a requirement or a rule. Propose the simpler shape.

### H. Scope — WARNING
- Files changed outside the module's Layout and boundary declared in `design.md` without a reason in the PR body → WARNING naming each file.

### I. Design document hygiene (when the PR edits design.md) — WARNING, NIT if minor
- Sentences that restate a constitution rule instead of a module-specific decision; a file inventory or test list in the design; errors whose names do not match the Spec's Rejections; any narration of history ("changed after…", "not in this change").

### J. ADR discipline (when the PR adds or edits ADRs) — WARNING
- An ADR that fails any of the four tests of `templates/adr.template.md` (already decided by a rule, the spec or an earlier ADR; module-local; cheap to reverse; not genuinely open) → WARNING with `required_action: fold into design.md as a one-line note under <section>`. An ADR whose Context only cites rule IDs it applies is the typical case.
- The opposite gap: a package or context boundary, an aggregate boundary, a contract other modules depend on, a persisted format or a repository-wide library chosen in the design or the code with no ADR → WARNING.
- More than two ADRs in one PR without a justification in the PR description → WARNING.

## Output

```yaml
gate: design-architecture
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements:                  # optional: IDs whose realization you judged
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    requirement: <MODULE>-NNN
    location: <path>:<line>
    description: >
      Which rule (ID) or design element is violated, and what is there now.
    required_action: The concrete change that closes the finding.
evidence:
  - <every file you inspected>
```

`NEEDS_HUMAN` when the Design and the constitution genuinely conflict and you cannot rank them.
