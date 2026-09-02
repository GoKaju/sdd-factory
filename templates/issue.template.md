# Issue templates

Four GitHub issue forms, one per native Issue Type. `sdd-init` writes them to
`.github/ISSUE_TEMPLATE/`. The `type:` key assigns the organization's Issue Type on creation;
the SDD state is a label the pipeline manages (`sdd:triage` is applied by the first triage run).
Issue Types `Feature`, `Bug`, `Task` exist by default in an organization; `Change` and
`Constitution` are created by `sdd-init` (organization admin required).

---

## `feature.yml`

```yaml
name: Feature
description: New behavior the system does not have yet
type: Feature
title: "feat: "
body:
  - type: textarea
    id: problem
    attributes: { label: Problem / motivation, description: Why this is needed and who benefits }
    validations: { required: true }
  - type: textarea
    id: outcome
    attributes: { label: Requested outcome, description: Observable behavior once done }
    validations: { required: true }
  - type: textarea
    id: acceptance
    attributes: { label: Acceptance hints, description: Examples of expected, rejected and edge behavior, placeholder: "- when … then …" }
    validations: { required: true }
  - type: textarea
    id: context
    attributes: { label: Dependencies / context, description: Related issues, constraints, deadlines }
```

## `change.yml`

```yaml
name: Change
description: Modify behavior the system already has
type: Change
title: "change: "
body:
  - type: input
    id: module
    attributes: { label: Domain / module, placeholder: payroll/overtime }
    validations: { required: true }
  - type: input
    id: requirements
    attributes: { label: Affected requirements, placeholder: "OT-002, OT-003" }
  - type: textarea
    id: current
    attributes: { label: Current behavior, description: What the Spec says today }
    validations: { required: true }
  - type: textarea
    id: requested
    attributes: { label: Requested behavior, description: What it should say instead, and why }
    validations: { required: true }
  - type: textarea
    id: acceptance
    attributes: { label: Acceptance hints }
```

## `bug.yml`

```yaml
name: Bug
description: Behavior differs from the Spec
type: Bug
title: "bug: "
body:
  - type: input
    id: module
    attributes: { label: Domain / module, placeholder: payroll/overtime }
  - type: input
    id: requirement
    attributes: { label: Violated requirement, description: Leave empty if the Spec is silent; triage may reclassify as Change, placeholder: OT-003 }
  - type: textarea
    id: observed
    attributes: { label: Observed, description: Steps, input, actual result }
    validations: { required: true }
  - type: textarea
    id: expected
    attributes: { label: Expected, description: What the Spec requires }
    validations: { required: true }
  - type: textarea
    id: evidence
    attributes: { label: Evidence, description: Logs, failing test, screenshot }
```

## `task.yml`

```yaml
name: Task
description: Maintenance with no behavior change (dependencies, refactor, tooling, docs)
type: Task
title: "chore: "
body:
  - type: input
    id: scope
    attributes: { label: Scope, placeholder: "@libs/ddd-core, CI" }
    validations: { required: true }
  - type: textarea
    id: what
    attributes: { label: What }
    validations: { required: true }
  - type: textarea
    id: why
    attributes: { label: Why }
    validations: { required: true }
  - type: checkboxes
    id: guardrails
    attributes:
      label: Guardrails
      options:
        - label: No observable behavior change. Existing tests stay untouched unless their source is removed.
          required: true
```

## `config.yml`

```yaml
blank_issues_enabled: false
```

> A `Constitution` Issue has no form: it is opened by hand, typed `Constitution`, and describes the
> amendment and its motivation. It is the only Issue type allowed to edit `docs/constitution.md`.
