# Beat Design Principles

This document records the design philosophy and direction of Beat. It is the reference for evaluating changes and resolving design ambiguities.

## What Beat Is

Beat is a **thinking framework**, not a testing tool. It forces structured thinking before coding: what behavior are we changing, why, and how will we verify it? The artifacts (proposal, features, design, tasks) are thinking checkpoints, not bureaucracy.

Beat is a **Claude Code plugin**, not an application. Every skill is a markdown instruction file — no executable code, no runtime, no dependencies. This makes skills easy to write, modify, and reason about.

## Core Beliefs

### Behavior Over Implementation

Beat cares about **what the system does**, not how it does it. Gherkin scenarios describe observable behavior ("monthly billing adjusts for short months"), not internal mechanics ("calculateNextTransactionDate clamps to last day"). This keeps specifications stable across refactors.

### Framework-Agnostic

Beat works with any language, any test framework, any tech stack. Skills never prescribe specific tools — they describe **what to do** (write a test, generate step definitions) and rely on the project's `testing.behavior` and `testing.e2e` config or auto-detection for **how to do it**. Annotation conventions (`@covered-by`, `@feature`, `@scenario`) use plain-text comments that work in any language.

### Gherkin as Thinking Tool, Not Documentation

Gherkin's value is in the **thinking process** — forcing you to articulate behavior before writing code. The .feature files are a byproduct of good thinking, not an end goal. When Gherkin doesn't add thinking value (purely technical changes), it can be skipped.

### File System as State

All state lives in the file system: directory structure, status.yaml, artifact files. No database, no external service, no hidden state. This makes Beat inspectable, debuggable, and version-controllable.

### Optional is Real

Proposal, design, and tasks are genuinely optional — not "optional but you should always do them." A small bug fix should be `new -> gherkin -> apply -> archive`. Ceremony should scale with complexity.

## Testing Philosophy

### Three Layers, One Principle

Tests exist at different granularities, each serving a different purpose:

| Layer | Purpose | Driven by | Binding to features |
|-------|---------|-----------|---------------------|
| E2E | Verify user journeys end-to-end | `@e2e` scenarios | Step definitions (if BDD runner) or annotations |
| Behavior | Verify business logic and rules | `@behavior` scenarios | `@covered-by` / `@scenario` annotations |
| Unit | Cover technical edge cases | Proposal risk points / developer judgment | None |

The principle: **every layer uses the project's own tools**. Beat doesn't introduce test frameworks — it tells the agent what to test and how to link tests back to specifications.

### Annotation Convention

The connection between features and tests is maintained through lightweight text annotations:

- **Feature -> Test**: `# @covered-by: path/to/test` (Gherkin comment in .feature, placed between tag and scenario line)
- **Test -> Feature**: `@feature: file.feature` + `@scenario: name` (code comment in test file)

These annotations are machine-checkable (by verify) but zero-cost (just comments). No framework dependency, no build step, works in any language.

### Granularity Guidance

Gherkin scenarios should be written at the **behavior level** — a level where a PM, QA, or new engineer can understand what the system does without reading code. If only the author understands a scenario, it's too granular.

Unit tests for internal functions don't need Gherkin scenarios. They are implementation details that live alongside the code, not in the specification.

## Pipeline Design

### Why This Order

```
proposal -> gherkin -> design -> tasks
```

1. **Proposal** answers "why" — without motivation, you build the wrong thing
2. **Gherkin** answers "what" — concrete behaviors force specificity that prose can't
3. **Design** answers "how" — technical decisions are better when constrained by known behavior
4. **Tasks** answer "in what order" — implementation steps come last because they depend on all above

### Forward-Only

Phase advances forward only. You can't go back from `design` to `gherkin`. If implementation reveals a spec problem, the right action is to update the artifact and continue forward, not to rewind the pipeline.

### Two Drive Modes

- **Gherkin-driven** (default): feature files are the primary input for apply and verify
- **Proposal-driven** (when gherkin is skipped): proposal becomes the primary input, testing is guided by risk points and success criteria

These are not two separate pipelines — the same pipeline adapts based on whether Gherkin adds value for this specific change.

## What Beat Is Not

- **Not a test runner** — Beat produces specifications and guides implementation, but doesn't execute tests itself
- **Not a project management tool** — changes are lightweight containers for thinking, not tickets
- **Not opinionated about architecture** — Beat doesn't care if you use microservices or monoliths, REST or GraphQL
- **Not a replacement for human judgment** — skills guide the agent, but the developer decides what's appropriate for each change

## Evolution

This document should be updated when:
- A design decision is made that affects multiple skills
- Real-world usage reveals a principle that was implicit but should be explicit
- A principle is found to be wrong or outdated

Changes to this document should be committed with a clear explanation of why the principle was added, modified, or removed.
