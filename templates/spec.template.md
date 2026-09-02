# <Module name>

module-id: <MODULE>          ← prefix for requirement IDs, e.g. OT
domain: <domain>
status: draft | approved

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

## Edge cases

- <boundary, empty, duplicate, concurrent, out-of-order…> → <expected behavior, referencing a requirement ID>

## Acceptance criteria

- [ ] <MODULE>-001: <observable check>
- [ ] <MODULE>-002: <observable check>

## Inputs and outputs

<only if the requirement itself is about a contract: payloads, events, files>

## Open questions

- <anything unresolved blocks Approval Gate 1>
