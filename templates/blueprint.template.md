# Blueprint — <project name>

How a module of this repository is built, shown by example. The constitution holds the rules; this file holds the conventions a reader learns by looking: where each kind of element lives, what it is named, what it extends, what its test looks like. Every row points to a **real file** in the repository that compiles and passes its tests, so the blueprint cannot drift from the code. Agents build new elements by copying the exemplar of their kind; the design names a file only when this blueprint does not determine it (`per blueprint` otherwise). Not following the blueprint is a WARNING; breaking a constitution rule is a BLOCKER.

<!-- Keep it to one screen. No prose rules: when something must never happen, it is a constitution rule.
     No exemplar yet for a kind? Write "none yet" and fill it with the first issue that creates one (through a
     Constitution issue). A filled example for DDD / TypeScript is in templates/examples/. -->

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
| <kind> | `<folder pattern>` | `<name pattern>` | <base class, interface or "plain"> | `<path/to/real/file>` |

## Tests

| Kind of test | Location | Exemplar |
| --- | --- | --- |
| <unit of the core> | `<pattern>` | `<path/to/real/test>` |
