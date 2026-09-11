# sdd-factory

A **Spec-Driven Development** factory for Claude Code, packaged as a plugin: typed GitHub issues, triage, spec → design → task with human approval gates, implementation, six adversarial Review Gates with bounded rework, and a single rule file per project (`docs/constitution.md`).

One command drives one issue end to end: `/sdd <issue-number>`. It launches a fresh subagent per phase with the model you configured, grants the approval gates you delegated after verifying the artifact, waits for the ones you kept **without spending tokens** (`sdd await`: bash polling of GitHub), runs the review, applies rework, and leaves a learning document per issue. Re-run it any time: it resumes from the issue's state label.

## Requirements

- Claude Code, `gh` authenticated, `jq`, `python3`, `git`, bash.
- The repository belongs to a **GitHub organization** (native Issue Types are organization-level). Creating the `Change` and `Constitution` types needs `gh auth refresh -h github.com -s admin:org` once.

## Install

```bash
claude plugin marketplace add GoKaju/sdd-factory
claude plugin install sdd-factory@sdd-factory
```

and for every collaborator, in the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": { "sdd-factory": { "source": { "source": "github", "repo": "GoKaju/sdd-factory" } } },
  "enabledPlugins": { "sdd-factory@sdd-factory": true }
}
```

Development: `claude --plugin-dir /path/to/sdd-factory` inside your repository.

Then, once per repository, `/sdd-init`: constitution, `.sdd/config.yml` (assisted), labels, Issue Types, issue forms. `/sdd-config` changes the config later.

## Flow

![The SDD flow: six phases, five human gates, one artifact per step on GitHub](docs/sdd-flow.svg)

Every issue moves left to right. `/sdd N` reads the issue's `sdd:<state>` label, asks `sdd next N` what the state machine requires, and acts:

| `sdd next` says | `/sdd` does |
| --- | --- |
| `run <phase>` | launches the phase subagent (`triage`, `spec`, `design`, `task`, `implement`; `review` is coordinated by `/sdd` itself: `sdd ci`, review pack, `reviewer` subagent, aggregate, rework) and sets the next state from its report |
| `approve <gate>` | the gate is delegated in `.sdd/config.yml`: verifies the artifact mechanically (and with the `reviewer` when `(judged)`), grants it or withholds it with a comment |
| `human` | the gate is a person's: `sdd await N` polls GitHub in bash until a label changes, someone comments `/approve` (write permission), `/rework`, or anything else; a human comment relaunches the current phase with it as feedback |

Approvals stay on GitHub: a label (`sdd:ready`, `sdd:spec-approved`, …) or a `/approve` comment on the issue. At Gate 4 the human merges the PR, comments `/approve` (the factory squash-merges), or comments `/rework` with one bullet per change, which becomes Task steps for the implement phase. On a review `FAIL` the issue loops back to implement with the BLOCKER findings, at most `gates.rework_budget` times.

The issue type decides the path: **Feature** and **Change** take every step; **Bug**, **Task** and **Constitution** go from `ready` straight to `task`. A Bug or Task whose root cause is in the spec or design is stopped and reclassified as Change. Source of the diagram: `docs/sdd-flow.html`.

## Where things live

| Place | Holds |
| --- | --- |
| Issue | intent, triage comment, Task comment with checklist, `sdd:<state>` label |
| Draft PR | `spec.md`, `design.md`, ADRs, code, gate results as comments, `.sdd/learning/<N>.md` |
| `docs/` on `main` | approved, merged truth: `docs/<domain>/<module>/{spec,design}.md` (the current state of the module, never its history) and `docs/adrs/NNNN-*.md` (one immutable file per decision; reversals supersede) |
| `docs/constitution.md` | the only **rule** file: Identity, Rules (one line each, stable IDs), Decisions, Verification. `CLAUDE.md` just points to it |
| `.sdd/config.yml` | how the factory **operates**: language, model per phase, delegated gates, warnings policy, rework budget, await limits, check commands (`sdd ci`) |
| `.sdd/learning/<N>.md` | one learning document per issue, for the people improving the project's rules and this plugin: metrics per phase, findings, escalations, frictions with concrete suggestions. `/sdd` never reads them |
| `.sdd/worktrees/issue-<N>/` | git worktree per issue (git-ignored): `/sdd` moves in at start and every phase works there; your checkout stays untouched; two issues can run in two sessions |
| `~/.sdd/<owner>-<repo>/` | scratch outside the repository: hook flags, review packs, run logs with the hooks' agent/model/token records (`sdd log`), await marks |

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
bin/sdd           the one CLI: sdd state|type|org-types|comment|pr|gate-result|review-pack|rework|flag|ci|next|await|worktree|log|config
scripts/          the bash behind each sdd command (gh + jq + git + python3 for JSON/YAML)
skills/           sdd (the orchestrator), sdd-init, sdd-config, sdd-status
agents/           one subagent per phase: triage, spec, design, task, implement, reviewer, learning (model and effort in the frontmatter; model overridden by .sdd/config.yml)
gates/            one checklist per Review Gate (completeness, spec-compliance, test-strategy, design-architecture, code-quality, security, regression, docs) + README with the common rules
hooks/            PreToolUse hooks: protect docs/constitution.md and approved spec/design/ADRs (also inside issue worktrees); deny push to main, force-push, history rewrites
templates/        constitution, config, learning, commits, spec, design, adr, gate-result, comments/{en,es}, issue-forms/{en,es}, examples/constitution.ddd-ts.md
```

## Design choices

- **One entry point, mechanical decisions.** A person starts each issue with `/sdd N`; nothing scans the tracker. `sdd next N` is the state machine of that one issue and `sdd await N` the waiting: both bash, both free. The `/sdd` skill spends tokens only to read a subagent's report, verify an artifact, and decide what a human comment means.
- **One subagent per phase, fresh context.** Each phase reads only what it needs and ends with a YAML report; `/sdd` owns every state transition. The reviewer never shares context with the agent it judges.
- **Rules and operation apart.** The constitution changes through a Constitution issue; the config changes with `/sdd-config`. The gates check the constitution's rules as written and skip what it does not state; nothing in the framework names a folder layout, a language or a package manager.
- **Documents are the current truth.** Spec and design never carry history; decisions are ADRs; deltas live in the PR description; drift is fixed in code, never by editing the document.
- **Humans hold the gates** unless they delegate them explicitly, gate by gate. A Constitution issue is never merged by the factory.

## Control: agent, model, time and tokens per phase

Two hooks the plugin ships (`SubagentStart`, `SubagentStop`, matcher `^sdd-factory:`) record on the host's side which agent type ran for which issue, with which real model, for how long and with how many tokens, into `~/.sdd/<owner>-<repo>/runs/<N>.jsonl`. This is evidence from Claude Code, not the agent's own report. `/sdd` prints it after every phase (`sdd log last N <phase>`) and at the end (`sdd log summary N`); the learning document copies it. Add an optional `pricing:` block to `.sdd/config.yml` (USD per million tokens per model family) and the same tables show the estimated cost.

## Guarantees

Hooks enforce, in the main checkout and in every issue worktree: `docs/constitution.md` changes only during a Constitution-type issue; approved `spec.md`, `design.md` and ADRs cannot be edited while their issue is in implementation or review; no `git push` to `main`, no force-push, no rebase / amend / reset --hard.

## Adding a gate

Write `gates/<name>.md` (question, procedure, checklist with severities, output schema), list it in the constitution's Verification, and name it in the `gates:` input of the reviewer. `sdd gate-result aggregate` treats every posted result the same way.
