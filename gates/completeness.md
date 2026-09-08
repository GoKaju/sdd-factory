# Gate · completeness

**Question:** is this Spec complete and unambiguous enough for an agent to implement it without asking a human? Look for reasons it is not ready.

## Inputs

Issue number; PR number if the Draft PR exists; path `docs/<domain>/<module>/spec.md`. Also read the sibling `design.md` if present and any spec the Spec names as a dependency. `gh issue view <n> --comments` for the Issue and its triage; `gh pr diff <n>` for the new lines; `git show origin/<base>:<path>` for the previously approved version.

## Checklist

### 1. Stable identifiers — BLOCKER
- Every requirement has an ID `<MODULE>-NNN` (uppercase module code, three-digit number). IDs are unique.
- An ID present in the approved version never names a different requirement now (compare with `git show`). Superseded requirements are marked `Removed`, never deleted or renumbered.
- A sentence with SHALL / MUST / NEVER and no ID is an unidentified requirement.

### 2. Ambiguity — BLOCKER
Flag any requirement two competent engineers could implement differently:
- Vague qualifiers: "fast", "appropriate", "properly", "as needed", "etc.", "and/or", "handle gracefully", "user-friendly".
- Undefined domain terms: every noun with business meaning is defined in Domain concepts or in the constitution.
- Missing actor or trigger where one is needed to know when the behavior applies.
- A transformation that does not say what comes in, what goes out and what is rejected.
- EARS (`WHEN … THE SYSTEM SHALL …`) is recommended, not mandatory; never flag a clear sentence for not using it.

### 3. Acceptance criteria — BLOCKER
- The section exists; every requirement has at least one observable, testable criterion (concrete input and expected outcome, not a restatement). Criteria describe behavior, never implementation.

### 4. Edge cases — WARNING; BLOCKER when the edge case changes the happy path
For each requirement: empty or absent input, boundaries (zero, negative, maximum, exactly at the limit), duplicates, repeated invocation, unavailable dependency, invalid state transition. List the missing ones in `required_action`.

### 5. Conflicts — BLOCKER
- Two requirements that cannot both hold; a requirement contradicting a business rule or a dependency Spec.
- Do NOT evaluate the constitution's technical rules against the Spec: they apply to design and code, and raising them here pushes design vocabulary into the Spec.
- A requirement contradicting an existing `design.md` with no note of which one changes. **Exception:** in a Change-type issue the Spec is expected to contradict the current Design; report it as a NIT listing the design sections to amend.

### 6. Business rules and rejections — WARNING
- Every rule a requirement relies on (limits, formulas, ordering, uniqueness) states its parameters.
- Every business reason to refuse a request is one row of `## Rejections`: stable English name, condition, message to the user, requirement ID; the checking order is stated when several apply.

### 7. Open questions and placeholders — BLOCKER
- `## Open questions` is empty or absent. No `TBD`, `TODO`, `???`, `to be defined`, `pending`, `<placeholder>` anywhere (grep for them; a plain word "todo" in Spanish prose is not a placeholder).

### 8. History in the spec — WARNING
- Answered questions, decisions taken while writing, rationale, corrections from earlier cycles or notes for Design anywhere in the document. The spec is the current truth; that history belongs to the Issue and the PR description.

### 9. Scope — WARNING
- Purpose, Scope and Out of scope exist and agree. Anything the Issue asks for and the Spec omits is a WARNING quoting the Issue.

### 10. Behavior, not implementation — BLOCKER
The Spec is written for the person who opened the Issue: WHAT, never HOW. Anywhere in the document, quote the sentence and propose a business-language rewrite for:
- Isolation or tenancy mechanics, identifiers of the isolation boundary.
- Persistence and read-side vocabulary: repository, database, storage, record, view, read model, projection, DTO.
- Messaging mechanics: event, publish, consumer, delivery, idempotent (the observable rule "doing X twice produces one result" is fine).
- Concurrency, locks, transactions, ordering of persistence vs publication.
- Transport and UI: HTTP, API, endpoint, frontend, screen.
- Test vocabulary: test, fake, mock, coverage.
- Code structure: class, aggregate, use case, layer, file or package names; the words "error", "exception".
- "Out of scope" entries that are deferred technical decisions (pagination, storage, API) instead of excluded business capabilities.
Only exception: a requirement that is itself technical because the customer asked for it ("data is exported as CSV").

## Requirement status

`PASS` when the requirement is identified, unambiguous and has an acceptance criterion; `FAIL` otherwise, with at least one finding referencing it.

## Output

```yaml
gate: completeness
issue: <issue number>
pr: <pr number, or null>
commit: <head sha of the PR, or null>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer from your input; 0 if unknown>
requirements:                  # one entry per requirement ID in the Spec
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    requirement: <MODULE>-NNN  # omit when not bound to one requirement
    location: docs/<domain>/<module>/spec.md:<line>
    description: >
      What is missing or ambiguous, quoting the offending text.
    required_action: The concrete addition or rewrite that closes the finding.
evidence:
  - docs/<domain>/<module>/spec.md
```

`BLOCKED` if the Spec path does not exist or is empty. `NEEDS_HUMAN` if the Spec hinges on a product decision only a human can make.
