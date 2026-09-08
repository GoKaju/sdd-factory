---
name: sdd-init
description: Initialize a repository for the SDD factory - constitution, pointer files, state labels, organization Issue Types and issue forms. Run once per project; idempotent.
argument-hint: "[project-name]"
disable-model-invocation: true
---

# /sdd-init [project-name]

Initialize the current repository for Spec-Driven Development. Idempotent: re-running adds what is missing and never overwrites an existing `docs/constitution.md`.

Conventions: **N** is the issue number given as argument. `sdd` is the plugin's `bin/sdd` (in Claude Code `${CLAUDE_PLUGIN_ROOT}/bin/sdd`; elsewhere the `bin/sdd` of the plugin checkout, ideally on the PATH; `sdd help` lists its commands). Templates live in the plugin's `templates/`, gate checklists in `gates/`.

## Steps

1. **Preconditions.** `gh auth status` succeeds; the repository has a GitHub remote; the owner is an **organization** (native Issue Types do not exist on personal accounts). If the owner is a user account, stop and explain. `jq` is installed. If `sdd` is not on the PATH, print the line to add (`export PATH="<plugin>/bin:$PATH"`) and keep using the full path meanwhile.

2. **Constitution.** If `docs/constitution.md` does not exist, copy `templates/constitution.template.md` there and fill in what the repository reveals: project name (the argument or the repo name), the check commands for the `## Commands` block (read the package manifest scripts and `.github/workflows/*.yml`), runtime and persistence if obvious from dependencies. Leave every unknown as its `<placeholder>` and list the placeholders at the end so the human fills them. Do not invent rules: the `## Rules` blocks carry placeholders the team writes (or copies from `templates/examples/`); only the Workflow block, C1 and Q3 are the framework's own and stay as they are.

3. **Pointer files.** Write `CLAUDE.md` with exactly:
   ```
   @docs/constitution.md
   ```
   and `AGENTS.md` with a pointer plus the skill list, so hosts without a skill system still find the flow:
   ```
   # Agents
   All rules and commands for this repository live in `docs/constitution.md`. Read it first; nothing else here is authoritative.

   The development flow is Spec-Driven Development, run with the sdd-factory skills (one SKILL.md each under the plugin's `skills/`):
   sdd-triage · sdd-spec · sdd-design · sdd-task · sdd-implement · sdd-review · sdd-status · sdd-init
   ```
   If either file exists with other content, do not overwrite: show the diff and ask.

4. **State labels.** `sdd state ensure-labels`.

5. **Issue Types.** `sdd org-types ensure`. For every line starting with `MANUAL`, tell the human exactly what to create and where.

6. **Issue forms.** `lang=$(sdd lang)`; copy `templates/issue-forms/<lang>/*.yml` into `.github/ISSUE_TEMPLATE/`. The forms are for non-technical authors; do not add technical fields.

7. **Host permissions (Claude Code only).** If the host is Claude Code, ensure `.claude/settings.json` denies `Bash(git push origin main:*)`, `Bash(git push -f:*)`, `Bash(git push --force:*)` (merge into the existing file). Other hosts rely on branch protection.

8. **Branch protection.** Do not change it; print the recommended settings for `main`: require PR, require the CI check, one approval, no force push.

9. **Report.** Files created or changed, labels and types created, remaining `<placeholders>`, manual steps. Do not commit unless the human asks (then follow `templates/commits.md`).
