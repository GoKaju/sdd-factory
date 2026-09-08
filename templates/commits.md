# Commits

Rules every `/sdd-*` skill follows when it commits. The constitution's Workflow rules win over this file.

- **Never on `main`.** Commit on the issue's branch. Never `git push` to `main`/`master`, never force-push, never amend, rebase or `reset --hard` published history: fix with a new commit.
- **One intent per commit.** A commit is atomic when it is one logical change that makes sense reverted alone. Stage selectively (`git add <path>`, `git add -p`); never `git add -A` when more than one intent is present.
- **Documents apart from code.** `spec.md`, `design.md` and ADRs are committed on their own as `docs(<module>): …`; code and its tests ride together (`feat`, `fix`); a port and its fake, an error and the test asserting it, a migration and the mapper needing it belong in one commit.
- **Conventional Commits with the package as scope:** `<type>(<scope>): <subject>`. Type: `feat | fix | refactor | test | docs | chore | build | ci | perf | style`. Scope: the name of the package that contains the files (`docs(<module>)` for documents; `repo`, `ci`, `deps` for root tooling). Subject: imperative, lowercase, no trailing period, ≤ 72 chars. Body only when the *why* is not obvious. Breaking change: `!` after the scope and a `BREAKING CHANGE:` footer.
- **Issue reference:** `Refs #N` in the footer. Never `Closes #N` in a commit: the closing keyword belongs to the first line of the PR body.
- **Never commit** secrets, `.env*`, credential files, build output, caches, `node_modules`, personal editor or agent settings. Leave nothing uncommitted behind: everything is committed or reverted before the phase ends.
- **Push** only the current non-main branch: `git push -u origin <branch>`.

Examples: `feat(payroll): reject overtime without a policy percentage` · `docs(overtime): spec for #42` · `test(payroll): assert exact OvertimePolicyMissingPercentage for OT-003`.
