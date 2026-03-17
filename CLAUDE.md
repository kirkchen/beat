# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Is Beat

Beat is a Claude Code plugin that provides an agent-driven BDD (Behavior-Driven Development) workflow. It uses Gherkin `.feature` files as the single source of truth for behavior specifications. Beat is not an application — it is a set of **skills** (SKILL.md files) that Claude Code loads as a plugin.

## Installation

```bash
claude --plugin-dir /path/to/beat
```

## Architecture

### Plugin Structure

```
beat/
├── .claude-plugin/plugin.json   # Plugin manifest (name, version, metadata)
├── skills/                      # Each subdirectory = one invocable skill
│   ├── new/SKILL.md             # /beat:new — create a change container
│   ├── continue/SKILL.md        # /beat:continue — build next artifact
│   ├── ff/SKILL.md              # /beat:ff — fast-forward all artifacts
│   ├── apply/SKILL.md           # /beat:apply — TDD implementation
│   ├── verify/SKILL.md          # /beat:verify — 3-dimension verification
│   ├── sync/SKILL.md            # /beat:sync — sync to beat/features/
│   ├── archive/SKILL.md         # /beat:archive — archive completed change
│   ├── explore/SKILL.md         # /beat:explore — thinking partner mode
│   ├── setup/SKILL.md           # /beat:setup — create beat/config.yaml
│   └── distill/SKILL.md         # /beat:distill — reverse-engineer specs from code
├── references/                  # Schemas referenced by skills
│   ├── status-schema.md         # status.yaml format (single source of truth)
│   ├── config-schema.md         # config.yaml format (single source of truth)
│   └── testing-conventions.md   # Annotation format and e2e test style reference
├── hooks/                       # Claude Code hooks
│   ├── hooks.json               # SessionStart hook config
│   └── session-start            # Detects Beat project, injects workflow context
├── tests/                       # Automated skill tests (claude -p headless)
│   ├── test-helpers.sh          # Shared assertion framework
│   ├── run-all.sh               # Run all fast tests (--integration for pipeline)
│   ├── analyze-token-usage.py   # Token analysis for test sessions
│   ├── skill-triggering/        # Layer 1: Description CSO validation
│   ├── skill-content/           # Layer 2: Enforcement awareness smoke tests
│   ├── pressure/                # Layer 3: Anti-rationalization under pressure
│   └── pipeline/                # Layer 4: End-to-end pipeline (--integration)
└── README.md
```

### How It Works in Target Projects

When installed in a user's project, Beat creates this structure:

```
<project>/beat/
├── config.yaml              # Optional project config (language, context, rules)
├── changes/                 # Active and archived changes
│   ├── <change-name>/       # One directory per active change
│   │   ├── status.yaml      # Change lifecycle state
│   │   ├── proposal.md      # Optional: why this change exists
│   │   ├── features/        # Gherkin feature files (mandatory by default)
│   │   │   └── *.feature
│   │   ├── design.md        # Optional: technical decisions
│   │   └── tasks.md         # Optional: implementation checklist
│   └── archive/             # Completed changes (YYYY-MM-DD-<name>/)
└── features/                # Persistent living documentation
    └── <capability>/        # Organized by capability after sync
        ├── *.feature
        └── README.md
```

### Pipeline Flow

```
explore → new → [proposal] → gherkin → [design] → [tasks] → apply → verify → sync → archive
                 optional     default    optional   optional
                              mandatory
```

For purely technical changes (tooling, deps, refactor): gherkin can be skipped, proposal becomes the driver.

- **new**: Creates the change container (directory + status.yaml)
- **continue**: Builds one artifact at a time in pipeline order
- **ff**: Creates all artifacts in one go (shortcut for continue × N)
- **apply**: TDD implementation — gherkin-driven (every scenario must have a test) or proposal-driven (when gherkin skipped)
- **verify**: Dispatches independent subagent to verify against artifacts
- **sync**: Copies features to `beat/features/` as living documentation
- **archive**: Moves change to `beat/changes/archive/`

### Key Concepts

- **status.yaml** is the state machine — schema defined in `references/status-schema.md`. Phase advances forward only. Pipeline entries use inline YAML flow style: `{ status: done }`.
- **config.yaml** is optional project config — schema in `references/config-schema.md`. Controls artifact language, injects project context, and adds per-artifact rules.
- **Gherkin is mandatory by default** but can be skipped for purely technical changes (tooling, deps, refactoring without behavior change). When skipped, proposal drives apply and verify.
- **verify** and **distill** use independent subagents (Agent tool with `subagent_type: Explore`) to avoid context bias.
- **distill** works in reverse (code → spec) and marks features with `@distilled` tag.

