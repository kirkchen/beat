# Testing Conventions

Reference for annotation format and e2e test style. Used by `apply` and `verify` skills.

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
