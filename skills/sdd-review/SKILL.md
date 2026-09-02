---
description: Run the six adversarial Review Gates on an issue's PR, publish gate results, aggregate, and drive bounded rework until PASS or NEEDS_HUMAN. Requires sdd:in-review or sdd:rework.
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /sdd-review $1

Verify the implementation of issue **#$1** and take it to Approval Gate 4 or back to rework.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Result schema: `${CLAUDE_PLUGIN_ROOT}/templates/gate-result.template.yaml`.

## Steps

1. **Preconditions.** `sdd-state.sh require $1 in-review rework`. `pr=$(sdd-pr.sh find $1)`; check out its branch. Read `docs/constitution.md` (Rules, Commands, Verification: gates and `max_rework_cycles`), the Task comment, and the affected `spec.md`/`design.md`. `cycle` = number of previous aggregate results on the PR (`sdd-gate-result.sh list $pr | ...`), starting at 0.

2. **Deterministic checks first.** Run the `ci-runner` agent. If red: publish one result with `gate: deterministic-checks`, `status: BLOCKED`, and stop with `sdd-state.sh set $1 rework`. Gates never run on a red build.

3. **Gates, in parallel.** Launch the six reviewer agents with the same inputs (issue, PR, spec/design paths, commit sha, `rework_cycle: <cycle>`): `spec-reviewer`, `design-reviewer`, `test-reviewer`, `security-reviewer`, `regression-reviewer`, `quality-reviewer`. Each returns one YAML block. Save each to a temp file and `sdd-gate-result.sh post $pr <file>`.

4. **Aggregate.** `sdd-gate-result.sh aggregate $pr <cycle>`.
   - `PASS` → `sdd-state.sh set $1 final-review`, `sdd-pr.sh ready $1`, remove `.git/sdd/lock-docs`. Post a short summary comment on the PR (gates, warnings to acknowledge). Done.
   - `NEEDS_HUMAN` or `BLOCKED` → `sdd-state.sh set $1 final-review`; comment on the issue what needs a human. Done.
   - `FAIL` → step 5.

5. **Rework, bounded.** If `cycle + 1 >= max_rework_cycles`: `sdd-state.sh set $1 final-review`, comment on the issue "NEEDS_HUMAN: rework limit reached" with the remaining BLOCKERs, and stop. Otherwise `sdd-state.sh set $1 rework`, fix **only the BLOCKER findings** (tests and code; never spec, design or constitution), commit via `committer`, push, and go back to step 2 with `cycle + 1`.

## Rules

- Reviewers are read-only and adversarial; you do not argue with a BLOCKER, you fix it or escalate it. A finding you believe is wrong goes to the human as `NEEDS_HUMAN`, with your reasoning, not silently ignored.
- Never edit `spec.md`, `design.md` or `docs/constitution.md` to make a gate pass. A Spec Compliance drift finding means the code changes, or the issue is escalated.
- Never delete, skip or weaken a test to get Test Strategy to PASS.
