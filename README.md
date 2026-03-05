English | [繁體中文](README.zh-TW.md)

# Beat

Think first, code second. Beat is a Claude Code plugin that makes you write [Gherkin](https://cucumber.io/docs/gherkin/) scenarios before touching code — then drives TDD implementation from those specs.

## The Problem

```
You: "Add user login"
Claude: *writes 400 lines, misses rate limiting, 
        tests are an afterthought, edge cases surface in PR review*
```

## With Beat

```
You: /beat:design add-user-login

Beat generates:
┌─────────────────────────────────────────────────┐
│ Feature: User Login                             │
│                                                 │
│   Scenario: Successful login with valid creds   │
│   Scenario: Invalid password shows error        │
│   Scenario: Account locked after 5 attempts     │
│   Scenario: Session expires after 30 min idle   │
│   Scenario: Login from new device sends email   │
└─────────────────────────────────────────────────┘

You: /beat:apply

Beat implements each scenario with TDD:
  ✗ Write test for "Account locked after 5 attempts"  (red)
  ✓ Implement lockout logic                            (green)
  ✓ Refactor                                           (clean)
  → Next scenario...
```

Every scenario gets a test. Every test links back to the spec. Nothing slips through.

## Install

**From the plugin marketplace:**

```shell
/install kirkchen/beat
```

**Or locally:**

```bash
claude --plugin-dir /path/to/beat
```

Then, in your project:

```bash
/beat:setup    # Detects your stack, creates beat/config.yaml
```

## Quick Start — 3 Commands

For most changes, this is all you need:

```bash
/beat:design fix-expired-session    # Describe the behavior change → generates Gherkin
/beat:apply                         # TDD: test → implement → next scenario
/beat:archive                       # Sync features to living docs, clean up
```

For complex changes, add `/beat:verify` before archive — it dispatches an independent agent to validate your implementation against the specs, catching gaps that the implementer's own context would miss.

Beat scales up when you need it (see [Full Pipeline](#full-pipeline)), but the simple path works for everyday fixes and small features.

## Already Have Code? Start with Distill

Most BDD tools only work for new code. Beat works backwards too — extract Gherkin from your **existing** codebase:

```bash
/beat:distill src/billing/          # Reads your code, generates feature files
```

```gherkin
@distilled @behavior @happy-path
Scenario: Monthly billing adjusts for short months
  Given a subscription billing on the 31st
  When February billing cycle runs
  Then the charge date adjusts to the 28th
```

Now you have living documentation of what your system actually does. Next time you change billing logic, Beat knows what behavior exists and what tests to write.

**This is the recommended entry point for existing projects.** Distill first, then use the full pipeline for future changes.

## Full Pipeline

```
explore → design → plan → apply → verify → archive
```

| Command | What it does | When to use |
|---------|-------------|-------------|
| `/beat:explore` | Think through ideas, no code | Unclear requirements, brainstorming |
| `/beat:design` | Create change + generate specs | Starting any change |
| `/beat:plan` | Task breakdown + multi-role review | Complex features (5+ scenarios) |
| `/beat:apply` | TDD implementation per scenario | Every change |
| `/beat:verify` | Independent verification against specs | Before shipping complex changes |
| `/beat:archive` | Sync features + archive change | After every change |

**Pick your path by size:**

| Change size | Commands | Example |
|------------|----------|---------|
| Bug fix | `design → apply → archive` | Fix off-by-one in date calc |
| Feature | `design → apply → verify → archive` | Add password reset flow |
| Large feature | `design → plan → apply → verify → archive` | Payment processing system |

Every change lives in `beat/changes/<name>/` with a `status.yaml` tracking where you are.

## What Beat Generates

Each change can include these artifacts (you choose which):

| Artifact | Default | Purpose |
|----------|---------|---------|
| `features/*.feature` | **Included** | Gherkin scenarios — the spec |
| `proposal.md` | Optional | Why this change exists |
| `design.md` | Optional | Technical decisions |
| `tasks.md` | Optional | Implementation plan |

For purely technical changes (refactoring, tooling, deps), you can skip Gherkin entirely and drive from `proposal.md` instead.

## Testing Architecture

Beat connects feature files to tests through lightweight text annotations — no framework, no build step, works in any language:

**In your `.feature` file:**
```gherkin
@behavior @happy-path
# @covered-by: src/billing/__tests__/date-calc.test.ts
Scenario: Monthly billing adjusts for short months
```

**In your test file:**
```typescript
// @feature: monthly-billing.feature
// @scenario: Monthly billing adjusts for short months
describe('Monthly billing', () => {
  it('adjusts for short months', () => { ... })
})
```

`/beat:verify` checks these links automatically — no scenario without a test, no test without a scenario.

Three test layers, each using your project's own frameworks:

| Layer | Tag | Example |
|-------|-----|---------|
| **E2E** | `@e2e` | Full user journey through the UI |
| **Behavior** | `@behavior` | Business logic with `@covered-by` tracing |
| **Unit** | — | Technical edge cases, no feature binding |

## Configuration

`/beat:setup` auto-detects your stack. All config is optional:

```yaml
# beat/config.yaml
language: zh-TW               # Artifact language (BCP 47)
context: |                     # Project background
  Express API, PostgreSQL, Vitest for testing
testing:
  behavior: vitest             # For @behavior scenarios
  e2e: playwright              # For @e2e scenarios
rules:
  gherkin:
    - "Max 5 scenarios per feature"
```

## With Superpowers (Recommended)

Beat works standalone, but pairs well with [superpowers](https://github.com/obra/superpowers) for structured brainstorming, git worktree isolation, and TDD discipline:

| Capability | With superpowers | Without |
|-----------|-----------------|---------|
| Brainstorming | Structured ideation before specs | Direct conversation |
| Worktree isolation | Changes in isolated git worktree | Work on current branch |
| TDD discipline | Enforced red-green-refactor | Standard implementation |
| Task generation | Detailed plan with review | Simple checklist |
| Post-archive | Guided PR/merge workflow | Manual |

## Design Principles

- **Behavior over implementation** — scenarios describe what the system does, not how
- **File system as state** — `status.yaml` + directories, no database, fully git-trackable
- **Optional is real** — ceremony scales with complexity, not one-size-fits-all
- **Framework-agnostic** — works with any language, any test framework
- **Independent verification** — `/beat:verify` uses a fresh agent to avoid confirmation bias

See [docs/DESIGN_PRINCIPLES.md](docs/DESIGN_PRINCIPLES.md) for the full philosophy.

## License

MIT
