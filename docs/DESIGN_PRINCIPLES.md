English | [繁體中文](DESIGN_PRINCIPLES.zh-TW.md)

# Beat Design Principles

This document explains *why* Beat works the way it does. Each section states a principle, what we chose instead, and what that trade-off costs. Consult it when evaluating changes that affect multiple skills or the overall direction.

## Audience

This document is for Beat contributors and power users who want to understand the reasoning behind design decisions. If you're new to Beat, start with the [README](../README.md).

---

## Behavior Over Implementation

Gherkin scenarios describe **what the system does**, not how.

```gherkin
# Good — stable across refactors
Scenario: Monthly billing adjusts for short months

# Bad — breaks when you rename the function
Scenario: calculateNextTransactionDate clamps to last day of month
```

**What we rejected:** Internal implementation details in Gherkin — method signatures, database column names, internal config constants. These couple specs to implementation and break on every refactor.

**What belongs in scenarios:** Observable behavior details — HTTP status codes, response field names, business rule thresholds ("locked after 5 attempts"), user-visible messages. These are the behavior, not implementation leaking through. Scenarios should be specific about *what the system does* (see [feature-writing conventions](../references/feature-writing.md)).

**Trade-off:** Scenarios don't explain *how* something works internally. A developer still needs to read the code or `design.md` for that. We accept this because specs that survive refactors are worth more than specs that document every implementation detail.

## Gherkin as Thinking Tool

The value of writing Gherkin is in **forcing you to articulate behavior before coding**. The `.feature` files are a byproduct of good thinking, not an end goal.

**What we rejected:** Mandatory Gherkin for every change. Purely technical changes (dependency upgrades, tooling, refactoring without behavior change) don't benefit from Gherkin. Forcing it turns thinking into paperwork.

**Trade-off:** Users must judge "does this change have behavior?" That judgment call is sometimes wrong. We accept this because the alternative — Gherkin for everything — trains people to write bad scenarios just to satisfy the pipeline.

## File System as State

All state lives in files: `status.yaml`, artifact documents, directory structure. No database, no external service.

**What we rejected:** A CLI tool with its own database, a web dashboard, integration with project management tools (Jira, Linear, etc.).

**Trade-off:** No centralized view across projects. No real-time collaboration on changes. No automatic notifications. We accept this because file-based state is inspectable (`cat`), debuggable (`git diff`), version-controllable (`git log`), and requires zero infrastructure.

## Forward-Only Pipeline

Phases advance forward only: `new → proposal → gherkin → design → tasks → implement → verify → sync → archive`. You cannot rewind.

**What we rejected:** Bidirectional phase transitions ("go back to design and fix the spec"). This creates ambiguous state — is the implementation stale now? Are the tasks still valid? Which version of the spec was verified?

**Trade-off:** If you discover a spec problem during implementation, you update the artifact in-place and continue forward instead of "going back." This feels unnatural at first. We accept this because forward-only eliminates an entire class of state confusion, and updating an artifact is the same action regardless of which phase you're in.

## Optional is Real

Proposal, design, and tasks are genuinely optional — not "optional but you should always do them."

| Change | Artifacts |
|--------|-----------|
| Fix a typo in error message | `design → gherkin → apply → archive` |
| Add password reset | `design → proposal → gherkin → apply → verify → archive` |
| Payment processing system | `design → proposal → gherkin → design.md → plan → tasks → apply → verify → archive` |

**What we rejected:** A single ceremony level for all changes. Many BDD tools require the full pipeline regardless of scope, which trains users to produce hollow artifacts for small changes.

**Trade-off:** Users must choose their ceremony level. Wrong choices happen — someone skips `plan` on a change that needed it, or writes a proposal for a one-line fix. We accept this because adaptive ceremony builds better judgment over time, while fixed ceremony builds resentment.

## Framework-Agnostic

Beat works with any language, any test framework, any tech stack. Skills describe *what to do* ("write a test for this scenario") and rely on `config.yaml` or auto-detection for *how*.

The annotation convention (`@covered-by`, `@feature`, `@scenario`) uses plain-text comments. No framework dependency, no build step, no AST parsing.

**What we rejected:** Deep integration with specific frameworks (Cucumber step definitions as the only binding, Jest-specific matchers, etc.). This would make Beat powerful for one stack and useless for others.

