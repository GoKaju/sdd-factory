# Gate · code-quality

**Question:** is the implementation maintainable and appropriately simple? A BLOCKER here points at an explicit constitution rule or at code that is objectively wrong; preference is a NIT. Architecture belongs to design-architecture, test policy to test-strategy: reference them, do not duplicate them.

## Procedure

1. Read the constitution's code rules and the Spec (its vocabulary is the naming reference).
2. Read the diff, then each changed file in full and the sibling files it duplicates or could reuse.
3. Walk the checklist; cite `path:line` and give the simpler alternative.

## Checklist

### 1. Unnecessary complexity — WARNING (NIT when arguable)
- Interfaces with a single implementation that are not ports the constitution requires; helpers, base classes or utilities used once; indirection that adds no decision.
- Parameters or configuration for values that never vary; flags with one state; premature optimization (caches, batching, memoization) without a requirement or a measurement.
- Clever code where a plain conditional would do; nesting a guard clause would flatten.

### 2. Duplication — WARNING
- Same logic twice in the diff, or copied from an existing file when a shared function exists in the project's shared packages; repeated large literals in tests where a builder exists or should.

### 3. Naming — WARNING (NIT for taste)
- Names that mislead or diverge from the Spec's vocabulary (Spec says `Payslip`, code says `PayDoc`); abbreviations, single letters outside tiny lambdas, `data`/`info`/`manager`/`helper`/`util`; booleans not phrased as predicates; functions named for what they call rather than what they achieve; file names against the constitution's convention.

### 4. Dead code — BLOCKER for commented-out code and unreachable branches; WARNING otherwise
- Commented-out code, unreachable branches, unused exports, parameters and imports; leftover scaffolding, debug statements and console output in production code.

### 5. Error handling — BLOCKER when errors are swallowed or masked; WARNING otherwise
- `catch` blocks that swallow, log-and-continue, or rethrow adding nothing; catch-alls that turn a specific error into a generic failure before the translation point; generic errors where the constitution requires named ones; messages mixing business meaning with infrastructure detail; promises or futures whose rejection is lost.

### 6. Comments — apply the constitution's comment rule; BLOCKER for TODO/FIXME
- Comments that describe what a line does, section separators, docstrings restating a signature; `TODO`, `FIXME`, `HACK`, ticket references (work is tracked in the Issue). If the constitution limits comments to one line of *why*, anything longer is WARNING.

### 7. Type and lint strictness — BLOCKER when the constitution states the rule
- Type escapes (`any`, `# type: ignore`, `@ts-ignore`, `interface{}` casts), lint-disable directives, non-null assertions and casts used to silence the compiler rather than to narrow after a real check.

### 8. Observability — WARNING
- Entry points log structured events with a correlation id; errors logged once at the translation point; no sensitive data in logs (the security gate owns the risk; here flag the noise); new long-running or scheduled work can be seen to have run.

## Severity discipline

BLOCKER: violates an explicit constitution rule or is objectively wrong. WARNING: hurts maintainability in a way a reviewer would ask to change. NIT: preference. Never argue formatting.

## Output

```yaml
gate: code-quality
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements: {}               # optional for this gate
findings:
  - severity: BLOCKER | WARNING | NIT
    location: <path>:<line>
    description: >
      What is there now and why it hurts; cite the constitution rule for a BLOCKER.
    required_action: The simpler or cleaner alternative, concretely.
evidence:
  - <every file you inspected>
```

`NEEDS_HUMAN` is rarely appropriate here; use it only when a rule's applicability is genuinely unclear.
