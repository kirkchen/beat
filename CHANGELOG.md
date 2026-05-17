# Changelog

All notable changes to Beat are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and Beat adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-17

### Added

Three layers of project-level **living documentation**, all lazily created on
first use:

- **Layer 1 — `beat/CONTEXT.md`** (domain glossary). Maintained inline by
  `/beat:design` via a four-challenge check (against glossary / sharpen fuzzy /
  scenario stress-test / cross-reference code) before writing gherkin, and by
  `/beat:archive` via a feature scan before sync. Optional hand-off to
  `mattpocock-skills:grill-with-docs` when ambiguity is complex; graceful
  fallback when not installed. Format: `references/context-format.md`.

- **Layer 2 — `docs/adr/`** (Architectural Decision Records). 1-3 sentence
  ADRs gated by three conditions: hard-to-reverse + surprising without context
  + result of a real trade-off. Offered at four trigger points: `/beat:design`
  (per Key Decision), `/beat:plan` (review-rejected alternatives),
  `/beat:apply` (implementation-forced choices), `/beat:archive` (last-mile
  sweep when zero ADRs written). Format: `references/adr-format.md`.

- **Layer 3 — `beat/ARCHITECTURE.md` + module `README.md`**
  (structure & intent). Hand-written hub (~150 lines) with Mermaid diagram,
  modules table, and constraints referencing ADRs; per-module spokes
  (~100 lines) covering Purpose / Public Interface / Internal Dependencies /
  Tests. Vocabulary is intentionally unspecified — monorepo, DDD, or
  framework-native terms all work. Maintained by `/beat:apply` on
  public-interface changes and surfaced by `/beat:verify` Dimension 5
  (advisory, WARNING tier). Format: `references/architecture-format.md`.

Other additions:

- **Spec self-review** in `/beat:design` — four-check pass (placeholder /
  consistency / scope / ambiguity) after each artifact, adapted from
  `superpowers:brainstorming`.
- **`NOTICE.md`** records third-party attribution (mattpocock-skills,
  superpowers — both MIT, MIT-compatible).
- **Tables of contents** added to all reference files longer than 100 lines.
- **Skill smoke tests** (`tests/skill-content/`) extended with assertions
  covering all new living-doc enforcement.

### Changed

- Frontmatter descriptions on `design`, `plan`, `archive`, `setup`, and
  `verify` tightened to pure trigger conditions under 120 characters (per
  skill-hardening guidance). `verify` gained an explicit `<decision_boundary>`
  block.
- `references/feature-writing.md` updated: drop per-feature Glossary
  recommendation (the project-level `beat/CONTEXT.md` is now canonical), add
  bolded domain term convention.
- `hooks/session-start` and `references/codex-agents-snippet.md` announce the
  three living-doc surfaces so Claude Code and Codex sessions start with the
  same baseline awareness.
- `CLAUDE.md` and both READMEs document the three layers and Beat's "Hard
  Prompt, Soft Action" enforcement philosophy.

### Known issues

- **Pressure tests on `/beat:apply` show baseline non-determinism.** Adding
  the Mid-Implementation Triggers section may further reduce Claude's
  resistance to user pressure to skip TDD/worktree prerequisites (main
  baseline ~50% pass rate; this release sampled at 0/15 in 5 runs). Layer 2/3
  enforcement is preserved via `/beat:design` ADR gate, `/beat:plan` ADR
  offer, `/beat:archive` last-mile sweep, and `/beat:verify` Dimension 5
  advisory — `/beat:apply` is not the sole owner. Will revisit after the
  next Claude model version or a larger sample.

## [0.1.0] - 2026-05-15

Initial release. Agent-driven BDD workflow:
`/beat:explore` → `/beat:design` → `/beat:plan` → `/beat:apply` →
`/beat:verify` → `/beat:archive`, plus `/beat:setup` and `/beat:distill`.
