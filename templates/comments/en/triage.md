<!-- sdd:triage -->
<!-- Exactly one triage comment per Issue. Re-running /sdd-triage edits this comment; it never posts a second one.
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
- [ ] <question the author must answer before the Issue can be `sdd:ready`>
- [ ] <…>

<!-- When every box above is checked (or the list is empty), the Issue is ready for Approval Gate 0. -->
