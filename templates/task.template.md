<!-- sdd:task -->
<!-- Exactly one Task comment per Issue. Edit this comment on rework; never post a second one.
     Approval = tracker state `task-approved` (human). Progress = tick the checkboxes.
     The Task is an execution plan and nothing else: the order of work. Every decision lives in the
     design; every rule lives in the constitution; the definition of done lives in the implementation
     skill. If the design leaves something open that the plan needs, the Task does not decide it:
     the issue goes back to `design`. -->

## Task — <short title>

**Issue type:** Feature | Change | Bug | Task | Constitution
**Spec:** `docs/<domain>/<module>/spec.md` → <MODULE>-001, <MODULE>-003
**Design:** `docs/<domain>/<module>/design.md` (or "none" for Task-type issues)
**Constitution:** v<x.y.z>

### Objective

<one paragraph: what will exist when this is done, as observable outcome>

### Steps

Ordered so that every step leaves the build green; each step names the design element it realizes and the requirement IDs it covers.

- [ ] **T1** — <step> (<design element>; <MODULE>-NNN)
- [ ] **T2** — <step>
- [ ] **T3** — <step>
