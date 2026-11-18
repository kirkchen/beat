# Testing Conventions

Reference for annotation format and e2e test style. Used by `apply` and `verify` skills.

## Table of Contents

- [Annotation Format](#annotation-format) — @covered-by, @feature, @scenario placement
- [Framework Selection](#framework-selection) — behavior vs e2e framework config
- [E2E Test Style](#e2e-test-style) — matching existing patterns
- [Modifying Existing Features](#modifying-existing-features--orig-backup-mechanism) — .orig backup mechanism
- [Generate vs Update Path](#generate-vs-update-path) — when to update existing tests
- [pytest-bdd Decorator as Annotation](#pytest-bdd-decorator-as-annotation) — @scenario decorator

## Annotation Format

### In .feature files

Annotation is placed between the tag line and the Scenario line:

```gherkin
@behavior @happy-path
# @covered-by: src/services/__tests__/billing.test.ts
Scenario: Monthly billing adjusts for short months
```

```gherkin
@e2e @happy-path
# @covered-by: e2e/tests/login.spec.ts
Scenario: User logs in with valid credentials
```

### In test files

Use the project language's comment syntax:

```typescript
// @feature: monthly-billing.feature
// @scenario: Monthly billing adjusts for short months
```

```python
# @feature: monthly-billing.feature
# @scenario: Monthly billing adjusts for short months
```

## Framework Selection

Beat config supports separate frameworks for each testing layer:

```yaml
testing:
  behavior: vitest      # for @behavior scenarios (unit/integration tests)
  e2e: playwright        # for @e2e scenarios (end-to-end tests)
```

When writing tests, use the framework matching the scenario's tag:
- `@behavior` scenario → use `testing.behavior` (or auto-detect: vitest, jest, pytest, etc.)
- `@e2e` scenario → use `testing.e2e` (or auto-detect: playwright, cypress, etc.)

Legacy: if only `testing.framework` is set, treat it as `testing.behavior`.

## E2E Test Style

E2e tests should follow the project's existing e2e patterns. When no existing patterns:

1. **Discover the e2e framework** — read project config (playwright.config, cypress.config, etc.)
2. **Find existing e2e tests** — use them as style reference (file naming, structure, utilities)
3. **Match conventions** — same directory structure, same assertion style, same setup patterns
4. **If no e2e tests exist** — ask the user which framework to use before creating the first one

### Style Consistency Rules

- File naming: match existing pattern (e.g., `*.spec.ts`, `*.e2e.ts`, `*.test.ts`)
- Test structure: match existing describe/it nesting or test() flat style
- Selectors: match existing strategy (data-testid, role-based, CSS selectors)
- Setup/teardown: use existing helpers and fixtures, don't create parallel patterns
- Assertions: use the same assertion library and style as existing tests

### When No Existing E2E Tests Exist

Do NOT invent a style. Ask the user:
> "No existing e2e tests found. Which e2e framework should I use? (e.g., Playwright, Cypress, etc.)"

Then create the first test following that framework's official conventions.

## Modifying Existing Features — .orig Backup Mechanism

When a change modifies scenarios in an existing `beat/features/` file:

1. **Rename** the original to `.feature.orig` in `beat/features/` (BDD runners ignore non-`.feature` files)
2. **Copy** the original content to `beat/changes/<name>/features/<file>.feature`
3. **Modify** the scenario(s) in the `changes/` copy
4. **Record** the original path in `status.yaml` `gherkin.modified`

This keeps the change self-contained (all latest features in `changes/`) while avoiding BDD runner conflicts (`.orig` is invisible to `*.feature` glob).

### Diff

Compare original vs modified:
```bash
diff beat/features/auth/login.feature.orig \
     beat/changes/add-two-factor/features/login.feature
```

### BDD Runner Feature Paths

Apply dynamically combines paths when running BDD tests:
```bash
# Cucumber.js
npx cucumber-js beat/features beat/changes/<name>/features

# behave
behave beat/features beat/changes/<name>/features
```

`.orig` files are naturally excluded by all runners. No config changes needed.

### Rollback

To abandon a change with modified features:
1. Rename each `.feature.orig` back to `.feature`
2. Delete the change directory

## Generate vs Update Path

When implementing a scenario that has an existing `@covered-by` annotation:

| @covered-by | Test file exists? | Path |
|-------------|-------------------|------|
| Present | Yes | **Update**: read existing test, modify to reflect new scenario steps |
| Present | No | **Generate**: create new test + WARNING (stale annotation) |
| Absent | — | **Generate**: create new test (existing flow) |

The Update path reads the existing test file, identifies the test case matching the scenario, and modifies it to reflect the changed steps. Do NOT create a separate test file for a scenario that already has a tracked test.

## pytest-bdd Decorator as Annotation

For projects using pytest-bdd, the `@scenario` decorator serves as both test binding and Beat annotation. It contains the feature file path and scenario name — equivalent to `# @feature` + `# @scenario` comments.

```python
# The @scenario decorator IS the annotation — no separate # @feature / # @scenario needed
@scenario("beat/changes/add-two-factor/features/login.feature",
          "User logs in with valid credentials")
def test_user_login():
    ...
```

Verify can parse `@scenario` decorator arguments to check traceability.

**Archive path update**: when archive syncs features from `changes/` to `beat/features/`, it must update `@scenario` decorator paths in pytest-bdd test files (e.g., `beat/changes/.../login.feature` → `beat/features/auth/login.feature`).
