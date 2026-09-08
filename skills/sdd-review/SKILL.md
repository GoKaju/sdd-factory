---
name: sdd-review
description: Run the six adversarial Review Gates on an issue's PR over one shared review pack (two documentation gates when the PR changes only documents), publish gate results, aggregate, and drive bounded rework until PASS or NEEDS_HUMAN. Requires sdd:in-review or sdd:rework.
argument-hint: "<issue-number>"
disable-model-invocation: true
---

# /sdd-review N

Verify the implementation of issue **#N** and take it to Approval Gate 4 or back to rework.

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`. Result schema: `templates/gate-result.template.yaml`; common gate rules: `gates/README.md`.

## Steps

1. **Preconditions.** `sdd state require N in-review rework design-approved`. In `design-approved` you are invoked after a document-only amendment (Task and code unchanged): record the design approval (`status: approved` in `design.md`, commit) and continue as `in-review`. `pr=$(sdd pr find N)`; check out its branch. Read `docs/constitution.md`, `max=$(sdd rework-budget)`, the Task comment and the affected `spec.md`/`design.md`. `cycle` = number of previous review cycles on the PR (highest cycle in `sdd gate-result list $pr`, plus one; 0 if none). `scope=$(sdd pr scope N)`: `docs` when every changed file is documentation, `code` otherwise.

2. **Deterministic checks first.** Skip when `scope` is `docs`. Otherwise `sdd ci`. If red: publish one result with `gate: deterministic-checks`, `status: BLOCKED`, the failing command in a finding, then `sdd state set N rework` and stop. Gates never run on a red build.

3. **Review pack.** `pack=$(sdd review-pack build N $cycle)`: one file with everything the gates need (constitution, issue with triage and Task, spec/design PR version and diff against the approved one, touched files, test stats, full diff). Rebuild it every cycle.

4. **Gates.** Inputs for every gate run: `pack`, issue, PR, head sha, `rework_cycle: $cycle`, and the plugin's `gates/` directory.
   - **With subagents** (Claude Code and any host that launches a fresh-context agent): launch the plugin's `reviewer` agent once with `gates: code` (six YAML blocks) or `gates: docs` (two blocks). When the diff exceeds ~1500 lines and the host runs subagents in parallel, you may split `code` into three runs: `spec-compliance,test-strategy` · `design-architecture,code-quality` · `security,regression`.
   - **Without subagents:** run the gates yourself, one at a time, re-reading the pack and following `gates/<gate>.md` literally; you are judging your own work, so be harsher, not kinder.
   - Split the returned blocks into one file each and `sdd gate-result post $pr <file>`. For `scope` `docs` also `sdd gate-result skip $pr <gate> $cycle "documentation-only change"` for `spec-compliance`, `test-strategy`, `security` and `regression`, so six results exist and the aggregate rule is unchanged.

5. **Aggregate.** `sdd gate-result aggregate $pr $cycle`.
   - `PASS` → `sdd state set N final-review`, `sdd pr ready N`, `sdd flag clear lock-docs`. Post a short summary comment on the PR (gates, WARNINGs the human must acknowledge). Done: Approval Gate 4 is the human's, who merges or writes a `/rework` comment on the PR with one bullet per required change (`/sdd-implement N` then applies them).
   - `NEEDS_HUMAN` or `BLOCKED` → `sdd state set N final-review`; comment on the issue what needs a human. Done.
   - `FAIL` → step 6.

6. **Rework, bounded.** If `cycle + 1 >= max`: `sdd state set N final-review`, comment "NEEDS_HUMAN: rework budget exhausted" with the remaining BLOCKERs, stop. Otherwise `sdd state set N rework`, fix **only the BLOCKER findings**, commit per `templates/commits.md`, push, and return to step 2 with `cycle + 1`. In `scope` `code` the fixes touch code and tests, never spec, design, ADRs or constitution. In `scope` `docs` the documents **are** the change under review: fix exactly the files the PR already changes (for `docs/constitution.md`, `sdd flag set allow-constitution` around the edit).

## Rules

- Reviewers are read-only and adversarial; you do not argue with a BLOCKER, you fix it or escalate it. A finding you believe wrong goes to the human as `NEEDS_HUMAN` with your reasoning, never silently ignored.
- Never edit `spec.md`, `design.md`, ADRs or `docs/constitution.md` to make a gate pass on a code change. Drift means the code changes, or the issue is escalated.
- Never delete, skip or weaken a test to get Test Strategy to PASS.
