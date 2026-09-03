<!-- sdd:task -->
<!-- Exactly one Task comment per Issue. Edit this comment on rework; never post a second one.
     Approval = tracker state `task-approved` (human). Progress = tick the checkboxes below.
     The Task contains ONLY what constitution, spec and design do not already say: the order of work,
     the decisions the design left open, the tests that cannot be derived, and issue-specific constraints.
     No file inventory (the design's Layout fixes where things live), no restated rules, no verification
     commands (the constitution's Commands section is the verification). -->

## Task — <short title>

**Issue type:** Feature | Change | Bug | Task | Constitution
**Spec:** `docs/<domain>/<module>/spec.md` → <MODULE>-001, <MODULE>-003
**Design:** `docs/<domain>/<module>/design.md` (or "none" for Task-type issues)
**Constitution:** v<x.y.z>

### Objective

<one paragraph: what will exist when this is done, as observable outcome>

### Steps

Ordered so that every step leaves the build green. Each step names the design element it realizes and the requirement IDs it covers.

- [ ] **T1** — <step> (<design element>; <MODULE>-NNN)
- [ ] **T2** — <step>
- [ ] **T3** — <step>

### Decisions the design left open

- <e.g. file names the design did not fix, a default the spec allows either way> — or "none"

### Tests not derivable from spec, design or constitution

- <e.g. a shared contract suite that every adapter of a port must pass> — or "none"

### Definition of done

- [ ] Every step above ticked
- [ ] Deterministic checks green (constitution → Commands)
- [ ] All Review Gates PASS
- [ ] No edit to spec, design or constitution (or: escalated as Change #<n>)

### Constraints specific to this issue

- <only what does not follow from constitution, spec or design; e.g. "no real clock adapter in this feature"> — or "none"
