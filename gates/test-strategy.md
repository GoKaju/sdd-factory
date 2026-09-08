# Gate · test-strategy

**Question:** do the tests prove the Spec is implemented? A green suite that does not assert the Spec's behavior fails this gate. Assume tests were written to pass, not to prove.

## Procedure

1. Read the Spec, the Design and the constitution's test rules and test exemplars (if it names any; hold new tests to that standard).
2. From the diff, list every test file added, modified and **deleted**; for each, the added cases, removed cases and modified assertions. Recover deleted bodies with `git show origin/<base>:<path>`.
3. Build the requirement table. For each `<MODULE>-NNN`, locate the test(s) proving it: grep the ID literally, then search by behavior. A requirement is proven only when a test drives the behavior and asserts its observable outcome.
4. Review new or modified tests against the checklist; classify every removed or weakened test as JUSTIFIED or SUSPICIOUS.

## Checklist

### 1. Coverage of the Spec — BLOCKER
- Every requirement ID has at least one test asserting its observable outcome. Example: Spec `OT-003: IF the policy defines no percentage, THEN THE SYSTEM SHALL reject the calculation.` Tests found: "calculates overtime", "applies the percentage". Result: FAIL, the rejection is not tested.
- Happy paths, failure paths, every edge case listed in the Spec, every business rule, every acceptance criterion, every rejection (asserting the **exact** refusal, not a generic failure), and the regression scenarios named in the Task.

### 2. What each layer must cover — BLOCKER when the constitution has the rule, WARNING otherwise
Apply the constitution's test rules as written. Typical rules and how to check them:
- Exact error or rejection types asserted (`toThrow(SpecificError)`, not `toThrow()`).
- Business logic tested without infrastructure: a test of business rules that imports a driver, SDK, framework or network client.
- Use cases or services tested through the project's official fakes with state or result assertions, at least one test without mocks each.
- Isolation boundary (tenant, organization, workspace) proven once per storage adapter: what A saved is not visible to B.
- Round-trip and mapping fidelity for every persistence adapter.

### 3. Test-double policy — apply the constitution's hierarchy; defaults below when it has one
- Replacing a whole module (`vi.mock`, `jest.mock`, `unittest.mock.patch` of a module, monkeypatching an import) is BLOCKER when the constitution bans it, WARNING otherwise.
- Mocking a third-party library or a domain object instead of wrapping it behind a port with a fake: BLOCKER when the constitution requires ports/fakes.
- Interaction-only assertions (`toHaveBeenCalledWith` as the primary check) are WARNING; assert state or result. Narrow exception: asserting a side effect did **not** happen on an error path.
- An ad-hoc stub where an official fake exists: WARNING. A mock at a real external boundary without a one-line justification: WARNING.

### 4. Anti-bypass rule — BLOCKER unless justified
Justification means "the Spec changed" (cite the ID) or "the production code was deleted in the same change". "CI was red" is never a justification.
- A test file deleted while its production source was not; a case removed without its behavior merged into another verifiable test.
- `skip`, `only`, `todo`, `xit`, `@pytest.mark.skip` added without a comment and a tracking reference. A forgotten `only` is always BLOCKER.
- Weakened assertions: exact type → generic; assertion removed; state assertion → interaction assertion; fake → mock; loosened matcher (`toEqual` → `toBeDefined`, exact count → `> 0`) without explanation. Assertion-free tests.
- Coverage thresholds lowered, files added to coverage exclusions.

### 5. Structure and naming — NIT
- One describe/group per unit under test; case names start with a verb, natural language, no implementation detail. Shared fixtures through builders; no repeated large literals. No real database, network or filesystem in unit tests unless the constitution allows it. No debug output.

## Removed or weakened tests

For each: the finding `description` includes the test name, `Verdict: JUSTIFIED | SUSPICIOUS (bypass)`, and the reason (production code deleted? Spec changed and which ID? or: the test would have failed against the new code). SUSPICIOUS is always BLOCKER.

## Requirement status

`PASS`: at least one test drives the requirement's behavior and asserts its observable outcome. `FAIL`: anything else, with at least one finding referencing it.

## Output

```yaml
gate: test-strategy
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements:                  # REQUIRED: every ID in the affected Spec(s)
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    requirement: <MODULE>-NNN
    location: <test path>:<line>
    description: >
      Rule violated, what is there now, and (for removed tests) the verdict and reason.
    required_action: The concrete test to add or change.
evidence:
  - <every test and source file you inspected>
```

`NEEDS_HUMAN` if a test removal cannot be classified without product knowledge.
