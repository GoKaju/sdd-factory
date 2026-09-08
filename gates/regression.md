# Gate · regression

**Question:** could this change break existing behavior? The implementation looked at the module it changed; you look at everything that depends on it.

## Procedure

1. Read the affected Spec and Design.
2. List every changed package or module. Find its dependents: grep the changed exports and package names across the repository (manifests, imports, configuration).
3. Find related Specs: other `docs/*/*/spec.md` that mention the same concepts, events or entry points. They define behavior this PR must not alter.
4. Compare every changed public surface against its base-branch version (`git show origin/<base>:<path>`).

## Checklist

### 1. Dependents and related Specs — BLOCKER when a related Spec's behavior changes
- Every dependent of a changed shared module is untouched-and-still-compatible or updated in the same PR. Shared libraries are reviewed for every consumer, not only the one that motivated the change.
- A behavior described in another module's Spec that the diff alters is BLOCKER: that Spec was not approved for change in this Issue.

### 2. Existing tests changed — WARNING; BLOCKER when the Spec did not change
- Any modification to a pre-existing test's assertions, fixtures or setup is a suspected behavior change; if the corresponding requirement did not change, BLOCKER (test-strategy rules on bypass; here rule on behavior). Snapshot or fixture updates without an explanation in the PR body.

### 3. Public surface — BLOCKER unless every consumer is updated in the PR
- Exports removed, renamed or re-typed; command, result or port signatures changed (every adapter and fake updated?); API routes or procedures renamed, removed, re-shaped or with a changed authorization level; shared contract schemas changed on one side only; stricter validation rejecting previously accepted payloads.

### 4. Events and messages — BLOCKER
- Renamed event, removed or re-typed field, changed semantics: every consumer located and still correct. A new or changed consumer that performs a non-idempotent side effect under at-least-once delivery. Messages in flight at deploy time still deserialize with the new code.

### 5. Schema changes and migrations — BLOCKER
- A change to a persisted shape has a migration in the same PR; destructive migrations (drop, rename, narrowing type, new NOT NULL without default or backfill) without an expand-and-contract plan; new tables and constraints missing the isolation key when the constitution requires it; migrations that follow the project's migrator and are never run by a script in the PR.
- Reconstruction of stored data given a new required value: rows persisted before the change must still load (backfill, or a tolerant mapper with a decision in the Design).

### 6. Backwards compatibility — WARNING; BLOCKER for data loss or silent behavior change
- Configuration or environment variables added, renamed or re-defaulted, and the wiring of every runtime updated; major bumps of shared dependencies checked for breaking changes; removed flags, changed defaults, sort orders or page sizes visible to users; a changed view type reaching every screen that renders it.

### 7. Regression scenarios named in the Task — WARNING
- The Task comment may list scenarios to protect; verify a test covers each (BLOCKER in test-strategy, WARNING here).

## Output

```yaml
gate: regression
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements:                  # optional: related-Spec IDs you verified
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    location: <path>:<line>
    description: >
      What existing behavior or consumer breaks, and how you know (the dependent file, the old version).
    required_action: The concrete change (update consumer X, add migration, keep old field) that closes it.
evidence:
  - <changed files, their dependents, related Specs you inspected>
```

`NEEDS_HUMAN` when compatibility depends on data or deployments you cannot inspect.
