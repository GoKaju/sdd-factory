---
name: sdd-init
description: Initialize a repository for the SDD factory - constitution, blueprint, .sdd/config.yml (assisted), CLAUDE.md pointer, state labels, organization Issue Types and issue forms. Run once per project; idempotent.
argument-hint: "[project-name]"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# /sdd-init [project-name]

Initialize the current repository for Spec-Driven Development with the sdd-factory plugin. Idempotent: re-running adds what is missing and never overwrites an existing `docs/constitution.md`, `docs/blueprint.md` or `.sdd/config.yml`.

Conventions: `sdd` = `${CLAUDE_PLUGIN_ROOT}/bin/sdd` (`sdd help` lists its commands). Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Steps

1. **Preconditions.** `gh auth status` succeeds; the repository has a GitHub remote; the owner is an **organization** (native Issue Types do not exist on personal accounts). If the owner is a user account, stop and explain. `jq` and `python3` are installed.

2. **Constitution.** If `docs/constitution.md` does not exist, copy `templates/constitution.template.md` there and fill in what the repository reveals: project name (the argument or the repo name), the Stack table if obvious from dependencies. Leave every unknown as its `<placeholder>` and list the placeholders at the end so the human fills them. Do not invent rules: the rule lines with placeholders are the team's to write (or to copy from `templates/examples/`); only the Workflow lines, C1 and Q3 are the framework's own and stay as they are. Keep it to rules a review blocks on; conventions go to the blueprint (step 2b).

2b. **Blueprint.** If `docs/blueprint.md` does not exist, copy `templates/blueprint.template.md` there. Every row is a written convention (location pattern, file-name pattern, base class or shape); the Exemplar column is optional (`—` when there is no file to point at). When the repository already has code, fill it from what it shows: the module layout of an existing module, one row per kind of element you find, with a real file as exemplar where one follows the row, and one row per kind of test. Describe only what the code already does consistently; where modules disagree, leave the row as a `<placeholder>` and list it for the human. A repository without code gets its conventions from the human: propose the layout and the kinds the stack and the constitution's rules suggest (or `templates/examples/`), confirm them one block at a time, and write every exemplar as `—`.

3. **Config, assisted.** `sdd config init` creates `.sdd/config.yml` from the template. Then fill it with the human, one question at a time when the repository does not answer it:
   - `language` (en | es) — the language of GitHub prose only (comments, forms, PR bodies); from the issue templates if any, else ask. Say that the repository itself, `docs/` included, is always English.
   - `commands` — read the package manifest scripts and `.github/workflows/*.yml`; propose the install / lint / typecheck / build / test lines in CI order and confirm them; `sdd config set commands "<cmd1>" "<cmd2>" ...`.
   - `models.*` — keep the defaults unless the human wants otherwise; say what they are.
   - `gates.delegated` — default none; explain in two lines what delegating means (the factory grants the gate after mechanical verification; `(judged)` adds the reviewer) and ask which, if any.
   - `gates.warnings_at_final`, `gates.rework_budget`, `await.*` — defaults; mention them, change only on request.
   Finish with `sdd config validate` and `sdd ci list`.

4. **Pointer file.** Write `CLAUDE.md` with exactly:
   ```
   @docs/constitution.md
   @docs/blueprint.md
   ```
   If it exists with other content, do not overwrite: show the diff and ask.

5. **State labels.** `sdd state ensure-labels`.

6. **Issue Types.** `sdd org-types ensure`. For every line starting with `MANUAL`, tell the human exactly what to create and where.

7. **Issue forms.** `lang=$(sdd config get language)`; copy `templates/issue-forms/<lang>/*.yml` into `.github/ISSUE_TEMPLATE/`. The forms are for non-technical authors; do not add technical fields.

8. **Ignore the worktrees.** Ensure `.gitignore` contains `.sdd/worktrees/` (`/sdd` keeps one git worktree per issue there) and `.sdd/tmp/`. `.sdd/config.yml` and `.sdd/learning/` are versioned.

9. **Permissions.** Ensure `.claude/settings.json` denies `Bash(git push origin main:*)`, `Bash(git push -f:*)`, `Bash(git push --force:*)` (merge into the existing file). The plugin's hooks enforce the same at runtime.

10. **Branch protection.** Do not change it; print the recommended settings for `main`: require PR, require the CI check, one approval, no force push.

11. **Report.** Files created or changed, config values set, labels and types created, remaining `<placeholders>`, manual steps, and that the flow starts with `/sdd <issue-number>`. Do not commit unless the human asks (then follow `templates/commits.md`).
