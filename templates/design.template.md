# Design — <Module name>

spec: ./spec.md
status: draft | approved   ← flipped to approved by the next phase when the human sets design-approved

<!-- A Design records DECISIONS specific to this module. It never restates rules that already live in
     docs/constitution.md; when a decision exists because of a rule, cite the rule ID in parentheses
     ("Today enters through the Clock port (D5)"). Every element must trace to requirement IDs.
     The design is the current state of the module: what this change touches, leaves out or risks goes to the PR description.
     Sections with nothing to say are written as "none", never deleted. -->

## Boundary

Three lines, no more:
- **Module:** `<name>` — owns <what>.
- **Relations:** <none | which modules it uses or serves, and through what>.
- **Per customer:** <yes | no>. (How isolation is implemented is the constitution's concern; do not restate it.)

## Components

One row per element the code must have, named in the constitution's vocabulary (aggregate, value object, use case, port, adapter, handler… only the kinds the constitution defines). **Location** fixes the file or folder of every element whose placement or file name the constitution's rules do not determine; write `per rules` when they do. The Task and the implement phase never choose a name or a place: they take it from here.

| Component | Kind | Responsibility | Location | Requirements |
| --- | --- | --- | --- | --- |
| `<Name>` | <kind> | <what it does or enforces, one line> | `<path>` · per rules | <MODULE>-NNN |

Design notes: one line each, under the table of the section they belong to (Components, Errors, Contracts), for choices that are not ADRs, citing the requirement or rule they follow.

## Errors

One per row of the spec's "Rejections" table, same name. Messages in **English**; the client shows and translates the spec's user message. Context values go in params, not in the message. Extra errors (invariants not visible to the user) are listed too.

| Error | Rejection (spec) | Raised by | Params |
| --- | --- | --- | --- |

## Contracts

What other modules or clients see: API or RPC procedures, events published or consumed, persisted formats, files. `none` when the module exposes nothing.

| Contract | Kind | Shape | Requirements |
| --- | --- | --- | --- |

## Decisions

<!-- One line per ADR this design relies on; the decision itself lives in docs/adrs/. An ADR only for a decision that is
     not already fixed by a rule, a requirement or an earlier ADR, is cross-cutting, is costly to reverse and was genuinely
     open (see the ADR template). Usually zero or one. Every other choice is a design note in the section it belongs to. -->
- [ADR-<NNNN>](../../adrs/<NNNN>-<slug>.md) — <decision in one line> · or "none"
