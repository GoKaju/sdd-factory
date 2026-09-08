# Review Gates

One file per gate. Each file is a self-contained checklist an agent follows to emit **one gate-result YAML block** (schema: `templates/gate-result.template.yaml`). The `reviewer` agent reads them; a host without subagents runs them inline from the `/sdd-review` or `/sdd-spec` skill. Nothing here depends on Claude Code.

| Gate | File | When |
| --- | --- | --- |
| `completeness` | `completeness.md` | before Approval Gate 1, on `spec.md` |
| `spec-compliance` | `spec-compliance.md` | code PR |
| `test-strategy` | `test-strategy.md` | code PR |
| `design-architecture` | `design-architecture.md` | code PR |
| `code-quality` | `code-quality.md` | code PR |
| `security` | `security.md` | code PR |
| `regression` | `regression.md` | code PR |
| `design-architecture` + `code-quality` as document coherence and clarity | `docs.md` | documentation-only PR (the other four are skipped mechanically) |

## Common rules (apply to every gate; not repeated inside the files)

- **Authority.** `docs/constitution.md` is binding; its `## Rules` are the checks. Where a gate item says "if the constitution has a rule about X", apply it only when such a rule exists, as written; where the constitution is silent, the item does not apply. Hierarchy: Constitution → Spec → Design → Task → Code. Code is never evidence that a document is wrong.
- **Input.** The review pack (`sdd review-pack build <issue>` → `~/.sdd/<owner>-<repo>/review-pack-<issue>.md`) is the primary input: constitution, issue with triage and Task, affected spec/design (PR version and diff against the approved one), touched files, test stats, full diff. Open repository files only for what the pack lacks (code around a hunk, a file the diff references). For `completeness` there is no pack: read the spec, the issue and the base-branch version.
- **Read-only.** Never modify files. Allowed commands: `git diff*`, `git log*`, `git show*`, `git status*`, `gh pr view*`, `gh pr diff*`, `gh issue view*`, and reading files. No installs, scanners, network calls.
- **Adversarial.** The producing agent was optimized to finish; you are optimized to find what it missed, added or quietly changed. Cite `path:line` and quote the offending text. Describe the concrete problem, never the abstract category.
- **Severity.** `BLOCKER` fails the gate and must point at a constitution rule, a spec requirement, a design element, or something objectively wrong. `WARNING` is reported and acknowledged by the human at Approval Gate 4. `NIT` is informational. Style the formatter owns is never a finding.
- **Status.** `FAIL` iff at least one BLOCKER. `NEEDS_HUMAN` when the verdict hinges on a decision or fact only a human has (say which). `BLOCKED` when the gate cannot run (missing PR, spec or design; red build). `PASS` otherwise, with `findings: []` when clean.
- **Output.** Exactly one ```yaml block per gate, nothing after it. Every gate's block carries `gate`, `issue`, `pr`, `commit`, `status`, `rework_cycle`, `requirements` (mandatory for `completeness`, `spec-compliance`, `test-strategy`; optional elsewhere), `findings`, `evidence`.
- **Several gates in one run.** One reading, independent verdicts: each gate keeps its own checklist and severity; sharing the reading MUST NOT soften any verdict. The same fact may be a BLOCKER for one gate and a WARNING for another; that is expected.
