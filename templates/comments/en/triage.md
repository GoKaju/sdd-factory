<!-- sdd:triage -->
<!-- Exactly one triage comment per Issue. Re-running the triage phase edits this comment; it never posts a second one.
     The agent that writes this reads the repository but never modifies it.
     Intake approval = a human sets the tracker state `sdd:ready`. -->

## Triage

**Type:** <Feature | Change | Bug | Task> <!-- "(changed from Bug: the request asks for new behavior)" when retyped -->
**Size:** <S | M | L> — <one clause justifying it>
**Effort:** <Low | Medium | High> suggested in the issue's `Effort` field (pending human acceptance) · or "the organization has no Effort field"
**Path:** <Spec → Design → Task → Implement → Review | Task → Implement → Review>

### Completeness
- Problem: <present | missing>
- Requested outcome: <present | vague: …>
- Acceptance hints: <present | missing>

### Duplicates and overlaps
- <#123 "…" — overlaps on …> or "none found" (searched open and closed issues, and `docs/`)

### Affected specs
| Domain / module | Spec | Requirements touched |
| --- | --- | --- |
| <payroll/overtime> | <exists · new> | <OT-002, OT-003 · none yet> |

### Open questions
<!-- Everything a later phase would otherwise guess. One box per question; each carries a proposed answer the author can
     confirm with one word, and the phase that would guess it. Ticked when answered and recorded under Clarifications. -->
- [ ] <question> — **proposed:** <business default> _(<spec | design | implement>)_
- [ ] <…>

### Clarifications
<!-- Answers the author gave, one line each, in their words when short. Inputs for the spec: each becomes a requirement,
     rejection or acceptance criterion; the completeness gate checks it did. Never removed in later runs. -->
- <question> → <answer>

### Assumptions
<!-- Business defaults taken because one reading is clearly right; written here so the author can object before `sdd:ready`. -->
- <assumption>

<!-- When every box under Open questions is checked (or the list is empty), the Issue is ready for Approval Gate 0. -->
