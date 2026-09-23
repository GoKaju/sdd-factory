# Gate · behaviour

**Question:** does the code do exactly what the approved Spec says, and do the tests prove it? Missing behavior, unauthorized behavior, drift and tests that pass without proving anything all fail this gate. Assume the code was written to finish and the tests to pass. Drift is never resolved by editing the Spec.

## Procedure

1. Read the Spec as approved on the base branch AND as it appears in the PR; diff them. Read the Design, the Task comment (`<!-- sdd:task -->`), the constitution's test rules and the blueprint's test rows (and their exemplars, when named).
2. Build the requirement table: every `<MODULE>-NNN` in the affected Spec(s). For each, locate (a) the code that implements it and (b) the test that proves it. Start from the `mechanical` result's list of IDs no test cites, then search by behavior.
3. Walk the diff hunk by hunk and attribute every behavioral change to a requirement ID. Anything unattributable is unauthorized behavior.
4. From the diff, list every test file added, modified and **deleted**; recover deleted bodies with `git show origin/<base>:<path>` and classify every removed or weakened test as JUSTIFIED or SUSPICIOUS.

## Checklist

### 1. Missing behavior — BLOCKER
- A requirement with no implementing code; partial implementation (the `WHEN` branch exists, the `IF … THEN` rejection does not; a listed state unhandled).
- A scenario of the Spec the code cannot produce (edge-case scenarios included).
- A business-rule parameter (limit, percentage, ordering, uniqueness scope) hardcoded differently from the Spec.
- A rejection of the Spec's table with no corresponding refusal in code, or with a different user message.

### 2. Unauthorized behavior — BLOCKER when observable, WARNING when internal
- Code paths, entry points, events, fields, states or error types no requirement calls for; "while I was here" changes; features the Issue mentioned but the Spec did not adopt.
- Silent widening: accepting inputs the Spec rejects, defaulting a value the Spec requires explicitly.
- Behavior present in code and tests, plausibly desirable, absent from Spec and Design (a validation, a limit, an ordering): WARNING, it needs a requirement ID or removal.

### 3. Spec drift — BLOCKER
- `spec.md` modified in the PR so a requirement is weakened, removed, renumbered or reworded to match the code (compare `git log -p -- <spec>` with the order of the code commits). The only legitimate Spec edits are the ones approved at Approval Gate 1 for this Issue.
- The Design omits an element a requirement needs, or the code diverges from it in a way that changes how a requirement is realized. `required_action` is always "change the code" or "revise the plan through the issue", never "update the document".

### 4. Tests prove the Spec — BLOCKER
- Every requirement ID has at least one test that drives its behavior and asserts its observable outcome. Example: Spec `OT-003: IF the policy defines no percentage, THEN THE SYSTEM SHALL reject the calculation.` Tests found: "calculates overtime", "applies the percentage". Result: FAIL, the rejection is not tested.
- Every scenario of the Spec (happy, failure and edge cases) and every rejection, asserting the **exact** refusal, not a generic failure.

### 5. What each layer must cover — BLOCKER when the constitution has the rule, WARNING otherwise
- Exact error or rejection types asserted; business logic tested without infrastructure (no driver, SDK, framework or network client in a business-rule test); use cases tested through the official fakes with state or result assertions; the isolation boundary proven once per storage adapter; round-trip fidelity for every persistence adapter.

### 6. Test-double policy — apply the constitution's rule
- Replacing a whole module (`vi.mock`, `jest.mock`, `unittest.mock.patch` of a module, monkeypatching an import): BLOCKER when the constitution bans it, WARNING otherwise. Mocking a third-party library or a domain object instead of wrapping it behind a port with a fake: BLOCKER when the constitution requires ports and fakes.
- Interaction-only assertions as the primary check: WARNING (exception: asserting a side effect did **not** happen on an error path). An ad-hoc stub where an official fake exists, or a mock at a real boundary without a one-line justification: WARNING.

### 7. Anti-bypass — BLOCKER unless justified
Justification means "the Spec changed" (cite the ID) or "the production code was deleted in the same change". "CI was red" never is. The `mechanical` result already flags added `skip`/`only` markers; judge the rest:
- A test file deleted while its production source was not; a case removed without its behavior moving into another verifiable test.
- Weakened assertions: exact type → generic; assertion removed; state → interaction; fake → mock; loosened matcher without explanation; assertion-free tests. Coverage thresholds lowered or files added to exclusions.
- For each removed or weakened test, the finding's `description` carries the test name, `Verdict: JUSTIFIED | SUSPICIOUS (bypass)` and the reason. SUSPICIOUS is always BLOCKER.

### 8. Test structure — NIT (WARNING when it diverges from the blueprint's row for that kind of test, or from its exemplar when it names one)
- One group per unit under test; case names start with a verb, no implementation detail; shared fixtures through builders; no real database, network or filesystem in unit tests unless the constitution allows it.

## Requirement status

`PASS`: code implements it fully AND at least one test asserts its observable outcome. `FAIL`: anything else, with at least one finding referencing it. `requirements` is REQUIRED for this gate.

`NEEDS_HUMAN` when a requirement is too ambiguous to decide compliance, or a test removal cannot be classified without product knowledge.
