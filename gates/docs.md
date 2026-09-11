# Gates for a documentation-only PR · design-architecture (coherence) + code-quality (clarity)

The PR changes **only documents**: `docs/constitution.md`, a `spec.md`, a `design.md`, ADRs, templates or pointer files. There is no code and no test to judge, so `spec-compliance`, `test-strategy`, `security` and `regression` are skipped mechanically by the skill (`sdd gate-result skip`), and two gates run here: `design-architecture`, read as *coherence of the documents with each other and with the constitution*, and `code-quality`, read as *clarity and hygiene of the prose*. Emit two YAML blocks, in that order, both following `templates/gate-result.template.yaml`.

---

## Gate 1 · design-architecture — coherence

**Question:** do the changed documents say one consistent thing, and does it match what the issue asked for?

### Constitution changes (issue type Constitution) — BLOCKER unless noted
- Every rule is one line, carries a unique ID in its block's series (`A5` after `A4`, never two `T3`), and states a rule, not a rationale or an example.
- The version bump follows the change: removing or rewording a rule so that something previously forbidden is allowed is a **major**; added rules are a **minor**; wording only is a **patch**. Mismatch is BLOCKER.
- The change is exactly what the issue body describes: a rule the issue does not mention, added or removed, is BLOCKER; a rule the issue announces and the diff lacks is BLOCKER.
- No model names, runner settings, provider names or costs inside the constitution: orchestrator policy does not live here (WARNING if descriptive, BLOCKER if it acts as a rule).
- Identity, Decisions and Verification stay consistent with the Rules. `CLAUDE.md` remains a pointer only.

### Spec and design changes — BLOCKER unless noted
- Every requirement keeps its stable ID; renumbered or reused IDs are BLOCKER.
- The Spec uses business language only (see `completeness.md` §10): WARNING each, BLOCKER if a requirement depends on the technical term.
- The Design cites rule IDs instead of restating rules (restated rule: WARNING). Every decision the design links exists as an ADR; an edited ADR instead of a superseding one is BLOCKER.
- ADR discipline: an ADR that fails any of the four tests in `templates/adr.template.md` (already decided by a rule, the spec or an earlier ADR; module-local; cheap to reverse; not genuinely open) is WARNING, `required_action: fold into design.md as a one-line note`; a cross-cutting, costly-to-reverse choice recorded only as a design note is WARNING; more than two ADRs in one PR without justification in the PR description is WARNING.
- In the changed parts, a design element without a requirement, or a requirement without a design element, is BLOCKER.

### Security of the rules — BLOCKER unless noted
The rules are the only place a security property is guaranteed before code exists; judge the text as a security reviewer judges a design. When the changed documents introduce or describe any of the following, the matching guarantee must be a rule (gap: BLOCKER; vague "should"/"when possible": WARNING):
- An identity or boundary (tenant, organization, installation, user): how the key is derived from a **verified principal**, never from request input; what a caller presents to cross it; nothing crosses it silently.
- An enrollment or registration: who authorizes it, with what; no anonymous enrollment.
- An inbound event from outside (webhook, callback, message): origin verified before anything is read; what happens to an unverified one.
- A credential or token: scope, lifetime, never persisted or logged, who may hold it.
- A channel or subscription: who may subscribe and publish, enforced by the platform, not by convention.
- A privileged automatic action (merge, approval, deletion): the actor is a verified human with the permission; an app or bot never counts.
Two rules that grant and forbid the same crossing are a contradiction and BLOCKER; the fix states the exception inside the forbidding rule.

### Cross-document consistency
- A changed rule contradicting an approved spec or design elsewhere is NEEDS_HUMAN with the conflicting locations named; the reviewer never decides which document yields.

---

## Gate 2 · code-quality — clarity and hygiene

**Question:** can a newcomer read these documents and act on them without asking?

- **Current state only.** Any narration of how the document got here (change logs, "corrected after #N", answered questions, per-change deltas) is BLOCKER: git is the history, decisions go to ADRs, deltas go to the PR body.
- Duplicated statements inside one document, or the same rule in two places: WARNING.
- Ambiguous quantifiers ("usually", "when possible", "should" where a rule is meant): WARNING in a rule, BLOCKER in a requirement.
- Placeholders left behind (`<...>`, `TBD`, `TODO`, `???`): BLOCKER in a constitution or spec, WARNING in a design.
- Prose follows the language configured in `.sdd/config.yml`; rule IDs, identifiers and paths stay as they are. A mixed-language sentence is WARNING.
- Formatting that breaks the template's structure (missing section, uneven table, skipped heading level): WARNING; pure style: NIT.

## Output

Two blocks, `gate: design-architecture` then `gate: code-quality`, same `issue`, `pr`, `commit`, `rework_cycle`; schema as in `templates/gate-result.template.yaml`. `NEEDS_HUMAN` when two documents genuinely conflict and the issue does not say which wins.
