# Design — <Module name>

spec: ./spec.md
variant: full | light
status: draft | approved

Pick ONE variant. Delete the other. Sections are optional: keep only what applies.

---

## Variant A — Full (DDD)

Use when the change touches the domain model, aggregates, use cases, or context boundaries.

### Bounded Context
<which context owns this; what it does NOT own; how it talks to other contexts (events only)>

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
One per row of the spec's "Rejections" table, same name. Extra errors (invariants not visible to the user) are listed too.
| Error | Rejection (spec) | Thrown when | Maps to (transport) |
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

### Changes
- **New:** <…>
- **Modified:** <…>
- **Removed:** <…>

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
