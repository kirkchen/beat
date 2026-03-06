# Granularity-Aware Testing Architecture

## Problem

Beat's current pipeline treats Gherkin as the single source of truth and requires every scenario to have a corresponding test. In practice:

1. **Gherkin written at function level** (e.g., "generateHmacSignature returns hex") adds ceremony without communication value
2. **Unit tests don't map 1:1 to scenarios** — one behavior scenario expands to many edge-case tests
3. **Purely technical changes** (setup tooling, upgrade deps, refactor) don't benefit from Gherkin at all
4. **No formal binding** between .feature files and test code — features become stale documentation

## Design

### Three-Layer Testing Architecture

```
Layer 1: E2E Tests
  Runner:   project's e2e framework (Playwright, Cypress, Selenium, etc.)
  Features: @e2e tagged scenarios
  Binding:  step definitions (if BDD runner available) or annotation-based

Layer 2: Behavior Tests
  Runner:   project's test framework (Vitest, Jest, pytest, RSpec, Go test, etc.)
  Features: @behavior tagged scenarios
  Binding:  annotation-based (@covered-by in feature, @scenario in test)

Layer 3: Unit Tests
  Runner:   project's test framework
  Features: none (driven by proposal risk points / developer judgment)
  Binding:  none
```

### Annotation Conventions

#### In .feature files: `@covered-by`

```gherkin
@behavior
Scenario: Monthly billing adjusts for short months
  # @covered-by: src/app/services/__tests__/date-calculation.test.ts
  Given the member's billing day is 31
  And the next billing falls in February
  When the system calculates next_transaction_at
  Then the billing date should be the last day of February
```

- Placed as a Gherkin comment (# line) immediately after the Scenario line
- Points to the test file that covers this behavior
- Machine-parseable by verify skill
- Multiple `@covered-by` annotations allowed for scenarios covered by multiple test files

#### In test files: `@feature` and `@scenario`

Use the project language's comment syntax (`//`, `#`, `--`, etc.):

```
@feature: monthly-billing.feature
@scenario: Monthly billing adjusts for short months
```

Example (TypeScript):
```typescript
// @feature: monthly-billing.feature
// @scenario: Monthly billing adjusts for short months
describe("Monthly billing adjusts for short months", () => { ... });
```

Example (Python):
```python
# @feature: monthly-billing.feature
# @scenario: Monthly billing adjusts for short months
class TestMonthlyBilling:
    def test_billing_day_31_in_leap_year_feb(self): ...
```

- Placed as comments before the test block
- `@feature` references the .feature filename
- `@scenario` references the exact scenario name
- Enables bidirectional traceability (feature -> test AND test -> feature)

### Scenario Tags

| Tag | Meaning | Test Layer | Binding |
|-----|---------|------------|---------|
| `@e2e` | User journey, needs running app | Project's e2e framework | Step definitions (if BDD runner) or annotations |
| `@behavior` | Business logic/rules, no full app needed | Project's test framework | Annotations (convention) |
| (no tag) | Existing tags (@happy-path, @edge-case) still apply | Determined by @e2e/@behavior | - |

- `@e2e` and `@behavior` can coexist with other tags: `@e2e @happy-path`
- If neither `@e2e` nor `@behavior` is present, default to `@behavior`

### Gherkin Granularity Guidance

#### Write (behavior level)

```gherkin
# Good: describes WHAT the system does
Scenario: Monthly billing adjusts for short months
Scenario: Duplicate transactions are prevented within the same month
Scenario: API request signatures are tamper-proof
```

#### Don't write (function level)

```gherkin
# Bad: describes HOW a function works
Scenario: generateHmacSignature returns lowercase hex
Scenario: isSameMonth returns false for cross-year dates
Scenario: billingCycleSchema rejects times > 12
```

#### When to skip Gherkin entirely

Gherkin can be skipped (`status: skipped`) when the change is purely technical:
- Setting up test infrastructure (e.g., "add test framework")
- Upgrading dependencies
- Refactoring file structure without behavior change
- CI/CD configuration

When skipped, proposal.md becomes the primary driver for apply (proposal-driven testing).

### Verify Behavior

#### When Gherkin exists

**Dimension 1 — Gherkin Coverage** adapts by tag:

For `@e2e` scenarios:
- Check that e2e test or step definitions exist
- If BDD runner: check for step definitions binding to .feature
- If not: check for `@covered-by` annotation (same as `@behavior`)
- Missing test -> CRITICAL

For `@behavior` scenarios:
- Parse `@covered-by` annotation
- Check that the referenced test file exists
- Check that the test file contains a matching `@scenario` annotation or describe block name
- Missing `@covered-by` -> WARNING
- `@covered-by` pointing to nonexistent file -> CRITICAL
- File exists but no matching describe/scenario -> WARNING

**Dimension 2 — Proposal Alignment** (unchanged)

**Dimension 3 — Design Adherence** (unchanged)

#### When Gherkin is skipped

- Skip Dimension 1 entirely
- Strengthen Dimension 2: check that every risk point and success criterion in proposal.md has corresponding test coverage
- Dimension 3 unchanged

### Apply Behavior

#### When Gherkin exists

Apply processes scenarios by tag:

1. **@e2e scenarios**: Generate e2e tests or step definitions using the project's e2e framework
2. **@behavior scenarios**: Generate test files with `@feature`/`@scenario` annotations (in the project's test framework), then update the .feature file with `@covered-by` annotation
3. **Additional unit tests**: After all scenarios are covered, read proposal.md for risk points and generate additional unit tests for technical edge cases (Layer 3)

#### When Gherkin is skipped (proposal-driven)

1. Read proposal.md success criteria and risk points
2. Generate unit tests covering each identified risk
3. No annotation conventions needed (no features to link to)

### Sync Behavior

- `@e2e` and `@behavior` scenarios: sync to `beat/features/` as before
- When gherkin is `skipped`: skip sync (no features to sync), inform user

## Impact on Existing Files

| File | Change |
|------|--------|
| `references/status-schema.md` | Allow `gherkin: { status: skipped }` for technical changes |
| `skills/continue/SKILL.md` | Add granularity guidance, @e2e/@behavior tags, skip option for technical changes |
| `skills/ff/SKILL.md` | Align gherkin creation with continue changes |
| `skills/apply/SKILL.md` | Two-layer testing, proposal-driven mode, annotation generation |
| `skills/verify/SKILL.md` | Annotation-based coverage checking |
| `skills/sync/SKILL.md` | Handle gherkin skipped gracefully |
| `CLAUDE.md` | Document testing architecture |

## Non-Goals

- Not prescribing specific test frameworks — Beat is framework-agnostic, uses `testing.framework` from config or auto-detects
- Not changing how `@no-test` tag works (still skips TDD for individual scenarios)
- Not changing proposal, design, or tasks artifact formats
