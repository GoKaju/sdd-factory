# <Module name>

module-id: <MODULE>          ← prefix for requirement IDs, e.g. OT
domain: <domain>
status: draft | approved   ← flipped to approved by the next phase when the human sets spec-approved

<!-- A Spec describes WHAT the system does, in the language a business reader uses. It never says HOW.
     Does not belong here (it belongs in design.md or in the constitution): tenants and isolation,
     persistence, repositories, views or read models, events and their delivery, idempotency mechanics,
     concurrency control, HTTP/API/frontend, test doubles, class or file names, layer names.
     "Out of scope" lists business capabilities deliberately left out, never deferred technical decisions.
     Rejections are named here (business reason + message); the design maps them to domain errors.
     The spec is the current state of the module: no open questions, decisions or history (they go to the PR description). -->

## Purpose

<one paragraph: what this module is responsible for and for whom>

## Scope

**In scope:** <…>
**Out of scope:** <…>

## Domain concepts

| Term | Meaning |
| --- | --- |
| <Concept> | <definition in business language> |

## Requirements

Every requirement is `### <MODULE>-NNN <short name>`: a stable ID, never reused or renumbered, and a name for the reader. The statement uses EARS where it adds precision; an invariant that always holds is a requirement too (`THE SYSTEM SHALL …`).

```text
WHEN <trigger>, THE SYSTEM SHALL <response>.
IF <condition>, THEN THE SYSTEM SHALL <response>.
WHILE <state>, THE SYSTEM SHALL <response>.
WHERE <feature is enabled>, THE SYSTEM SHALL <behavior>.
```

Every requirement has at least one `#### Scenario:` with a concrete input and its observable outcome. Edge cases (empty, boundary, duplicate, repeated, out of order…) are scenarios of the requirement they affect.

### <MODULE>-001 <short name>
WHEN <…>,
THE SYSTEM SHALL <…>.

#### Scenario: <happy path>
- **WHEN** <concrete input>
- **THEN** <observable outcome>

#### Scenario: <edge case>
- **WHEN** <boundary input>
- **THEN** <observable outcome, or the rejection by name: `<SomethingNotAllowed>`>

## Rejections

One row per business reason the system refuses a request. The name is part of the ubiquitous language (English, PascalCase); the design turns each row into one domain error. Never mention classes, hierarchies or `DomainError` here.

| Name | Condition | Message to the user | Requirement |
| --- | --- | --- | --- |
| `<SomethingNotAllowed>` | <when it happens, in business terms> | <what the user reads> | <MODULE>-NNN |

When one request breaks several rules at once, state which rejection wins (a fixed checking order).
