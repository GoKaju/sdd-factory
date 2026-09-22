<!-- sdd:task -->
<!-- Exactly one Task comment per Issue. Edit this comment on rework; never post a second one.
     Approval = tracker state `plan-approved` (human), together with the spec and design. Progress = tick the checkboxes.
     The Task is an execution plan and nothing else: the order of work. Every decision lives in the
     design; every rule lives in the constitution; the definition of done lives in the implementation
     skill. If the plan needs something the design does not fix, the design is amended first. -->

## Task — <short title>

**Issue type:** Feature | Change | Bug | Task | Constitution
**Spec:** `docs/<domain>/<module>/spec.md` → <MODULE>-001, <MODULE>-003
**Design:** `docs/<domain>/<module>/design.md` (or "none" for Bug, Task and Constitution issues)

### Objective

<one paragraph: what will exist when this is done, as observable outcome>

### Steps

Ordered so that every step leaves the build green; each step names, by its exact name, the design element it realizes (a row of Components, an Error or a Contract) and the requirement IDs it covers.

- [ ] **T1** — <step> (<design element>; <MODULE>-NNN)
- [ ] **T2** — <step>
- [ ] **T3** — <step>
