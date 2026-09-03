---
description: Initialize a repository for the SDD factory - constitution, pointer files, state labels, organization Issue Types and issue forms. Run once per project.
argument-hint: "[project-name]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /sdd-init

Initialize the current repository for Spec-Driven Development. Idempotent: re-running updates what is missing and never overwrites an existing `docs/constitution.md`.

Scripts: `${CLAUDE_PLUGIN_ROOT}/scripts/`. Templates: `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Steps

1. **Preconditions.** `gh auth status` succeeds; the repository has a GitHub remote; the owner is an **organization** (Issue Types do not exist on personal accounts). If the owner is a user account, stop and explain.

2. **Constitution.** If `docs/constitution.md` does not exist, copy `templates/constitution.template.md` to `docs/constitution.md` and fill in what you can detect from the repository: project name (`$1` or the repo name), the package manager and CI commands (read `package.json` scripts and `.github/workflows/*.yml`), the runtime and persistence if obvious from dependencies. Leave every unknown as its `<placeholder>` and list the placeholders at the end so the human fills them. Never rewrite the **Rules** section: it is the framework's minimal rule set; a project changes it only through a Constitution-type issue later.

3. **Pointer files.** Write `CLAUDE.md` with exactly:
   ```
   @docs/constitution.md
   ```
   and `AGENTS.md` with exactly:
   ```
   # Agents
   All rules and commands for this repository live in `docs/constitution.md`. Read it first; nothing else here is authoritative.
   ```
   If either file already exists with other content, do not overwrite: show the diff and ask.

4. **State labels.** Run `sdd-state.sh ensure-labels`.

5. **Issue Types.** Run `sdd-org-types.sh ensure`. For every line starting with `MANUAL`, tell the human exactly what to create and where.

6. **Issue forms.** Read `Language` from the constitution's Identity section (`en` or `es`; default `en`) and copy `templates/issue-forms/<lang>/*.yml` into `.github/ISSUE_TEMPLATE/`. The forms are for non-technical authors; do not add technical fields.

7. **Permissions.** Ensure `.claude/settings.json` denies `Bash(git push origin main:*)`, `Bash(git push -f:*)`, `Bash(git push --force:*)` (merge into the existing file if present).

8. **Branch protection.** Do not change it; print the recommended settings for `main`: require PR, require the CI check, one approval, no force push.

9. **Report.** List files created or changed, labels and types created, remaining `<placeholders>` in the constitution, and the manual steps if any. Do not commit: hand off to the `committer` agent only if the human asks.
