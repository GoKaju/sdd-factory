---
name: sdd-config
description: Show or change how the SDD factory operates in this repository (.sdd/config.yml) - language, model per phase, delegated gates, warnings policy, rework budget, await limits, deterministic check commands. Assisted and validated; never touches docs/constitution.md.
argument-hint: "[key [value...]] | show | validate"
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# /sdd-config [key [value...]]

Edit `.sdd/config.yml`, the operation config of the sdd-factory plugin for this repository. Rules of the project are **not** here (they live in `docs/constitution.md` and change only through a Constitution issue); this file says how the factory runs.

Conventions: `sdd` = `${CLAUDE_PLUGIN_ROOT}/bin/sdd`. Reference template with every key documented: `${CLAUDE_PLUGIN_ROOT}/templates/config.template.yml`.

## Behaviour

- No argument, or `show` → `sdd config show`, then for each section one line of what it means and whether it is still a `<placeholder>`; end with `sdd config validate`. Offer to change something.
- `validate` → `sdd config validate` and explain each problem with the fix.
- `<key>` alone → print the current value and the allowed values, ask for the new one.
- `<key> <value...>` → `sdd config set <key> <value...>` (several values for a list key: `gates.delegated Intake "Spec (judged)"`, `commands "pnpm install --frozen-lockfile" "pnpm test"`; no value for an empty list), then `sdd config validate`.
- Missing file → `sdd config init --from-constitution`, then proceed as `show`.

## Keys

| Key | Values | Meaning |
| --- | --- | --- |
| `language` | `en` \| `es` | prose of tracker comments, issue forms, PR bodies |
| `models.<phase>` | `haiku` \| `sonnet` \| `opus` \| `inherit` | model of the subagent per phase: `triage`, `spec`, `design`, `task`, `implement`, `reviewer`, `learning`; `inherit` = the session's model. Effort per phase is fixed in the plugin's agents. |
| `gates.delegated` | list of `Intake`, `Spec`, `Design`, `Task`, `Final`, each optionally `(judged)` | approval gates `/sdd` grants after mechanical verification; `(judged)` adds the reviewer's PASS. A Constitution issue is never merged by the factory. |
| `gates.warnings_at_final` | `human` \| `merge` \| `rework` | what a delegated Final does with WARNINGs |
| `gates.rework_budget` | integer ≥ 1 | review cycles before NEEDS_HUMAN |
| `await.interval_seconds` | integer | polling interval of `sdd await` |
| `await.max_minutes` | integer | total minutes `/sdd` waits for a human per run before ending the turn |
| `commands` | list of shell lines | `sdd ci` runs exactly these, in order, fail-fast |

## Rules

- Never edit `docs/constitution.md` here. If the human asks for a rule, say it is a Constitution issue.
- Explain a change's effect in one line before applying it when it widens what the factory may do on its own (`gates.delegated`, `warnings_at_final: merge|rework`).
- Do not commit unless the human asks (`chore(sdd): config ...`).
