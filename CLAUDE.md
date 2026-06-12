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
├── .claude-plugin/plugin.json   # Claude Code plugin manifest
├── .codex-plugin/plugin.json    # Codex plugin manifest (with interface block)
├── .agents/plugins/marketplace.json  # Codex marketplace manifest — makes this repo a single-plugin marketplace
├── plugins/beat/                # Codex plugin overlay (symlinks to root files: skills, assets, .codex-plugin, references)
├── assets/                      # Brand icons (composerIcon, logo) for Codex
├── skills/                      # Each subdirectory = one invocable skill (SKILL.md + synced references/)
│   ├── design/                  # /beat:design — create change + generate spec artifacts
│   ├── plan/                    # /beat:plan — task breakdown with multi-role review
│   ├── apply/                   # /beat:apply — TDD implementation
│   ├── verify/                  # /beat:verify — 5-dimension verification
│   ├── archive/                 # /beat:archive — sync features + archive completed change
│   ├── explore/                 # /beat:explore — thinking partner mode
│   ├── setup/                   # /beat:setup — create beat/config.yaml
│   └── distill/                 # /beat:distill — reverse-engineer specs from code
├── references/                  # Source of truth for shared schemas — edit here, then run scripts/sync-references.mjs
│   ├── status-schema.md         # status.yaml format
│   ├── config-schema.md         # config.yaml format
│   ├── testing-conventions.md   # Annotation format and e2e test style reference
│   ├── context-format.md        # beat/CONTEXT.md glossary format (Layer 1 living docs)
│   ├── adr-format.md            # docs/adr/ ADR format + three-condition gate (Layer 2 living docs)
│   ├── architecture-format.md   # beat/ARCHITECTURE.md hub + module README format (Layer 3 living docs)
│   ├── tool-mapping.md          # Cross-platform tool name mapping (root only)
│   └── codex-agents-snippet.md  # Per-project AGENTS.md snippet for Codex (root only)
├── scripts/sync-references.mjs  # Syncs /references into each skill's references/ (see header for rationale)
├── NOTICE.md                    # Third-party attribution (mattpocock-skills, superpowers — both MIT)
├── hooks/                       # Claude Code hooks (Codex ignores; replaced by AGENTS.md snippet)
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
<project>/
├── beat/
│   ├── config.yaml              # Optional project config (language, context, rules)
│   ├── CONTEXT.md               # Layer 1 — domain glossary (lazy, created on first term)
│   ├── ARCHITECTURE.md          # Layer 3 — architecture hub (lazy, multi-module projects)
│   ├── changes/                 # Active and archived changes
│   │   ├── <change-name>/       # One directory per active change
│   │   │   ├── status.yaml      # Change lifecycle state
│   │   │   ├── proposal.md      # Optional: why this change exists
│   │   │   ├── features/        # Gherkin feature files (mandatory by default)
│   │   │   │   └── *.feature
│   │   │   ├── design.md        # Optional: technical decisions
│   │   │   └── tasks.md         # Optional: implementation checklist
│   │   └── archive/             # Completed changes (YYYY-MM-DD-<name>/)
│   └── features/                # Persistent living documentation
│       └── <capability>/        # Organized by capability after sync
│           ├── *.feature
│           └── README.md
├── docs/adr/                    # Layer 2 — ADRs (lazy, three-condition gate)
│   └── NNNN-slug.md
└── packages|src/<module>/
    └── README.md                # Layer 3 — module README (lazy, on public-interface change)
```

### Pipeline Flow

```
explore → design → plan → apply → verify → archive
           │         │
           │         └── tasks (with multi-role review)
           └── [proposal] → gherkin → [design]
                optional     default    optional
                             mandatory
