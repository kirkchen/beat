# Feature File Writing Conventions

Reference for writing Gherkin feature files as living documentation. Used by `design` and `distill` skills when creating feature files.

## Two Readers

Feature files serve two readers simultaneously:
- **Test runner** — scenarios must be executable
- **Team members** — reading the file should be enough to understand the system

## Feature Description Block

The free text between `Feature:` and the first `Scenario:` is the core of living documentation. Gherkin parsers ignore this text, but documentation tools preserve it.

### Minimum (all features)

1. **Overview** — 2-4 lines: what this is, core capabilities, role in the system
2. **As a / I want / So that** — three lines

### Recommended additions (scale to complexity)

Not every feature needs all of these. Add sections as the feature's complexity warrants.

| Section | When to include | What to write |
|---------|----------------|---------------|
| Architecture diagram | Multi-component interaction | ASCII box diagram: components, protocols, data flow direction |
| Data model | Features with DB or typed contracts | Table: field / type / description |
| API endpoints | REST/RPC-facing features | Table: Method / Path / Description |
| Execution flow | Ordered multi-step processing | Numbered steps from trigger to completion |
| Key design decisions | Non-obvious choices | **Bold keyword** + reasoning (record why, not just what) |
| External dependencies | External service calls | Table with failure behavior column (error / degrade / silent) |

> **Domain vocabulary** — do NOT add a per-feature Glossary section. The project-level `beat/CONTEXT.md` is the single source of truth (see `context-format.md`). If a scenario uses a term not in the glossary, `/beat:design` will prompt to add it during the four-challenge check.

### Architecture diagram style

Use ASCII box diagrams with consistent formatting:
- Mark component names and roles
- Arrows indicate protocols or data types
- Mark data flow direction

## Scenario Organization

### 1. Error scenarios nearby

Error scenarios MUST immediately follow the corresponding happy-path, NOT in a separate "Error Handling" section.

```gherkin
# --- Create and Query ---
Scenario: Register a new repo           # happy-path
Scenario: List all registered repos      # happy-path
Scenario: Register duplicate URL         # error - nearby
```

Wrong — error scenarios pulled into separate section:

```gherkin
# --- Create and Query ---
Scenario: Register a new repo
Scenario: List all registered repos
# --- Error Handling ---                  # out of context
Scenario: Register duplicate URL
```

### 2. Order by lifecycle or functional groups

Section order should follow the component's operation sequence or logical grouping. Section titles can reference process steps to establish correspondence.

### 3. No fragmented sections

| Situation | Action |
|-----------|--------|
| Section with 1 scenario | Merge into nearest related section |
| Section with 5+ scenarios | Consider splitting |
| Cross-cutting concerns | May be independent section even with 2-3 scenarios |

## Domain Terms

Project-specific domain terms (Run, Task, Capability, Customer, etc.) referenced in scenario steps should appear in **bold** the first time they're introduced in a scenario, and remain consistent across scenarios. The canonical form is defined in `beat/CONTEXT.md` — every bolded term must exist there.

```gherkin
Scenario: A new **Run** extends the current **Task** when topic stays the same
  Given an active **Task** "billing-cleanup"
  When the user submits a prompt on the same topic
  Then a new **Run** is appended to the **Task** (not a new **Task**)
```

If a scenario needs a term that isn't in `beat/CONTEXT.md` yet, `/beat:design` will prompt to add it inline before the scenario is written. See `context-format.md` for the four-challenge check that maintains the glossary.

## Annotation Conventions

Every `@behavior` scenario needs a `@covered-by` annotation (added after tests are implemented in apply phase). Optional: **Scenario NOTE** for non-obvious test design decisions.

For detailed annotation format and placement rules, see `testing-conventions.md`.

## Language

When `config.yaml` specifies `language`:
- Gherkin keywords follow the language's Cucumber translation (e.g., zh-TW: `功能:` / `場景:` / `假設` / `當` / `那麼`)
- Description blocks, scenario titles, and step text use the configured language
- Technical terms (service names, protocol names, field names) remain in English

No language configured → default to English.

## Review Checklist

When reviewing feature files:

1. [ ] Language declaration matches config; text is consistent throughout
2. [ ] Description includes overview + user story (reader understands the system after reading)
3. [ ] Architecture diagram or data flow diagram present (multi-component features)
4. [ ] Key design decisions record reasoning (why, not just what)
5. [ ] Scenarios are specific — field names, status codes, payload structures
6. [ ] Error scenarios placed near corresponding functional block
7. [ ] No fragmented sections (single-scenario sections merged)
8. [ ] No per-feature Glossary section — domain terms live in `beat/CONTEXT.md`
9. [ ] Bolded domain terms in scenarios are all defined in `beat/CONTEXT.md`
10. [ ] All `@behavior` scenarios have `@covered-by` annotation (after apply)
