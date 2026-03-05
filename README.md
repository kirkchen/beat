# Beat

Agent-driven BDD workflow plugin for Claude Code. Uses Gherkin `.feature` files as the single source of truth for behavior specifications.

## Install

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
| `/beat:init` | Initialize Beat config in a project |
| `/beat:sync` | Sync features to persistent `beat/features/` |
| `/beat:archive` | Archive a completed change |
| `/beat:distill` | Reverse-engineer features from existing code |

## Pipeline

```
explore → new → [proposal] → gherkin → [design] → [tasks] → apply → verify → sync → archive
                 optional     REQUIRED   optional   optional
```

Each change lives in `beat/changes/<name>/` with a `status.yaml` tracking progress. Optional project config in `beat/config.yaml`.

## Artifacts

| Artifact | Required | Purpose |
|----------|----------|---------|
| `proposal.md` | Optional | Why this change exists |
| `features/*.feature` | **Required** | Gherkin scenarios defining behavior |
| `design.md` | Optional | Technical decisions |
| `tasks.md` | Optional | Implementation checklist |

## Typical Paths

| Size | Path |
|------|------|
| Small fix | `new → gherkin → apply → archive` |
| Medium feature | `new → proposal → gherkin → apply → verify → sync → archive` |
| Large feature | `new → proposal → gherkin → design → tasks → apply → verify → sync → archive` |

## License

MIT
