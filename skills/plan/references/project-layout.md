# Project Layout

Beat writes into a project at fixed places so that other tools (mattpocock/skills, cadence) find the same files. This file is the map of those places; each row links the format reference for that file. Skills point here instead of hardcoding paths.

## Map

| Path | What | Created by | Lazy / required | Format |
|------|------|------------|-----------------|--------|
| `GLOSSARY.md` (project root) | Layer 1 domain glossary | `/beat:design`, `/beat:distill`, `/beat:archive`, and mattpocock `domain-modeling` | Lazy (created on the first term) | `references/context-format.md` |
| `CODING_STANDARDS.md` (project root) | Reviewer-facing judgement rules plus a "Sources" index of pointers to README conventions sections | `/beat:setup` scaffolds, mattpocock `/retro` appends, cadence `pr-review` reads | Required when the project uses an orchestrator or cadence, otherwise optional (`--layout` always requires it) | `references/coding-standards-template.md` |
| `docs/agents/issue-tracker.md` | Tracker, CLI, assignee, dispatch label, status labels, epic / sub-issue / blocking conventions | `/beat:setup` | Required for `/beat:to-issue` | `references/issue-tracker-github.md` / `-gitlab.md` / `-other.md` |
| `CLAUDE.md` or `AGENTS.md`, `## Agent docs` block | Three pointer lines to the files above | `/beat:setup` | Required with the files above | Inline example below |
| `docs/adr/NNNN-slug.md` | Layer 2 decisions (ADRs) | Skills at the ADR trigger points | Lazy | `references/adr-format.md` |
| `beat/config.yaml` | Project config | `/beat:setup` | Optional | `references/config-schema.md` |
| `beat/ARCHITECTURE.md` + module `README.md` | Layer 3 architecture hub and module spokes | `/beat:apply`, `/beat:design`, `/beat:distill` | Lazy | `references/architecture-format.md` |
| `beat/changes/`, `beat/routes/`, `beat/features/` | Change containers, routes, living features | The pipeline skills | Created as the pipeline needs them | `references/status-schema.md`, `references/route-schema.md` |

## Agent docs block

The pointer block goes in `CLAUDE.md` or `AGENTS.md`:

```markdown
## Agent docs

- Glossary: `GLOSSARY.md` — canonical terms; use them in every artifact.
- Coding standards: `CODING_STANDARDS.md` — judgement rules reviewers enforce; mechanical rules live in lint.
- Issue tracker: `docs/agents/issue-tracker.md` — where issues live, labels, how work is dispatched.
```

## Records

Records are files that describe what was true at a point in time. Migrations and path rewrites never touch them:

- paths under `beat/changes/archive/`
- paths under `docs/incidents/`, `docs/proposals/`, `docs/research/`, `docs/migrations/`
- the file `CHANGELOG.md`
- any file whose basename starts with a date, matching `^\d{4}-\d{2}-\d{2}-`

A record may keep an old path (for example `beat/CONTEXT.md`) forever.

## Legacy

`beat/CONTEXT.md` was the glossary path before 0.6. Projects that still have it run the migration prompt `docs/migrations/0.6-project-layout.md` (https://github.com/kirkchen/beat/blob/main/docs/migrations/0.6-project-layout.md). Skills do not read the legacy path.
