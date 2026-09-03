# Design — <Module name>

spec: ./spec.md
variant: full | light
status: draft | approved

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
Only the placement decisions that are specific to this module (e.g. "domain grouped by aggregate: `domain/task/`, `domain/task-list/`, `domain/shared/`"; "contract test suite in `src/testing/`, excluded from coverage"). No file inventory and no test list: those belong to the Task ("Files expected to change", "Tests required").

### Changes to existing code
- **Modified:** <existing elements that change, or "none">
- **Removed:** <…, or "none">

### Decisions
| Decision | Alternatives considered | Rationale |
| --- | --- | --- |

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
| Decision | Alternatives considered | Rationale |
| --- | --- | --- |
