# <Module name>

module-id: <MODULE>          ← prefix for requirement IDs, e.g. OT
domain: <domain>
status: draft | approved   ← flipped to approved by the next phase when the human sets spec-approved

<!-- A Spec describes WHAT the system does, in the language a business reader uses. It never says HOW.
     Does not belong here (it belongs in design.md or in the constitution): tenants and isolation,
     persistence, repositories, views or read models, events and their delivery, idempotency mechanics,
     concurrency control, HTTP/API/frontend, test doubles, class or file names, layer names.
     "Out of scope" lists business capabilities deliberately left out, never deferred technical decisions.
     Rejections are named here (business reason + message); the design maps them to domain errors. -->

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

Every requirement has a stable ID `<MODULE>-NNN`. IDs are never reused or renumbered. Use EARS where it adds precision:

```text
WHEN <trigger>, THE SYSTEM SHALL <response>.
IF <condition>, THEN THE SYSTEM SHALL <response>.
WHILE <state>, THE SYSTEM SHALL <response>.
WHERE <feature is enabled>, THE SYSTEM SHALL <behavior>.
```

### <MODULE>-001
WHEN <…>,
THE SYSTEM SHALL <…>.

### <MODULE>-002
IF <…>,
THEN THE SYSTEM SHALL <…>.

## Business rules

- **BR-1:** <invariant that always holds, in business language>

## Rejections

One row per business reason the system refuses a request. The name is part of the ubiquitous language (English, PascalCase); the design turns each row into one domain error. Never mention classes, hierarchies or `DomainError` here.

| Name | Condition | Message to the user | Requirement |
| --- | --- | --- | --- |
| `<SomethingNotAllowed>` | <when it happens, in business terms> | <what the user reads> | <MODULE>-NNN |

When one request breaks several rules at once, state which rejection wins (a fixed checking order).

## Edge cases

- <boundary, empty, duplicate, concurrent, out-of-order…> → <expected behavior, referencing a requirement ID>

## Acceptance criteria

- [ ] <MODULE>-001: <observable check>
- [ ] <MODULE>-002: <observable check>

## Open questions

- <anything unresolved blocks Approval Gate 1>
