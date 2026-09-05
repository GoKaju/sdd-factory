# Design — <Module name>

spec: ./spec.md
variant: full | light
status: draft | approved   ← flipped to approved by the next phase when the human sets design-approved

Pick ONE variant. Delete the other. Sections are optional: keep only what applies.

<!-- A Design records DECISIONS specific to this module. It never restates rules that already live in
     docs/constitution.md; when a decision exists because of a rule, cite the rule ID in parentheses
     ("Today enters through the Clock port (D5)"). Every element must trace to requirement IDs. -->

---

## Variant A — Full (DDD)

Use when the change touches the domain model, aggregates, use cases, or context boundaries.

### Bounded Context
Three lines, no more:
- **Context:** `<name>` — owns <aggregates>.
- **Relations:** <none | consumes/publishes which events with which contexts>.
- **Multi-tenant:** <yes | no>. (How isolation is implemented is the constitution's T rules; do not restate them.)

### Domain Model

#### Aggregates
| Aggregate | Identity | Invariants enforced | Events recorded |
| --- | --- | --- | --- |

#### Entities
#### Value Objects
| VO | Validates | Optional? (`fromOptional`) |
| --- | --- | --- |

#### Domain Services
#### Domain Events
| Event | Emitted when | Payload | Consumers |
| --- | --- | --- | --- |

#### Domain Errors
One per row of the spec's "Rejections" table, same name. Messages in **English**; the client shows and translates the spec's user message. Context values go in params, not in the message. Extra errors (invariants not visible to the user) are listed too.
| Error | Rejection (spec) | Thrown when | Params |
| --- | --- | --- | --- |

### Application

#### Use Cases
| Use case | Command / Query | Returns | Requirements covered |
| --- | --- | --- | --- |

#### Ports
| Port | Kind (repository / read repository / publisher / …) | Fake |
| --- | --- | --- |

### Infrastructure

#### Persistence
<tables / keys / indexes; tenant key placement; migrations>

#### Adapters
| Port | Implementation | Runtime |
| --- | --- | --- |

#### External services

### Interface

#### API / RPC
| Procedure | Auth level | Input schema | Output view |
| --- | --- | --- | --- |

#### Events published / consumed

### Layout
The placement decisions specific to this module, and **every file-level name the naming rules do not determine** (e.g. "domain grouped by aggregate: `domain/task/`, `domain/task-list/`, `domain/shared/`"; "one mapper per direction: `task-record-mapper.ts`, `task-view-mapper.ts`"; "contract test suite `src/testing/task-view-repository-contract.ts`, excluded from coverage, applied by every adapter test"). No exhaustive inventory of files whose names follow from the rules.

### Decisions
<!-- one line per ADR this design relies on; the decision itself lives in docs/adrs/ -->
- [ADR-<NNNN>](../../adrs/<NNNN>-<slug>.md) — <decision in one line>

---

## Variant B — Light

Use for reporting, integrations, tooling, or changes with no domain-model impact.

### Change summary
<what changes technically, in one paragraph>

### Affected components
| Component | Change | Requirements covered |
| --- | --- | --- |

### Contracts touched
<API, events, schemas, files — or "none">

### Decisions
<!-- one line per ADR this design relies on; the decision itself lives in docs/adrs/ -->
- [ADR-<NNNN>](../../adrs/<NNNN>-<slug>.md) — <decision in one line>
