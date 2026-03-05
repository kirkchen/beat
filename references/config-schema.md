# config.yaml Schema

Single source of truth for the `beat/config.yaml` format.

**Every skill that creates artifacts MUST read this config (if it exists) and apply it.**

## Full Schema

```yaml
context: |                           # optional, string (max 50KB)
  [Project context injected into all artifact generation]

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

### `context`

Free-form project background injected into **every** artifact generation prompt. Typical contents: tech stack, testing framework, language preferences, architectural constraints.

**Hard limit: 50KB.** If exceeded, warn and ignore.

### `rules`

Per-artifact rules applied **additively** to skill instructions. Keys must match artifact IDs: `proposal`, `gherkin`, `design`, `tasks`. Unknown keys are ignored with a warning.

Rules are constraints, not templates — they tell the agent what to enforce, not how to structure the output.

## How Skills Consume Config

Insert this step **before creating any artifact**:

1. Check if `beat/config.yaml` exists
2. If yes, read and parse it
3. Inject `context` (if present) as project background when generating the artifact
4. Apply matching `rules` (if present) as additional constraints for the artifact being created
5. If config doesn't exist, proceed normally — config is always optional

## Examples

### Minimal config
```yaml
context: |
  TypeScript monorepo using Vitest for testing.
```

### Full config
```yaml
context: |
  Tech stack: TypeScript, React, PostgreSQL
  Testing: Vitest + React Testing Library
  Language: English for code and docs
  Architecture: Feature-sliced design

rules:
  proposal:
    - Include rollback plan
    - Identify affected microservices
  gherkin:
    - Write scenarios in English
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
2. **Never write to config** — only `/beat:init` creates it, users edit it manually
3. **Context is injected, not stored** — don't copy context into artifacts, use it to inform generation
4. **Rules are additive** — they supplement skill instructions, never override them
5. **Fail gracefully** — if config is malformed, warn and proceed without it
