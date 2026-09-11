---
name: sdd-orchestrate
description: Orchestrate the SDD factory from Orca - read what every open issue needs (sdd next), grant the approval gates the constitution delegates once the artifact is verified, launch each runnable phase as a supervised Orca worker in its own worktree, wait for the results, report. Runs on a schedule (Orca automation) or by hand. Never sets a non-delegated approval.
argument-hint: "[--max-parallel N] [--dry-run]"
disable-model-invocation: true
---

# /sdd-orchestrate

Conventions: `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH). `orca` is the Orca CLI; if `orca` is not on the PATH on macOS use `/Applications/Orca.app/Contents/Resources/bin/orca`. Load Orca's own skill with `orca skills get orchestration --full` the first time you need a command you do not remember: it is the authority on Run, Task, Dispatch, `check`, release and recovery. This skill only says **what** to orchestrate; Orca says **how**.

You are the **coordinator** of one tick of the factory. The decision of which phase an issue needs is mechanical and already taken (`sdd next`); your judgement goes to what the rules leave open: how many issues to run at once, in which order, on which host, with which model and effort, when to hold, and whether a delegated gate may really be granted. You never set `sdd:ready` or an `sdd:*-approved` label that the constitution does not delegate, and you never merge a Constitution issue.

## Steps

1. **Preconditions.** `orca status --json` must report the runtime running; otherwise stop and say so. `cd` to the repository (the automation's workspace, on `main`, pulled). Read `docs/constitution.md`: `Delegated gates`, `Rework budget`, `Language`. Defaults: `--max-parallel 2`; `--dry-run` prints the plan and launches nothing.

2. **What is needed.** `sdd next --all` → one JSON line per open issue. Lines with `action: run` are phases to launch; `action: approve` are delegated gates to verify; `human` and `busy` are only for the report. If nothing is `run` or `approve`, report "nothing to do" and stop.

3. **Delegated gates, verified before granted.** For each `approve` line, in this order and only then `sdd state set N <state>`:
   - `Intake` → `sdd comment open N sdd:triage` is `0` and the triage comment names a type and a size. Set `ready`.
   - `Spec` → check out the PR branch (`sdd pr branch N`); the spec's `Open questions` has no unchecked item and no `TBD`/`TODO`; the last completeness result on the PR (`sdd gate-result list <pr>`) is `PASS`. Set `spec-approved`.
   - `Design` → the design carries no `NEEDS_HUMAN`, `pending human` or `TBD`; every decision it lists exists as an ADR. Set `design-approved`.
   - `Task` → the Task comment exists, has at least one step and none is a question. Set `task-approved`.
   - `Final` → every gate result of the latest review cycle is `PASS` (`sdd gate-result aggregate <pr> <cycle>`), the PR is ready and mergeable, and the issue is not of type Constitution. Merge with `gh pr merge --squash --delete-branch`.
   - `judged: true` → before granting, run the `reviewer` agent with gate set `completeness` (Spec) or `docs` (Design, Task) over the artifact and the issue's original body and author comments; grant only on `PASS`. On any other verdict, do not grant: comment on the issue what the reviewer found and leave the gate to the human.
   - When a check fails, do not grant; comment once on the issue why the gate was withheld (in the constitution's `Language`) and move on.
   Approvals granted here change `sdd next`; re-run it before step 4 so the newly approved issues get their next phase in the same tick.

4. **Plan the wave.** From the `run` lines, order by type (`Constitution`, `Bug`, `Change`, `Feature`, `Task`), then by issue number. Skip an issue that already has a live Orca worker (`orca orchestration worker-list --include-remote --json`, or an Orca worktree named `issue-N` with an active agent). Take at most `--max-parallel` issues minus the ones already running; `triage` does not count against the limit. Hold an issue and say why when it has exhausted its rework budget or when two issues would touch the same module's spec (run them one after the other).

5. **Launch, supervised.** One Run per tick, one Task per phase:
   ```text
   orca orchestration run-create --objective "SDD tick <ISO time>: <n> phases" --json
   orca orchestration worker-start --spec "Run /sdd-<phase> <N> in this worktree. Follow the skill to the end; send worker_done with --outcome succeeded only if the skill finished and set the issue's next state, otherwise --outcome failed with the reason." \
     --worktree new-top-level --name issue-<N> --repo id:<repoId> --agent claude --setup inherit --json
   ```
   Reuse the issue's existing Orca worktree (`orca worktree show --worktree issue:<N> --json` or name `issue-N`) with `--worktree id:<repoId>::<path>` instead of creating another; the phase skills check out the PR branch themselves. Pass `--model`/`--effort` only when the constitution or the human named one; note `launch.effective` in the report. On a non-zero `worker-start`, do not relaunch: follow the receipt's recovery action.

6. **Wait and settle.** `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json`, process every message, `--ack`, repeat until every Dispatch of the tick settled or the wall-clock budget is over (spec/design/task 45 min, implement 135, review 90; triage 15). Answer a worker's `question` only from the constitution, the spec or the issue; anything else is escalated to the human on the issue. Release each settled worker (`worker-release`); keep a failed one retained only if the transcript is needed and say so. A Dispatch that neither settles nor shows life within its budget is stopped per Orca's recovery reference, and the issue's state is left as the phase left it (the skills are idempotent; the next tick resumes).

7. **Report.** One block: per issue — phase, outcome, state before → after, minutes, and Orca's estimated cost when the receipt has it; gates granted and gates withheld with the reason; issues waiting for a human and for what; issues held and why. Post nothing on GitHub beyond what steps 3 and 6 required. End the turn: the next tick is the automation's.

## Running it on a schedule

`sdd orca enable` (inside the repository) creates the Orca automation **SDD factory · <repo>**: every five minutes the precheck `sdd next` runs in a dedicated worktree on the default branch; it exits 1 when nothing is runnable, so idle ticks are recorded as skipped and cost nothing, and only when there is work does Orca wake this skill in that worktree with `--reuse-session`. It is created disabled: `sdd orca run` tries one tick by hand (manual runs skip the precheck), `sdd orca enable --on` turns it on, `sdd orca show|disable|remove` manage it.

## Rules

- Mechanical decisions stay in `sdd next`; if you disagree with a `run` line, hold it and say why, never launch something else.
- A delegated gate is granted only after the verification above; "the artifact looks fine" is not verification.
- Never `sdd state set` to `ready` or `*-approved` for a gate that is not delegated; never merge a Constitution issue; never push to `main`.
- One tick, one Run; leave no worker unsettled without saying so in the report.
