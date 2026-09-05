---
description: Run the six adversarial Review Gates on an issue's PR (three paired reviewers over one shared review pack by default; one documentation reviewer when the PR changes only documents), publish gate results, aggregate, and drive bounded rework until PASS or NEEDS_HUMAN. Requires sdd:in-review or sdd:rework.
argument-hint: "<issue-number>"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /sdd-review $1

Verify the implementation of issue **#$1** and take it to Approval Gate 4 or back to rework.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Result schema: `${CLAUDE_PLUGIN_ROOT}/templates/gate-result.template.yaml`.

## Steps

1. **Preconditions.** `sdd-state.sh require $1 in-review rework design-approved`. In `design-approved` you are being invoked after a document-only amendment (Task unchanged, code unchanged): record the design approval (`status: approved` in `design.md`, commit) and continue as `in-review`. `pr=$(sdd-pr.sh find $1)`; check out its branch. Read `docs/constitution.md` (Rules, Commands), `max=$(sdd-config.sh get .review.maxReworkCycles)` and `mode=$(sdd-config.sh get .review.mode)` from `.sdd/config.json`, the Task comment, and the affected `spec.md`/`design.md`. `cycle` = number of previous aggregate results on the PR (`sdd-gate-result.sh list $pr | ...`), starting at 0. `scope=$(sdd-pr.sh scope $1)`: `docs` when every changed file is documentation (`docs/**`, `*.md`, issue forms), `code` otherwise.

2. **Deterministic checks first.** Skip this step when `scope` is `docs`: the build cannot change, and the repository's CI check still guards the merge. Otherwise run the `ci-runner` agent. If red: publish one result with `gate: deterministic-checks`, `status: BLOCKED`, and stop with `sdd-state.sh set $1 rework`. Gates never run on a red build.

3. **Review pack.** `pack=$(sdd-review-pack.sh build $1 <cycle>)`. One file with everything the gates need (constitution, issue with triage and Task, spec/design approved vs PR, touched files, test stats, full diff), so no reviewer explores the repository from scratch. Rebuild it on every cycle.

4. **Gates, in parallel.** **`scope` `docs`** (documentation-only PR, typical of a Constitution issue or a document-only amendment): four gates have nothing to judge, so do not launch them. Launch only the `docs-reviewer` agent with the pack path, issue, PR, commit sha, `rework_cycle: <cycle>` and the model below; it returns **two** YAML blocks (`design-architecture` read as coherence of the documents, `code-quality` read as clarity and hygiene); split and `sdd-gate-result.sh post $pr <file>` each. Then `sdd-gate-result.sh skip $pr <gate> <cycle> "documentation-only change"` for `spec-compliance`, `test-strategy`, `security` and `regression`, so the six results exist and the aggregate rule is unchanged. Continue at step 5.

   **`scope` `code`:** `model=$(sdd-config.sh tier-model "$(sdd-config.sh reviewer-tier $1)")` resolves the reviewers' model: the repository's `.sdd/config.json` names an intelligence tier (light | standard | strong) by issue type or triage size, and this machine maps the tier to a model. Pass it as the `model` of every reviewer agent you launch. `mode` `paired` (default): launch the three paired reviewer agents, each with the pack path, issue, PR, commit sha and `rework_cycle: <cycle>`: `spec-test-reviewer` (gates spec-compliance + test-strategy), `design-quality-reviewer` (design-architecture + code-quality), `security-regression-reviewer` (security + regression). Each returns **two** YAML blocks; split them and `sdd-gate-result.sh post $pr <file>` for each, so the six gate results exist exactly as before. `mode` `single`: launch the six single-gate agents instead (`spec-reviewer`, `design-reviewer`, `test-reviewer`, `security-reviewer`, `regression-reviewer`, `quality-reviewer`), also with the pack path.

5. **Aggregate.** `sdd-gate-result.sh aggregate $pr <cycle>`.
   - `PASS` → `sdd-state.sh set $1 final-review`, `sdd-pr.sh ready $1`, `sdd-flag.sh clear lock-docs`. Post a short summary comment on the PR (gates, warnings to acknowledge). Done.
   - `NEEDS_HUMAN` or `BLOCKED` → `sdd-state.sh set $1 final-review`; comment on the issue what needs a human. Done.
   - `FAIL` → step 6.

6. **Rework, bounded.** If `cycle + 1 >= $max`: `sdd-state.sh set $1 final-review`, comment on the issue "NEEDS_HUMAN: rework limit reached" with the remaining BLOCKERs, and stop. Otherwise `sdd-state.sh set $1 rework`, fix **only the BLOCKER findings**, commit via `committer`, push, and go back to step 2 with `cycle + 1`. In `scope` `code` the fixes touch tests and code, never spec, design or constitution. In `scope` `docs` the documents **are** the change under review, so the fixes touch exactly the files the PR already changes and nothing else; for `docs/constitution.md` set `sdd-flag.sh set allow-constitution` for the fix and clear it right after.

## Rules

- Reviewers are read-only and adversarial; you do not argue with a BLOCKER, you fix it or escalate it. A finding you believe is wrong goes to the human as `NEEDS_HUMAN`, with your reasoning, not silently ignored.
- Never edit `spec.md`, `design.md` or `docs/constitution.md` to make a gate pass on a code change. A Spec Compliance drift finding means the code changes, or the issue is escalated. (A documentation-only PR is the exception by definition: there the reviewed documents are what gets fixed.)
- Never delete, skip or weaken a test to get Test Strategy to PASS.
