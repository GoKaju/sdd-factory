<!-- EXAMPLE: DDD · TypeScript · pnpm workspace. Pairs with templates/examples/constitution.ddd-ts.md.
     The written conventions stand on their own; replace each exemplar with a real file of your repository, or `—` while there is none. -->
# Blueprint — <project name>

How a module of this repository is built. The constitution holds the rules; this file holds the conventions. Each row is a written convention; when it names an exemplar, new elements copy it. The design names a file only when this blueprint does not determine it. Not following the blueprint is a WARNING; breaking a constitution rule is a BLOCKER.

## Module layout

```text
contexts/<context>/src/
├── domain/<aggregate>/        ← aggregate root; subfolders value-objects/, events/, errors/, ports/ once a kind has more than one file
├── use-cases/<use-case>/      ← one folder per use case: command or query, handler, test
└── infrastructure/<technology>/ ← one folder per adapter family, with its mappers/
apps/<app>/                    ← entry points: wiring, HTTP or RPC handlers, translation of domain errors
libs/                          ← shared kernel: base classes, testing utilities
```

No flat folder past five files. Files are kebab-case without type suffixes; named exports only (config files excepted).

## Kinds

| Kind | Location | File name | Extends / shape | Exemplar |
| --- | --- | --- | --- | --- |
| Aggregate | `domain/<aggregate>/` | `<aggregate>.ts` | `AggregateRoot`; `create()` enforces invariants, ids, defaults and records events; `rehydrate()` rebuilds exactly; getters, no serialization | `<path>` |
| Value object | `domain/<aggregate>/value-objects/` | `<name>.ts` | `ValueObject`; immutable, validates on construction, `fromOptional()` for nullable input | `<path>` |
| Domain event | `domain/<aggregate>/events/` | `<name>-<past-verb>.ts` | `DomainEvent` | `<path>` |
| Domain error | `domain/<aggregate>/errors/` | `<name>.ts` | `DomainError`; `name` equals the class name; English message, context in params | `<path>` |
| Port | `domain/<aggregate>/ports/` | `<name>-repository.ts` · `<name>-read-repository.ts` | interface; read repositories return Views | `<path>` |
| Use case | `use-cases/<use-case>/` | `<use-case>.ts` + `<use-case>-command.ts` | plain command or query, no validation library; handler orchestrates | `<path>` |
| Fake | `infrastructure/in-memory/` | `in-memory-<port>.ts` | implements the port; every port ships one | `<path>` |
| Adapter | `infrastructure/<technology>/` | `<technology>-<port>.ts` | implements the port; tenant fixed at construction; mappers in `mappers/` | `<path>` |
| Entry point | `apps/<app>/` | `<procedure>.ts` | validates input, calls the use case, translates domain errors once | `<path>` |

## Tests

| Kind of test | Location | Exemplar |
| --- | --- | --- |
| Domain (aggregate, value object) | next to the file, `*.test.ts` | `<path>` |
| Use case with zero mocks (fakes only) | `use-cases/<use-case>/*.test.ts` | `<path>` |
| Adapter contract + tenant isolation | `infrastructure/<technology>/*.test.ts`, applying the port's shared contract suite | `<path>` |