```

For purely technical changes (tooling, deps, refactor): gherkin can be skipped, proposal becomes the driver.

- **design**: Creates worktree + change container + generates spec artifacts (proposal, gherkin, design.md) + commits
- **plan**: Creates execution plan (tasks.md) with multi-role review against spec artifacts + commits
- **apply**: TDD implementation — gherkin-driven (every scenario must have a test) or proposal-driven (when gherkin skipped). Verifies worktree isolation (should exist from design/plan).
- **verify**: Dispatches independent subagent to verify against artifacts
- **archive**: Syncs features to `beat/features/` as living documentation + moves change to `beat/changes/archive/`

### Key Concepts

- **status.yaml** is the state machine — schema defined in `references/status-schema.md`. Phase advances forward only. Pipeline entries use inline YAML flow style: `{ status: done }`. `/beat:verify` records its outcome in the top-level `verification` field (it never advances phase); `/beat:archive` warns when archiving a change without a passing verification record.
- **config.yaml** is optional project config — schema in `references/config-schema.md`. Controls artifact language, injects project context, and adds per-artifact rules.
- **Gherkin is mandatory by default** but can be skipped for purely technical changes (tooling, deps, refactoring without behavior change). When skipped, proposal drives plan, apply, and verify.
- **verify** uses independent subagents (Agent tool with `subagent_type: Explore`) to avoid context bias. When verifying distilled specs (`source: distill`), it switches to accuracy mode.
- **distill** works in reverse (code → spec), marks features with `@distilled` tag, and relies on `/beat:verify` for independent accuracy verification. A distill change sets `tasks: skipped` (nothing to implement) and flows distill → verify → archive; future changes to the distilled area use the normal flow in their own change containers.

### Living Documentation (three layers)

Beat maintains three layers of project-level living documentation alongside the per-change artifacts. All three are **lazy** — created on first need, never preemptively. They complement the per-change archives, not replace them.

- **Layer 1 — `beat/CONTEXT.md`** (glossary). Domain vocabulary, one canonical term per concept, opinionated about synonyms. Maintained inline by `/beat:design` (four-challenge check before writing gherkin), `/beat:distill` (glossary check on terms recovered from code), and `/beat:archive` (scan synced features for undefined terms). Format: `references/context-format.md`. Optional grilling via `mattpocock-skills:grill-with-docs` when ambiguity is complex.

- **Layer 2 — `docs/adr/NNNN-slug.md`** (decisions). 1-3 sentence ADRs gated by three conditions: hard-to-reverse + surprising without context + result of a real trade-off. Offered at five trigger points: `/beat:design` (per Key Decision), `/beat:plan` (review rejections), `/beat:apply` (implementation-forced choices), `/beat:distill` (Key Decisions recovered from code — rationale from evidence or the user, never invented), `/beat:archive` (last-mile sweep when zero ADRs written). Format: `references/adr-format.md`. ADRs live at `docs/adr/` rather than `beat/adr/` because the ADR format is an industry standard (Nygard 2011) with its own tool ecosystem; Beat only triggers and offers, while the files belong to the project and outlive Beat if the plugin is removed.

- **Layer 3 — `beat/ARCHITECTURE.md` hub + module `README.md` spokes** (structure & intent). Hub stays under ~150 lines: one Mermaid diagram, modules table, constraints referencing ADRs. Each module README under ~100 lines: purpose, public interface, dependencies, tests. Vocabulary is intentionally unspecified — use the codebase's native terms (package/service/module/layer). Maintained by `/beat:apply` (hard prompt on public-interface change, README scaffold offer on new module), `/beat:design` (hub update suggestion on module-level architecture change), `/beat:distill` (README scaffold offer for distilled modules), and `/beat:verify` (Dimension 5, WARNING tier, advisory only). Format: `references/architecture-format.md`. Structural snapshots (file tree, symbol map) are derive-tool territory — Beat doesn't generate them.

- **Spec self-review**: After writing each artifact, `/beat:design` runs a four-check pass (placeholder / consistency / scope / ambiguity) and fixes issues inline. Adapted from `superpowers:brainstorming`.

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

**Granularity guidance** — Scenarios should describe behavior (what the system does), not function specs (how a function works). See `design/SKILL.md` for Gherkin creation guidelines.

**Proposal-driven testing** — When gherkin is skipped (technical changes), testing is driven by proposal.md risk points and success criteria. Tests use the project's test framework without feature file annotations.

## Dependencies

Requires the [superpowers](https://github.com/obra/superpowers) plugin for TDD, brainstorming, and debugging integrations referenced by `design`, `plan`, `apply`, and `explore` skills.

Optionally integrates with [mattpocock-skills](https://github.com/mattpocock/skills) — `/beat:design` can hand off to `grill-with-docs` when CONTEXT.md ambiguity is complex enough to warrant a full grilling session. Graceful fallback when not installed.

`NOTICE.md` records third-party attribution for content adapted from these projects (both MIT-licensed).

### Superpowers Integration

Beat cooperates with Superpowers via a SessionStart hook (`hooks/session-start`). When `beat/config.yaml` or `beat/changes/` exists, the hook injects context telling Claude to transition to Beat workflow after brainstorming instead of `writing-plans` directly. Skills reference Superpowers via `MUST invoke` prerequisites with anti-rationalization enforcement (Hard Gate, Rationalization Table, Red Flags).

## Design Philosophy

See `docs/DESIGN_PRINCIPLES.md` for the full design philosophy — core beliefs, testing philosophy, pipeline design rationale, and what Beat is and isn't. Consult it when evaluating changes that affect multiple skills or the overall direction.

## Development Guidelines

### Editing Skills

Each skill is a single SKILL.md file with YAML frontmatter (`name`, `description`) followed by markdown instructions. Skills are self-contained — they reference schemas in `references/` but don't import code.

### Schema Changes

`references/status-schema.md` and `references/config-schema.md` are the single sources of truth. Every skill that reads/writes these files must follow the schemas exactly. If you change a schema, audit all skills that reference it.

### References sync

`/references` is the source of truth; `skills/<name>/references/` are synced copies. After editing anything under `/references`, run `node scripts/sync-references.mjs` (or `--check` for CI). Do not hand-edit synced copies. Rationale in the script header.

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
| Pipeline Integration | End-to-end design → plan → apply → verify → archive | `pipeline/` (--integration only) |

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
2. Run the skill command (e.g., `/beat:design`, `/beat:plan`)
3. Verify the skill produces correct artifacts and status.yaml updates

### Codex Distribution

Beat is installable on Codex directly from this GitHub repo — no separate marketplace fork or sync step. The repo is structured as a **single-plugin Codex marketplace**:

- `.agents/plugins/marketplace.json` declares one plugin `beat` with `source.path: "./plugins/beat"`.
- `plugins/beat/` is a thin overlay containing symlinks back to repo-root files (`.codex-plugin/`, `skills/`, `assets/`, `references/`, `README.md`, `LICENSE`). Single source of truth at root, no duplication.

`source.path: "./"` (root as plugin) was tried first but Codex's plugin scanner does not pick up content when marketplace and plugin overlap at the same path — the subdirectory layout matches the convention in `openai/plugins` and other working marketplaces.

End-user install (two steps because the Codex CLI has no plugin-install subcommand — only marketplace add/upgrade/remove):

1. `codex plugin marketplace add https://github.com/kirkchen/beat`
2. Inside Codex UI plugins panel, install Beat.

See `docs/INSTALL-CODEX.md` for the full user-facing flow.

Codex doesn't support hooks, so the SessionStart context injection performed by `hooks/session-start` does not run on Codex. The replacement is a per-project `AGENTS.md` snippet — see `references/codex-agents-snippet.md` for the text.

If we ever want to publish Beat to the canonical `openai/plugins` curated marketplace, that's a separate manual step (open a PR upstream that copies the plugin into their `plugins/beat/` subdirectory — same shape we already use locally). The current setup intentionally does not automate that.