### Testing Architecture

Beat supports a three-layer testing architecture that connects feature files to tests at the appropriate level:

**Layer 1: E2E Tests** — `@e2e` tagged scenarios → e2e tests or BDD step definitions (using project's e2e framework)

**Layer 2: Behavior Tests** — `@behavior` tagged scenarios → tests with annotation linking (using project's test framework):
- Feature files include `# @covered-by: <path/to/test.ts>` between the tag and scenario line
- Test files include `// @feature: <file>.feature` and `// @scenario: <name>` comments
- Verify checks these annotations for bidirectional traceability

**Layer 3: Unit Tests** — No feature binding, driven by proposal risk points or developer judgment

**Annotation conventions:**

In .feature files (annotation placed between tag and scenario line):
```gherkin
@behavior @happy-path
# @covered-by: src/services/__tests__/date-calculation.test.ts
Scenario: Monthly billing adjusts for short months
```

In test files (use the project language's comment syntax):
```
@feature: monthly-billing.feature
@scenario: Monthly billing adjusts for short months
```

**Granularity guidance** — Scenarios should describe behavior (what the system does), not function specs (how a function works). See `continue/SKILL.md` Granularity Assessment.

**Proposal-driven testing** — When gherkin is skipped (technical changes), testing is driven by proposal.md risk points and success criteria. Tests use the project's test framework without feature file annotations.

## Dependencies

Requires the [superpowers](https://github.com/obra/superpowers) plugin for TDD, brainstorming, and debugging integrations referenced by `continue`, `apply`, and `explore` skills.

### Superpowers Integration

Beat cooperates with Superpowers via a SessionStart hook (`hooks/session-start`). When `beat/config.yaml` or `beat/changes/` exists, the hook injects context telling Claude to transition to Beat workflow after brainstorming instead of `writing-plans` directly. Skills reference Superpowers via `MUST invoke` prerequisites with anti-rationalization enforcement (Hard Gate, Rationalization Table, Red Flags).

## Design Philosophy

See `docs/DESIGN_PRINCIPLES.md` for the full design philosophy — core beliefs, testing philosophy, pipeline design rationale, and what Beat is and isn't. Consult it when evaluating changes that affect multiple skills or the overall direction.

## Development Guidelines

### Editing Skills

Each skill is a single SKILL.md file with YAML frontmatter (`name`, `description`) followed by markdown instructions. Skills are self-contained — they reference schemas in `references/` but don't import code.

### Schema Changes

`references/status-schema.md` and `references/config-schema.md` are the single sources of truth. Every skill that reads/writes these files must follow the schemas exactly. If you change a schema, audit all skills that reference it.

### Testing Changes

Beat has a four-layer automated test suite using `claude -p` headless mode. Tests are in `tests/`.

**Run fast tests (~20 min):**
```bash
cd tests && ./run-all.sh
```

**Run all tests including pipeline integration (~50 min):**
```bash
cd tests && ./run-all.sh --integration
```

**Four test layers:**

| Layer | What it tests | Scripts |
|-------|--------------|---------|
| Skill Triggering | Naive prompts trigger correct Beat skill | `skill-triggering/` |
| Skill Content | Skills know their enforcement rules (smoke test) | `skill-content/` |
| Pressure | Anti-rationalization holds under implicit pressure | `pressure/` |
| Pipeline Integration | End-to-end new → ff → apply → verify | `pipeline/` (--integration only) |

**When to run tests:**
- After changing any skill description → run `skill-triggering/run-all.sh`
- After changing enforcement rules (Hard Gate, Rationalization Table) → run `pressure/run-all.sh`
- After changing skill content → run `skill-content/run-all.sh`

**Notes:**
- Tests use `claude -p --output-format stream-json --verbose` and grep for tool invocations
- Some tests are non-deterministic (LLM behavior varies) — a single flaky fail doesn't indicate a real problem
- Pressure tests assert Beat's responsibility boundary only (did it invoke the Superpowers skill?), not Superpowers' execution
- macOS compatible (Perl-based timeout fallback, no GNU coreutils needed)

**Manual testing** is still useful for verifying the full user experience:
1. Install the plugin in a test project
2. Run the skill command (e.g., `/beat:new`)
3. Verify the skill produces correct artifacts and status.yaml updates
