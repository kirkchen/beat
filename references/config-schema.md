# config.yaml Schema

Single source of truth for the `beat/config.yaml` format.

**Every skill that creates artifacts MUST read this config (if it exists) and apply it.**

## Full Schema

```yaml
language: zh-TW                      # optional, BCP 47 tag (e.g. en, zh-TW, ja)

context: |                           # optional, string (max 50KB)
  [Project context injected into all artifact generation]

testing:                             # optional, map
  required: true                     # optional, boolean (default: true)
  framework: vitest                  # optional, string (auto-detected if omitted)

rules:                               # optional, map
  proposal:                          # optional, array of strings
    - [Rule applied when creating proposals]
  gherkin:                           # optional, array of strings
    - [Rule applied when creating feature files]
  design:                            # optional, array of strings
    - [Rule applied when creating design docs]
  tasks:                             # optional, array of strings
    - [Rule applied when creating task lists]
```

## Fields

### `language`

BCP 47 language tag controlling the output language of **all** artifacts. Common values: `en`, `zh-TW`, `zh-CN`, `ja`. When set, all skills produce artifacts (proposals, features, designs, tasks) in this language. Gherkin keywords follow the language's Cucumber translation when available.

If not set, skills default to English.

### `context`

Free-form project background injected into **every** artifact generation prompt. Typical contents: tech stack, testing framework, language preferences, architectural constraints.

**Hard limit: 50KB.** If exceeded, warn and ignore.

### `testing`

Controls how `/beat:apply` and `/beat:verify` handle automated tests. The entire field is optional — if omitted, skills default to requiring tests (existing behavior).

**`testing.required`** (boolean, default: `true`): When `false`, `/beat:apply` does not enforce TDD cycles and `/beat:verify` skips test existence checks in Dimension 1. Implementation code is still written; only the test mandate is relaxed.

**`testing.framework`** (string, optional): The test framework to use (e.g. `vitest`, `jest`, `pytest`, `go test`). If omitted, `/beat:apply` auto-detects from the codebase. If set, apply uses this framework directly without detection.

Skills that consume `testing`:
- `/beat:apply` — checks `testing.required` and `testing.framework` before TDD cycles
- `/beat:verify` — checks `testing.required` to decide whether Dimension 1 includes test existence checks
- `/beat:setup` — asks users about testing preferences and writes this field

**Interaction with `@no-test` scenario tag:** The `@no-test` Gherkin tag overrides `testing.required` at the scenario level. Even when `testing.required: true`, scenarios tagged `@no-test` are excluded from TDD and coverage checks. When `testing.required: false`, `@no-test` has no additional effect.

### `rules`

Per-artifact rules applied **additively** to skill instructions. Keys must match artifact IDs: `proposal`, `gherkin`, `design`, `tasks`. Unknown keys are ignored with a warning.

Rules are constraints, not templates — they tell the agent what to enforce, not how to structure the output.

## How Skills Consume Config

Insert this step **before creating any artifact**:

1. Check if `beat/config.yaml` exists
2. If yes, read and parse it
3. Use `language` (if present) as the output language for the artifact
4. Inject `context` (if present) as project background when generating the artifact
5. Apply matching `rules` (if present) as additional constraints for the artifact being created
6. Check `testing` (if present) to determine test requirements for apply/verify
7. If config doesn't exist, proceed normally — config is always optional

## Examples

### Minimal config
```yaml
language: zh-TW
```

### Context only
```yaml
context: |
  TypeScript monorepo using Vitest for testing.
```

### No-test project
```yaml
language: zh-TW

testing:
  required: false
```

### Full config
```yaml
language: zh-TW

context: |
  Tech stack: TypeScript, React, PostgreSQL
  Testing: Vitest + React Testing Library
  Architecture: Feature-sliced design

testing:
  framework: vitest

rules:
  proposal:
    - Include rollback plan
    - Identify affected microservices
  gherkin:
    - Each scenario must be independently executable
    - Use data tables for parameterized examples
  design:
    - Include sequence diagrams for async flows
    - Reference existing modules by file path
  tasks:
    - Each task should map to exactly one scenario
    - Estimate complexity as S/M/L
```

## Rules

1. **Config is always optional** — skills must work without it
2. **Never write to config** — only `/beat:setup` creates it, users edit it manually
3. **Context is injected, not stored** — don't copy context into artifacts, use it to inform generation
4. **Rules are additive** — they supplement skill instructions, never override them
5. **Fail gracefully** — if config is malformed, warn and proceed without it
6. **Testing defaults to required** — if `testing` is absent, skills behave as if `testing.required: true`
