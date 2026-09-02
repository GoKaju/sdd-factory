# Evals

`claude plugin eval` is in early access and not enabled here yet. Until it is, run these three cases by hand on the pilot repository (milestone M5) and record the outcome in the vault.

| Case | Prompt | Pass when |
| --- | --- | --- |
| `init-creates-labels` | `/sdd-init` on a fresh org repo | 12 `sdd:*` labels exist, `docs/constitution.md` written once, `CLAUDE.md` = `@docs/constitution.md`, `AGENTS.md` points to it, 5 Issue Types present or listed as MANUAL |
| `spec-requires-ids` | `/sdd-spec <n>` on a Feature issue in `sdd:ready` | every requirement in `spec.md` has `<MODULE>-NNN`; `completeness-checker` returns PASS; state becomes `sdd:spec`; PR is draft |
| `review-detects-deleted-test` | delete the negative-path test of one requirement, then `/sdd-review <n>` | `test-reviewer` FAIL with a BLOCKER naming the requirement; state `sdd:rework`; the rework restores an equivalent test; second cycle PASS |

Each case lives in `evals/<case>/prompt.md`; graders will be added when the command is available.