**Trade-off:** Beat can't leverage framework-specific features (Cucumber's automatic step matching, pytest-bdd's decorator binding). Users in those ecosystems get a simpler annotation system than their framework provides. We accept this because portability across all stacks outweighs power in one stack.

## Independent Verification

`/beat:verify` dispatches a **fresh subagent** with no conversation history. It only sees the artifacts and the code.

**What we rejected:** Having the implementing agent verify its own work. The agent that wrote the code has context bias — it knows what it *intended*, so it's likely to confirm that the code does what was intended rather than what the spec says.

**Trade-off:** Verification is slower (subagent startup, re-reading files) and sometimes catches false positives (the subagent misreads context that would be obvious with history). We accept this because the false negatives from self-verification (missing real gaps) are far more costly than false positives.

## Two Drive Modes

The same pipeline serves two modes:

- **Gherkin-driven** (default): Feature files drive planning, implementation, and verification
- **Proposal-driven** (when gherkin is skipped): Proposal drives planning, risk points drive testing

**What we rejected:** Two separate pipelines. This would double the maintenance surface and create subtle inconsistencies between modes.

**Trade-off:** Skills must check "is this gherkin-driven or proposal-driven?" and branch accordingly, adding conditional logic to several skills. We accept this because one pipeline with a mode switch is simpler to reason about than two parallel pipelines.

---

## Testing Philosophy

### Three Layers, One Principle

| Layer | Purpose | Driven by | Feature binding |
|-------|---------|-----------|-----------------|
| E2E | User journeys end-to-end | `@e2e` scenarios | Step definitions or annotations |
| Behavior | Business logic and rules | `@behavior` scenarios | `@covered-by` / `@scenario` annotations |
| Unit | Technical edge cases | Developer judgment | None |

The principle: **every layer uses the project's own tools**. Beat doesn't introduce test frameworks — it tells the agent what to test and how to link tests back to specs.

### Why Text Annotations, Not Framework Bindings

Most BDD tools use framework-level bindings (Cucumber step definitions, pytest-bdd decorators). Beat uses plain-text comments:

```gherkin
# In .feature — points to test
# @covered-by: src/billing/__tests__/date-calc.test.ts
```

```typescript
// In test — points to feature
// @feature: monthly-billing.feature
// @scenario: Monthly billing adjusts for short months
```

Reasons:
1. **Zero cost** — just comments, no runtime, no build step
2. **Any language** — every language has comments
3. **Machine-checkable** — `/beat:verify` can grep for these
4. **Human-readable** — you see the link without tooling

### Granularity

Scenarios should be at the **behavior level**: a PM, QA engineer, or new team member can understand what the system does without reading code. If only the author understands a scenario, it's too granular.

Unit tests for internal functions don't need Gherkin scenarios. They're implementation details, not specifications.

---

## Pipeline Design

### Why This Order

```
design phase:  [proposal] → gherkin → [design.md]
plan phase:    tasks (with multi-role review)
```

1. **Proposal** answers "why" — without motivation, you build the wrong thing
2. **Gherkin** answers "what" — concrete scenarios force specificity that prose cannot
3. **Design** answers "how" — technical decisions are better when constrained by known behavior
4. **Tasks** answer "in what order" — implementation steps come last because they depend on all of the above

Reversing any pair degrades quality. Writing tasks before knowing behavior produces speculative plans. Writing design before knowing scenarios produces over-engineered architecture.

### Why a Pause Between Design and Plan

Design is creative — defining the problem, exploring behaviors, making technical choices. Plan is structural — decomposing into tasks, reviewing from multiple perspectives, producing a checklist.

The pause between them is intentional. It gives the team a chance to review spec artifacts, challenge assumptions, and align on approach **before** committing to execution.

**What we rejected:** A single "design-and-plan" phase. This works for small changes but collapses two distinct thinking modes (creative exploration vs. structural decomposition) into one, producing worse output for complex changes.

---

## What Beat Is Not

- **Not a test runner** — Beat produces specifications and guides implementation, but doesn't execute tests
- **Not a project management tool** — changes are lightweight containers for thinking, not tickets
- **Not opinionated about architecture** — Beat doesn't care if you use microservices or monoliths
- **Not a replacement for human judgment** — skills guide the agent, the developer decides what's appropriate

---

## Evolving This Document

Update when:
- A design decision affects multiple skills
- Real-world usage reveals an implicit principle that should be explicit
- A principle is found to be wrong or outdated

Changes should be committed with a clear explanation of why the principle was added, modified, or removed.
