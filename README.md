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

Stable (verified):

```bash
claude plugin marketplace add GoKaju/sdd-factory
claude plugin install sdd-factory@sdd-factory
```

and, so every collaborator of a project gets it, in the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": { "sdd-factory": { "source": { "source": "github", "repo": "GoKaju/sdd-factory" } } },
  "enabledPlugins": { "sdd-factory@sdd-factory": true }
}
```

Creating the `Change` and `Constitution` Issue Types needs the `admin:org` scope on `gh`: `gh auth refresh -h github.com -s admin:org` once.

## Flow

```
/sdd-init                 once per repo: constitution, CLAUDE.md, AGENTS.md, labels, Issue Types, issue forms

issue opened (typed)
/sdd-triage <n>     →  comment <!-- sdd:triage -->        human sets  sdd:ready          (Gate 0)
/sdd-spec <n>       →  branch + Draft PR + spec.md        human sets  sdd:spec-approved  (Gate 1)   Feature, Change
/sdd-design <n>     →  design.md                          human sets  sdd:design-approved(Gate 2)   Feature, Change
/sdd-task <n>       →  comment <!-- sdd:task -->          human sets  sdd:task-approved  (Gate 3)
/sdd-implement <n>  →  code + tests, checklist ticked, CI green
/sdd-review <n>     →  review pack → 6 gates (3 paired reviewers) → PR comments → PASS: PR ready   human approves + merges (Gate 4)
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
| `.sdd/config.json` | orchestrator policy: delegated approvals, review mode and budget, intelligence **floors** per phase and reviewer in vendor-neutral tiers `light` · `standard` · `strong` · `frontier`; in `mode: auto` the orchestrator raises a phase above its floor on rework, on the last permitted review cycle or after a recent failure of that phase, never below, and records tier and reason in the ledger; the worker maps tiers to models |

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
skills/           sdd-init, sdd-triage, sdd-spec, sdd-design, sdd-task, sdd-implement, sdd-review, sdd-status, pr-review, create-release
agents/           completeness-checker, ci-runner, committer; paired reviewers spec-test, design-quality, security-regression (default); single-gate spec, design, test, security, regression, quality (Review mode: single)
hooks/            PreToolUse: protect docs/constitution.md and approved spec/design; deny push to main, force-push, history rewrites
scripts/          sdd-state, sdd-type, sdd-org-types, sdd-comment, sdd-gate-result, sdd-pr, sdd-flag, sdd-field, sdd-review-pack, sdd-config  (bash over gh)
templates/        constitution, issue forms, spec, design, task, triage, gate-result
evals/            plugin eval cases (early access)
```

## Guarantees enforced by hooks

- `docs/constitution.md` changes only during a Constitution-type issue.
- Approved `spec.md` / `design.md` cannot be edited while their issue is in implementation or review.
- No `git push` to `main`, no force-push, no rebase / amend / reset --hard.

## Worker (Phase 2)

`worker/` is a zero-dependency Node 24 service (besides the Agent SDK) that polls GitHub and runs the phases headless, one git worktree per issue, so several issues can advance without touching each other.

```bash
cp worker/config.example.json ~/.sdd/worker/config.json   # repos, plugin dir, interval (15 s), maxParallel, models (tier → model for this machine)
cd worker && pnpm install
pnpm dry-run      # one tick, prints what it would run
pnpm once         # one tick, runs it
pnpm stats        # cost, minutes and turns per issue and per phase (from ~/.sdd/worker/jobs.sqlite)
pnpm start        # loop in the foreground
# as a service (macOS):
cp worker/launchd/com.gokaju.sdd-worker.plist ~/Library/LaunchAgents/ && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.gokaju.sdd-worker.plist
# logs: ~/.sdd/worker/worker.log · stop: launchctl bootout gui/$(id -u)/com.gokaju.sdd-worker
```

Status, read-only, on this machine only: `http://127.0.0.1:4777/` (page) and `/status` (JSON: running phases with time budget, issues waiting for a human decision, open issues, pause state, today's cost). `worker/swiftbar/sdd-worker.10s.sh` puts the same in the macOS menu bar via SwiftBar or xbar. The JSON is what a control plane will read from each worker later.

What it reacts to (see `src/rules.ts`): a new issue → triage; an author comment or an edit of the issue title/body while in `triage` → triage again; `ready` → task for Bug/Task/Constitution (Feature/Change wait for a human unless `autoSpec`); `spec-approved` → design; `design-approved` → task, or straight to review when the Task is already complete and newer than the last docs change on the branch (document-only amendment; a Task written for an earlier spec/design is stale and gets rewritten); `task-approved` and `rework` → implement then review; `in-review` → review; `implementing` idle for 45 min → resume. It never sets `ready` or `*-approved`.

Delegated approvals come from `.sdd/config.json` (`approvals.auto`) and are verified, not blind: Spec only when its Open questions section has no unchecked item, Design only when nothing is marked as pending human confirmation, Task only when the Task comment has steps, and in all three cases only when the producing phase reported no BLOCKER, FAIL or NEEDS_HUMAN; otherwise the worker comments once why it is holding and waits for a human.

After every phase the worker rewrites one marked **SDD summary** comment on the issue (minutes and USD per phase, total) and one marked one-line comment on the PR pointing to it, in the constitution's language. Mechanical; no agent involved.

Jobs run in the background: the tick never waits for a phase, so approvals, triage and other issues keep moving while a long phase runs; `maxParallel` bounds the heavy jobs (triage is outside the budget). The config file is re-read after every tick, so interval, parallelism and models change without a restart.

While the orchestrator owns an issue it is assigned to the account `gh` runs as; when the next move is a human's (triage answers, a non-delegated gate, Gate 4) the worker removes itself.

Guarantees: the issue carries `sdd:working` while a phase runs (the state label changes only when the phase ends); one job per issue at a time; a failed job is not retried until the issue changes (new comment, label, edit); a quota error pauses polling (30 min; an org spend limit pauses 6 h, since it does not reset on its own); a phase over its time budget is aborted; every run logs to `~/.sdd/worker/logs/` and records itself in `~/.sdd/worker/jobs.sqlite`, with one `phases` row per executed phase (duration, cost in USD, turns, outcome) that `pnpm stats` aggregates; when a job fails the worker leaves the issue state untouched and comments the reason on the issue.

## Roadmap

- **Phase 3**: control plane scheduling many issues across many workers (the worker is already split into decide/run around a `Job`).
