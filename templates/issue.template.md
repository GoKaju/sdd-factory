# Issue forms

GitHub issue forms, one per native Issue Type, in two languages:

```
templates/issue-forms/
├── en/   feature.yml · change.yml · bug.yml · task.yml · config.yml
└── es/   feature.yml · change.yml · bug.yml · task.yml · config.yml
```

`sdd-init` reads **`Language`** from the constitution's Identity section (`en` or `es`) and copies
that set into `.github/ISSUE_TEMPLATE/`. The forms are written for **non-technical authors**: the
questions are about the problem, the expected outcome and concrete examples, never about
implementation. The `type:` key of each form assigns the organization's native Issue Type on
creation; the form's `name:` is the label the author sees in the chooser and is translated.

`Feature`, `Bug` and `Task` exist by default in an organization; `Change` and `Constitution` are
created by `sdd-init` (organization admin and `admin:org` scope required).

A `Constitution` Issue has no form: it is opened by hand, typed `Constitution`, and describes the
amendment and its motivation. It is the only Issue type allowed to edit `docs/constitution.md`.

Triage and Task comments are written in the same `Language`, per rule C4 of the constitution.
