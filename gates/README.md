# Review Gates

One file per gate. Each is a self-contained checklist the `reviewer` agent follows to emit **one gate-result YAML block** (schema below and in `templates/gate-result.template.yaml`). `/sdd` launches one reviewer per gate, in parallel, each with fresh context.

| Gate | File | When | Who |
| --- | --- | --- | --- |
| `completeness` | `completeness.md` | after the plan phase, before Approval Gate 1, on `spec.md` (cycle `plan`) | reviewer |
| `mechanical` | — (`sdd review-check`) | every code review cycle, before the reviewers | bash, no tokens |
| `behaviour` | `behaviour.md` | code PR: the code does what the Spec says and the tests prove it | reviewer |
| `structure` | `structure.md` | code PR: built as design, constitution and blueprint say, and simply | reviewer |
| `risk` | `risk.md` | code PR: security and regression | reviewer |
| `structure` (documents) | `docs.md` | documentation-only PR: coherence and clarity; `behaviour` and `risk` are skipped | reviewer |

## Common rules (apply to every gate; not repeated inside the files)

- **Authority.** `docs/constitution.md` is binding; its `## Rules` are the checks. `docs/blueprint.md` is the convention reference: diverging from it is at most a WARNING. Where a gate item says "when the constitution has the rule", apply it only when such a rule exists, as written; never invent one. Hierarchy: Constitution → Spec → Design → Task → code.
- **Input.** The review pack (`sdd review-pack build <issue> <cycle>`) is the primary input: constitution, blueprint, issue with triage and Task, affected spec and design, the `mechanical` result, touched files, test stats and the diff; in cycles ≥ 1 also the previous cycle's findings, implement's disputes and the delta since the previous review. Open repository files only for what the pack lacks. For `completeness` the input is the spec.
- **Mechanical first.** What `sdd review-check` already reported (added `skip`/`only` markers, `TODO`/`FIXME`, files outside the design's Locations, requirement IDs no test cites, missing blueprint exemplars) is not repeated; use it as a lead.
- **Read-only.** Never modify files. Allowed commands: `git diff*`, `git log*`, `git show*`, `git status*`, `gh pr view*`, `gh pr diff*`, `gh issue view*`, `sdd issue show*`, and reading files. No installs, scanners or network calls.
- **Adversarial.** The producing agent was optimized to finish; you are optimized to find what it missed, added or quietly changed. Cite `path:line`, quote the offending text, and describe the concrete problem, never the abstract category.
- **Severity.** `BLOCKER` fails the gate and must point at a constitution rule, a spec requirement, a design element, or something objectively wrong. `WARNING` is reported and acknowledged by the human at Approval Gate 2. `NIT` is informational. Style the formatter owns is never a finding.
- **Status.** `FAIL` iff at least one BLOCKER. `NEEDS_HUMAN` when the verdict hinges on a decision or fact only a human has (say which), or a disputed BLOCKER is upheld. `BLOCKED` when the gate cannot run (missing PR, spec or design; red build). `PASS` otherwise, with `findings: []` when clean.

## Cycles ≥ 1: incremental review

A rework cycle does not review the PR from scratch; it closes the previous cycle and judges what changed since.

1. **Previous BLOCKERs.** For each BLOCKER of the previous cycle of your gate: resolved → one NIT with `carried: fixed`; still there → the same BLOCKER with `carried: not-fixed`.
2. **Disputes.** For each finding implement disputed (pack section "Disputes") in your gate — and, for the `mechanical` gate, in your area: `behaviour` rules on test markers, deleted tests and requirement citations; `structure` on work markers, Locations, language and blueprint exemplars — rule on the evidence, as a finding with the disputed finding's exact `location`: `disputed: withdrawn` (drop the finding) or `disputed: upheld` (keep it as BLOCKER; the gate's status becomes `NEEDS_HUMAN` for that finding and it is never sent to rework again). A finding cannot be disputed twice. `sdd review-check` reads these rulings: a withdrawn mechanical finding is not reported again, an upheld one turns the mechanical status into `NEEDS_HUMAN`.
3. **The delta.** Judge only the changes since `reviewed_since` (the pack's "Delta" section) with the full checklist. A new BLOCKER must be located in the delta; a problem you notice late in code the previous cycle already reviewed is at most a WARNING (`carried: new`), so review converges.
4. A gate that `PASS`ed in the previous cycle and whose delta is empty is carried over by `/sdd` without a reviewer run.

## Output

Exactly one ```yaml block per gate, nothing after it:

```yaml
gate: <completeness | behaviour | structure | risk>
issue: <issue number>
pr: <pr number, or null>
commit: <head sha reviewed>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <0, 1, 2… ; plan for completeness>
reviewed_since: <sha>          # cycle ≥ 1 only
requirements:                  # REQUIRED for completeness and behaviour: every ID in the affected Spec(s)
  <MODULE>-NNN: PASS | FAIL
findings:
  - severity: BLOCKER | WARNING | NIT
    requirement: <MODULE>-NNN  # omit when not bound to one requirement
    location: <path>:<line>
    description: >
      What is wrong, quoting the text or code and the rule, requirement or design element it breaks.
    required_action: The concrete change that closes the finding.
    carried: fixed | not-fixed | new   # cycle ≥ 1 only
    disputed: upheld | withdrawn       # only for a disputed finding
evidence:
  - <every file you inspected>
```
