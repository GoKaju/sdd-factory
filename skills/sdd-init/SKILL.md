---
name: sdd-init
description: Initialize a repository for the SDD factory - constitution, .sdd/config.yml (assisted), CLAUDE.md pointer, state labels, organization Issue Types and issue forms. Run once per project; idempotent.
argument-hint: "[project-name]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# /sdd-init [project-name]

Initialize the current repository for Spec-Driven Development with the sdd-factory plugin. Idempotent: re-running adds what is missing and never overwrites an existing `docs/constitution.md` or `.sdd/config.yml`.

Conventions: `sdd` = `${CLAUDE_PLUGIN_ROOT}/bin/sdd` (`sdd help` lists its commands). Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Steps

1. **Preconditions.** `gh auth status` succeeds; the repository has a GitHub remote; the owner is an **organization** (native Issue Types do not exist on personal accounts). If the owner is a user account, stop and explain. `jq` and `python3` are installed.

2. **Constitution.** If `docs/constitution.md` does not exist, copy `templates/constitution.template.md` there and fill in what the repository reveals: project name (the argument or the repo name), runtime and persistence if obvious from dependencies. Leave every unknown as its `<placeholder>` and list the placeholders at the end so the human fills them. Do not invent rules: the `## Rules` blocks carry placeholders the team writes (or copies from `templates/examples/`); only the Workflow block, C1 and Q3 are the framework's own and stay as they are. If an existing constitution still carries a `## Commands` block or `Language` / `Rework budget` / `Delegated gates` / `Warnings at Final` lines (v1 layout), leave the file alone here: step 3 migrates the values and you then propose the cleanup as a Constitution issue.

3. **Config, assisted.** `sdd config init --from-constitution` creates `.sdd/config.yml` from the template (and migrates v1 values when present). Then fill it with the human, one question at a time when the repository does not answer it:
   - `language` (en | es) — from the constitution or the issue templates if any; else ask.
   - `commands` — read the package manifest scripts and `.github/workflows/*.yml`; propose the install / lint / typecheck / build / test lines in CI order and confirm them; `sdd config set commands "<cmd1>" "<cmd2>" ...`.
   - `models.*` — keep the defaults unless the human wants otherwise; say what they are.
   - `gates.delegated` — default none; explain in two lines what delegating means (the factory grants the gate after mechanical verification; `(judged)` adds the reviewer) and ask which, if any.
   - `gates.warnings_at_final`, `gates.rework_budget`, `await.*` — defaults; mention them, change only on request.
   Finish with `sdd config validate` and `sdd ci list`.

4. **Pointer file.** Write `CLAUDE.md` with exactly:
   ```
   @docs/constitution.md
   ```
   If it exists with other content, do not overwrite: show the diff and ask.

5. **State labels.** `sdd state ensure-labels`.

6. **Issue Types.** `sdd org-types ensure`. For every line starting with `MANUAL`, tell the human exactly what to create and where.

7. **Issue forms.** `lang=$(sdd config get language)`; copy `templates/issue-forms/<lang>/*.yml` into `.github/ISSUE_TEMPLATE/`. The forms are for non-technical authors; do not add technical fields.

8. **Ignore the worktrees.** Ensure `.gitignore` contains `.sdd/worktrees/` (`/sdd` keeps one git worktree per issue there) and `.sdd/tmp/`. `.sdd/config.yml` and `.sdd/learning/` are versioned.

9. **Permissions.** Ensure `.claude/settings.json` denies `Bash(git push origin main:*)`, `Bash(git push -f:*)`, `Bash(git push --force:*)` (merge into the existing file). The plugin's hooks enforce the same at runtime.

10. **Branch protection.** Do not change it; print the recommended settings for `main`: require PR, require the CI check, one approval, no force push.

11. **Report.** Files created or changed, config values set, labels and types created, remaining `<placeholders>`, manual steps, and that the flow starts with `/sdd <issue-number>`. Do not commit unless the human asks (then follow `templates/commits.md`).
