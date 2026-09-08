# Gate · security

**Question:** can the implementation be abused, bypassed, or made to expose protected data? Think as an attacker holding a valid session who wants another customer's data, an anonymous caller probing entry points, and a malicious payload arriving on a queue.

## Procedure

1. Read the constitution's security, tenancy and error rules; the Spec; the Design. Note every entry point the Design declares (routes, procedures, consumers, jobs, IPC channels, CLI commands).
2. Read the diff, then every changed entry point, adapter and wiring file in full. Follow each new input from the boundary to storage and back.
3. Walk the checklist. Describe the concrete attack, not the category.

## Checklist

### 1. Authentication and authorization per entry point — BLOCKER
- Every new or changed entry point declares its authorization level (the levels the constitution or the project's auth layer names). No level, or public access without a Spec requirement calling for it, is BLOCKER.
- Object-level authorization: an id supplied by the caller is only usable inside the caller's scope. Identity, role or scope identifiers taken from the request body, query or headers instead of the verified session are BLOCKER (privilege escalation).
- Clients (browser, desktop renderer, mobile) are untrusted; only the server-side session counts.

### 2. Isolation boundary — BLOCKER when the system has one (tenant, organization, workspace)
- Unscoped reads, lists, updates or deletes in a scoped adapter (missing predicate, key prefix or partition), in raw queries, ORM calls, key construction and search alike.
- The boundary key passed as a method parameter or read from request input instead of the verified principal; scoped adapters kept in module-level variables, singletons or caches across requests; the key missing from a new table, index, unique constraint or storage key; events or views carrying another scope's data; consumers not re-resolving the scope from the message envelope.

### 3. Input validation at entry points — BLOCKER
- Every boundary validates before building a command: unbounded strings and arrays, missing enum constraints, unchecked numeric ranges, dates not parsed. File uploads: type, size and name validated; content never executed or rendered raw.

### 4. Injection — BLOCKER
- Queries built by concatenation or interpolation with request data; command execution, file paths or URLs built from request data (traversal, SSRF); untrusted content interpolated into HTML, templates, email or headers; untrusted content placed into an LLM prompt without delimiting, or model output executed as an instruction.

### 5. Secrets — BLOCKER
- Hardcoded keys, tokens, passwords, connection strings; credential files added; secrets in URLs, logs, error messages, fixtures or CI files; secrets read outside the wiring layer the constitution designates.

### 6. Insecure defaults — BLOCKER unless the Spec requires it
- Permissive CORS, disabled TLS verification, debug modes on production paths, default credentials, non-cryptographic randomness for ids or tokens, home-made crypto, missing rate limiting on public entry points, unlimited pagination.

### 7. Sensitive data in logs and errors — BLOCKER for credentials and personal data, WARNING otherwise
- Tokens, passwords, personal data, full request bodies or stack traces logged or returned to the caller; unexpected errors exposing driver, query or path detail instead of the generic wrapper.

### 8. Dependencies — WARNING, report only
- New or upgraded dependencies: name, version, why. Flag known-vulnerable or unmaintained versions and additions outside the project's dependency policy. Do not run audit tooling; CI owns that.

## Output

```yaml
gate: security
issue: <issue number>
pr: <pr number>
commit: <head sha of the PR>
status: PASS | FAIL | NEEDS_HUMAN | BLOCKED
rework_cycle: <integer>
requirements: {}               # optional for this gate
findings:
  - severity: BLOCKER | WARNING | NIT
    location: <path>:<line>
    description: >
      The concrete attack: who, with what access, obtains or does what.
    required_action: The concrete change that removes the attack path.
evidence:
  - <every entry point, adapter and wiring file you inspected>
```

`NEEDS_HUMAN` when a finding depends on deployment configuration you cannot see (gateway, WAF, network policy).
