<!-- Write an ADR only when all four hold; otherwise the choice is a one-line note in design.md:
     1. not already decided by the constitution, the spec or an earlier ADR (applying a rule is compliance, not a decision);
     2. cross-cutting: package or context boundary, aggregate boundary, a contract others depend on, a persisted format, a library or technology the repository adopts;
     3. costly to reverse: data migration, broken contract, or more than the module rewritten;
     4. genuinely open: a competent engineer could have chosen otherwise, with different consequences. -->
# ADR-<NNNN> — <decision in one line>

- **Status:** Accepted | Superseded by ADR-<NNNN>
- **Date:** <YYYY-MM-DD>
- **Issue / PR:** #<issue> · #<pr>
- **Module:** <domain>/<module>
- **Rules cited:** <constitution rule IDs, if the decision exists because of one>

## Context

<the forces: which requirement IDs, constraints or rules make a choice necessary; two to five sentences>

## Decision

<what was chosen, stated in the present tense; cite requirement IDs>

## Alternatives considered

- <alternative> — <why it lost>

## Consequences

- <what becomes easier, harder, or must be revisited>

<!-- An ADR states a decision that is in force (or superseded). It never narrates how the document got here: git is the history. -->
