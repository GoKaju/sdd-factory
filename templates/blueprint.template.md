# Blueprint — <project name>

How a module of this repository is built. The constitution holds the rules; this file holds the conventions: where each kind of element lives, what it is named, what it extends or looks like, what its test looks like. Each row is a **written convention** on its own (Location, File name, Extends / shape). The **Exemplar** is optional: when a real file in the repository already follows the row, name it, and agents copy it; write `—` when there is none yet, and agents follow the written convention. The design names a file only when this blueprint does not determine it (`per blueprint` otherwise). Not following the blueprint is a WARNING; breaking a constitution rule is a BLOCKER.

<!-- Keep it to one screen. No prose rules: when something must never happen, it is a constitution rule.
     Write the convention of every row even without code; add an exemplar when one exists (a later Constitution issue can
     add it once the first element of that kind is merged). A filled example for DDD / TypeScript is in templates/examples/. -->

## Module layout

```text
<root of a module, e.g. src/<module>/>
├── <folder>/            ← <what lives here>
└── <folder>/            ← <what lives here>
```

## Kinds

The vocabulary the design's Components table uses. One row per kind of element the code has.

| Kind | Location | File name | Extends / shape | Exemplar |
| --- | --- | --- | --- | --- |
| <kind> | `<folder pattern>` | `<name pattern>` | <base class, interface or "plain"> | `<path/to/real/file>` · — |

## Tests

| Kind of test | Location | Exemplar |
| --- | --- | --- |
| <unit of the core> | `<pattern>` | `<path/to/real/test>` · — |
