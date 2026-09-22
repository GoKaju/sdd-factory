# Gate · risk

**Question:** can this change be abused, or can it break something that already works? Think as an attacker holding a valid session who wants another customer's data, an anonymous caller probing entry points, a malicious payload arriving on a queue — and as the owner of every module that depends on what changed.

## Procedure

1. Read the constitution's security, tenancy and error rules; the Spec; the Design. Note every entry point the Design declares (routes, procedures, consumers, jobs, IPC channels, CLI commands).
2. Read the diff, then every changed entry point, adapter and wiring file in full. Follow each new input from the boundary to storage and back.
3. List every changed package or module and find its dependents: grep the changed exports and package names across the repository. Find related Specs (`docs/*/*/spec.md` naming the same concepts, events or entry points): they define behavior this PR must not alter. Compare every changed public surface with its base-branch version (`git show origin/<base>:<path>`).
4. Walk the checklist. Describe the concrete attack or the concrete breakage, not the category.

## Checklist — security

### 1. Authentication and authorization per entry point — BLOCKER
- Every new or changed entry point declares its authorization level; none, or public access without a Spec requirement calling for it, is BLOCKER.
- Object-level authorization: an id supplied by the caller is usable only inside the caller's scope. Identity, role or scope taken from the request body, query or headers instead of the verified session is BLOCKER. Clients are untrusted; only the server-side session counts.

### 2. Isolation boundary — BLOCKER when the system has one
- Unscoped reads, lists, updates or deletes (missing predicate, key prefix or partition) in adapters, raw queries, ORM calls, key construction and search; the key read from request input; scoped adapters cached across requests; the key missing from a new table, index, unique constraint or storage key; events or views carrying another scope's data; consumers not re-resolving the scope from the message.

### 3. Input and injection — BLOCKER
- Every boundary validates before building a command: unbounded strings and arrays, missing enum constraints, unchecked ranges, unparsed dates; uploads checked for type, size and name and never executed or rendered raw.
- Queries, commands, file paths or URLs built from request data (injection, traversal, SSRF); untrusted content interpolated into HTML, templates, email or headers; untrusted content placed into an LLM prompt without delimiting, or model output executed as an instruction.

### 4. Secrets and insecure defaults — BLOCKER
- Hardcoded keys, tokens, passwords or connection strings; secrets in URLs, logs, errors, fixtures or CI files, or read outside the wiring layer.
- Permissive CORS, disabled TLS verification, debug modes on production paths, default credentials, non-cryptographic randomness for ids or tokens, home-made crypto, missing rate limiting on public entry points, unlimited pagination — unless the Spec requires it.

### 5. Sensitive data — BLOCKER for credentials and personal data, WARNING otherwise
- Tokens, passwords, personal data, full request bodies or stack traces logged or returned to the caller; unexpected errors exposing driver, query or path detail.

### 6. Dependencies — WARNING, report only
- New or upgraded dependencies: name, version, why; known-vulnerable or unmaintained versions; additions outside the project's dependency policy. Do not run audit tooling.

## Checklist — regression

### 7. Dependents and related Specs — BLOCKER when a related Spec's behavior changes
- Every dependent of a changed shared module is still compatible or updated in the same PR. A behavior described in another module's Spec that the diff alters is BLOCKER: that Spec was not approved for change in this Issue.
- A pre-existing test whose assertions, fixtures or setup changed while its requirement did not: BLOCKER (behaviour rules on bypass; here rule on the behavior change).

### 8. Public surface, events and data — BLOCKER unless every consumer is updated in the PR
- Exports removed, renamed or re-typed; command, result or port signatures changed (every adapter and fake updated?); routes or procedures renamed, removed, re-shaped or with a changed authorization level; contract schemas changed on one side only; stricter validation rejecting previously accepted payloads.
- Renamed events, removed or re-typed fields, changed semantics: every consumer located and correct; a new consumer with a non-idempotent side effect under at-least-once delivery; messages in flight at deploy time still deserialize.
- A persisted shape changed without a migration in the PR; destructive migrations without an expand-and-contract plan; rows persisted before the change that no longer load.

### 9. Backwards compatibility — WARNING; BLOCKER for data loss or silent behavior change
- Configuration or environment variables added, renamed or re-defaulted without every runtime's wiring updated; major bumps of shared dependencies; changed defaults, sort orders or page sizes visible to users.

`NEEDS_HUMAN` when a finding depends on deployment configuration or data you cannot inspect (gateway, WAF, network policy, production records).
