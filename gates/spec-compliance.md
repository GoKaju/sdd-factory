# Gate · spec-compliance

**Question:** does the implementation fully comply with the approved Spec, and are Spec, Design and Code still aligned? Drift MUST NOT be resolved by editing the Spec.

## Procedure

1. Read the Spec as approved on the base branch AND as it appears in the PR; diff them. Read the Design and the Task comment (`<!-- sdd:task -->`) to learn which requirement IDs the PR claims to deliver.
2. Build the requirement table: every `<MODULE>-NNN` in the affected Spec(s). For each, locate (a) the code that implements it and (b) the test(s) that prove it. Grep the ID literally first (tests should cite IDs), then search by behavior.
3. Walk the diff hunk by hunk and attribute every behavioral change to a requirement ID. Anything unattributable is unauthorized behavior.
4. Check the Design against the code: every element the Design names exists as described, and the Design still supports every requirement.

## Checklist

### Missing behavior — BLOCKER
- A requirement with no implementing code; partial implementation (the `WHEN` branch exists, the `IF … THEN` rejection does not; a listed state unhandled).
- A business-rule parameter (limit, percentage, ordering, uniqueness scope) hardcoded differently from the Spec.
- An acceptance criterion the code cannot produce; an edge case listed in the Spec with no handling.
- A rejection of the Spec's table with no corresponding refusal in code, or with a different user message.

### Unauthorized behavior — BLOCKER when observable, WARNING when internal
- Code paths, entry points, events, fields, states or error types no requirement calls for; "while I was here" changes; features the Issue mentioned but the Spec did not adopt.
- Silent widening: accepting inputs the Spec rejects, defaulting a value the Spec requires explicitly.

### Spec drift — BLOCKER
- `spec.md` modified in the PR so a requirement is weakened, removed, renumbered or reworded to match the code. Compare `git log -p -- <spec>` with the order of the code commits. The only legitimate Spec edits in an implementation PR are the ones approved at Approval Gate 1 for this Issue.
- `required_action` for drift is always "restore the requirement and change the code", never "update the Spec".

### Design no longer supports the Spec — BLOCKER
- The Design omits an element a requirement needs; the code diverges from the Design in a way that changes how a requirement is realized. Report against `design.md` with the code location in `evidence`; recommend a design revision through the Issue, never editing the Design to pass.

### Undocumented behavior — WARNING
- Behavior present in code and tests, plausibly desirable, absent from Spec and Design (a validation, a limit, an ordering). It needs a requirement ID or removal.

### Tests as evidence — WARNING here (test-strategy owns the BLOCKER)
- A requirement with code but no test proving it: mark it `FAIL` and add a WARNING.

## Requirement status

`PASS`: code implements it fully AND at least one test asserts its observable outcome. `FAIL`: anything else, with at least one finding referencing it.

## Output

```yaml
gate: spec-compliance
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements:                  # REQUIRED: every ID in the affected Spec(s)
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    requirement: <MODULE>-NNN  # omit when not bound to one requirement
    location: <path>:<line>
    description: >
      What is missing, unauthorized or drifted; quote the requirement text.
    required_action: What must change in code, tests or Design for this to close.
evidence:
  - <every file you inspected>
```

`NEEDS_HUMAN` if a requirement is too ambiguous to decide compliance; name it.
