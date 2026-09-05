# @sdd-factory/core

The rules of the SDD factory that every orchestrator must share: the embedded worker and the
control plane decide with this code, so they can never disagree.

Admission rule: pure functions and types only. No network, no disk, no `gh`, no agent SDK, no AWS.
Anything that needs I/O lives in the worker or in the control plane.

| Module | Holds |
| --- | --- |
| `types` | Issue types, SDD states, phases, gates, sizes, tiers, `IssueSnapshot` |
| `decide` | The state machine: from a snapshot to phases to run, an approval or a merge |
| `intelligence` | Tier floors, automatic raises, tier per size |
| `config` | Parser of `.sdd/config.json` and of the legacy constitution line |
| `phases` | Skill name, time budget and allowed tools per phase |
| `artifacts` | Cleanliness checks on spec, design and phase summaries |
| `ledger` | Time-and-cost tables for the issue comment and the PR line |
| `waiting` | Which human decision an issue waits for |
| `markers` | HTML markers of the mechanical comments |
| `protocol` | Worker ↔ control-plane messages: registration, heartbeat, lease, result, push events |
| `scheduling` | Priority, worker eligibility, next job, leases and retries |
| `approvals` | Whether a `*-approved` label event counts as a human approval |
