# sdd-factory

Claude Code plugin that turns a GitHub repository into a **Spec-Driven Development factory**: typed issues, triage, spec → design → task with human approval gates, autonomous implementation, six adversarial review gates with bounded rework, and a single rule file per project (`docs/constitution.md`).

The framework this implements: `SDD Autonomous Software Factory` (Obsidian vault `SDD Factory`).

## Requirements

- Claude Code ≥ 2.1 with plugins, `gh` authenticated, `jq`.
- The repository belongs to a **GitHub organization** (native Issue Types are organization-level).

## Install

Development, per session:

```bash
cd <your-repo>
claude --plugin-dir /path/to/sdd-factory
```

Stable, per project (`.claude/settings.json`):

```json
{
  "extraKnownMarketplaces": ["https://github.com/GoKaju/sdd-factory.git"],
  "enabledPlugins": ["sdd-factory@sdd-factory"]
}
```

## Flow

```
/sdd-init                 once per repo: constitution, CLAUDE.md, AGENTS.md, labels, Issue Types, issue forms

issue opened (typed)
/sdd-triage <n>     →  comment <!-- sdd:triage -->        human sets  sdd:ready          (Gate 0)
/sdd-spec <n>       →  branch + Draft PR + spec.md        human sets  sdd:spec-approved  (Gate 1)   Feature, Change
/sdd-design <n>     →  design.md                          human sets  sdd:design-approved(Gate 2)   Feature, Change
/sdd-task <n>       →  comment <!-- sdd:task -->          human sets  sdd:task-approved  (Gate 3)
/sdd-implement <n>  →  code + tests, checklist ticked, CI green
/sdd-review <n>     →  6 gates → PR comments → PASS: PR ready       human approves + merges (Gate 4)
                                            → FAIL: rework, at most max_rework_cycles
/sdd-status [n]        where is everything, who acts next
```

Issue type decides the path: **Feature** and **Change** take every step; **Bug**, **Task** and **Constitution** go from `ready` straight to `/sdd-task`. A Bug or Task whose root cause is in the spec or design is stopped and reclassified as Change.

## Where things live

| Place | Holds |
| --- | --- |
| Issue | intent, triage comment, task comment with checklist, `sdd:<state>` label |
| Draft PR | `spec.md`, `design.md`, code, gate results as comments |
| `docs/` on `main` | approved, merged truth |
| `docs/constitution.md` | the only rule file; `CLAUDE.md` and `AGENTS.md` just point to it |

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
skills/           sdd-init, sdd-triage, sdd-spec, sdd-design, sdd-task, sdd-implement, sdd-review, sdd-status, pr-review, create-release
agents/           completeness-checker, spec-reviewer, design-reviewer, test-reviewer, security-reviewer, regression-reviewer, quality-reviewer, ci-runner, committer
hooks/            PreToolUse: protect docs/constitution.md and approved spec/design; deny push to main, force-push, history rewrites
scripts/          sdd-state, sdd-type, sdd-org-types, sdd-comment, sdd-gate-result, sdd-pr  (bash over gh)
templates/        constitution, issue forms, spec, design, task, triage, gate-result
evals/            plugin eval cases (early access)
```

## Guarantees enforced by hooks

- `docs/constitution.md` changes only during a Constitution-type issue.
- Approved `spec.md` / `design.md` cannot be edited while their issue is in implementation or review.
- No `git push` to `main`, no force-push, no rebase / amend / reset --hard.

## Roadmap

- **Phase 2**: local worker that polls GitHub and runs the phases headless (Agent SDK), one worktree per issue.
- **Phase 3**: control plane scheduling many issues across many workers.
