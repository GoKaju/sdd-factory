---
description: Run the six adversarial Review Gates on an issue's PR (three paired reviewers over one shared review pack by default), publish gate results, aggregate, and drive bounded rework until PASS or NEEDS_HUMAN. Requires sdd:in-review or sdd:rework.
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /sdd-review $1

Verify the implementation of issue **#$1** and take it to Approval Gate 4 or back to rework.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Result schema: `${CLAUDE_PLUGIN_ROOT}/templates/gate-result.template.yaml`.

## Steps

1. **Preconditions.** `sdd-state.sh require $1 in-review rework design-approved`. In `design-approved` you are being invoked after a document-only amendment (Task unchanged, code unchanged): record the design approval (`status: approved` in `design.md`, commit) and continue as `in-review`. `pr=$(sdd-pr.sh find $1)`; check out its branch. Read `docs/constitution.md` (Rules, Commands, Verification: gates and `max_rework_cycles`), the Task comment, and the affected `spec.md`/`design.md`. `cycle` = number of previous aggregate results on the PR (`sdd-gate-result.sh list $pr | ...`), starting at 0.

2. **Deterministic checks first.** Run the `ci-runner` agent. If red: publish one result with `gate: deterministic-checks`, `status: BLOCKED`, and stop with `sdd-state.sh set $1 rework`. Gates never run on a red build.

3. **Review pack.** `pack=$(sdd-review-pack.sh build $1 <cycle>)`. One file with everything the gates need (constitution, issue with triage and Task, spec/design approved vs PR, touched files, test stats, full diff), so no reviewer explores the repository from scratch. Rebuild it on every cycle.

4. **Gates, in parallel.** Default (`Review mode: paired`, or no such line in the constitution): launch the three paired reviewer agents, each with the pack path, issue, PR, commit sha and `rework_cycle: <cycle>`: `spec-test-reviewer` (gates spec-compliance + test-strategy), `design-quality-reviewer` (design-architecture + code-quality), `security-regression-reviewer` (security + regression). Each returns **two** YAML blocks; split them and `sdd-gate-result.sh post $pr <file>` for each, so the six gate results exist exactly as before. If the constitution's Verification section says `Review mode: single`, launch the six single-gate agents instead (`spec-reviewer`, `design-reviewer`, `test-reviewer`, `security-reviewer`, `regression-reviewer`, `quality-reviewer`), also with the pack path.

5. **Aggregate.** `sdd-gate-result.sh aggregate $pr <cycle>`.
   - `PASS` → `sdd-state.sh set $1 final-review`, `sdd-pr.sh ready $1`, `sdd-flag.sh clear lock-docs`. Post a short summary comment on the PR (gates, warnings to acknowledge). Done.
   - `NEEDS_HUMAN` or `BLOCKED` → `sdd-state.sh set $1 final-review`; comment on the issue what needs a human. Done.
   - `FAIL` → step 6.

6. **Rework, bounded.** If `cycle + 1 >= max_rework_cycles`: `sdd-state.sh set $1 final-review`, comment on the issue "NEEDS_HUMAN: rework limit reached" with the remaining BLOCKERs, and stop. Otherwise `sdd-state.sh set $1 rework`, fix **only the BLOCKER findings** (tests and code; never spec, design or constitution), commit via `committer`, push, and go back to step 2 with `cycle + 1`.

## Rules

- Reviewers are read-only and adversarial; you do not argue with a BLOCKER, you fix it or escalate it. A finding you believe is wrong goes to the human as `NEEDS_HUMAN`, with your reasoning, not silently ignored.
- Never edit `spec.md`, `design.md` or `docs/constitution.md` to make a gate pass. A Spec Compliance drift finding means the code changes, or the issue is escalated.
- Never delete, skip or weaken a test to get Test Strategy to PASS.
