# Beat

Agent-driven BDD workflow plugin for Claude Code. Uses Gherkin `.feature` files as the single source of truth for behavior specifications.

## Install

### From Marketplace (recommended)

```shell
# Add the marketplace
/plugin marketplace add kirkchen/beat

# Install the plugin
/plugin install beat@beat-bdd
```

### Local Development

```bash
claude --plugin-dir /path/to/beat
```

## Commands

| Command | Description |
|---------|-------------|
| `/beat:new` | Start a new change |
| `/beat:explore` | Think through ideas before starting |
| `/beat:continue` | Build the next artifact in the pipeline |
| `/beat:ff` | Fast-forward — create all artifacts at once |
| `/beat:apply` | Implement code with TDD for each scenario |
| `/beat:verify` | 3-dimension verification against artifacts |
| `/beat:setup` | Initialize Beat config in a project |
| `/beat:sync` | Sync features to persistent `beat/features/` |
| `/beat:archive` | Archive a completed change |
| `/beat:distill` | Reverse-engineer features from existing code |

## Pipeline

```
explore → new → [proposal] → gherkin → [design] → [tasks] → apply → verify → sync → archive
                 optional     default    optional   optional
                              mandatory
```

Gherkin can be skipped for purely technical changes (tooling, deps, refactor). See [Design Principles](docs/DESIGN_PRINCIPLES.md).

Each change lives in `beat/changes/<name>/` with a `status.yaml` tracking progress. Optional project config in `beat/config.yaml`.

## Artifacts

| Artifact | Required | Purpose |
|----------|----------|---------|
| `proposal.md` | Optional | Why this change exists |
| `features/*.feature` | **Default** | Gherkin scenarios defining behavior |
| `design.md` | Optional | Technical decisions |
| `tasks.md` | Optional | Implementation checklist |

## Typical Paths

| Size | Path |
|------|------|
| Small fix | `new → gherkin → apply → archive` |
| Medium feature | `new → proposal → gherkin → apply → verify → sync → archive` |
| Large feature | `new → proposal → gherkin → design → tasks → apply → verify → sync → archive` |

## Testing Architecture

Beat connects feature files to tests at three levels:

| Layer | Tag | Binding |
|-------|-----|---------|
| E2E | `@e2e` | Step definitions or annotations |
| Behavior | `@behavior` | `@covered-by` / `@scenario` annotations |
| Unit | — | No feature binding |

```gherkin
@behavior @happy-path
# @covered-by: src/services/__tests__/date-calculation.test.ts
Scenario: Monthly billing adjusts for short months
```

## Design Principles

See [docs/DESIGN_PRINCIPLES.md](docs/DESIGN_PRINCIPLES.md) for Beat's design philosophy, testing architecture, and pipeline rationale.

## Dependencies

Requires [superpowers](https://github.com/anthropics/superpowers) plugin for TDD, brainstorming, and debugging integrations referenced by `continue`, `apply`, and `explore` skills.

## License

MIT
