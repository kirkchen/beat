# Changelog

All notable changes to Beat are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and Beat adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `/beat:distill` now participates in all three living-doc layers, matching
  the other lifecycle skills: a glossary check before writing feature files
  (Layer 1, four challenges adapted for code-as-source), a three-condition
  ADR gate on Key Decisions recovered from the code (Layer 2 — rationale
  must come from evidence or the user, never invented), and a module README
  scaffold offer (Layer 3, advisory). Distill also runs the same four-check
  spec self-review as `/beat:design`.
- `/beat:verify` records its outcome in a new top-level `verification` field
  in status.yaml (`{ status, critical, date }`); `/beat:archive` warns and
  asks for confirmation when archiving a change that was never verified or
  has unresolved critical findings. Inform-and-confirm — never blocks.
- `/beat:explore` runs the ADR gate when capturing design decisions;
  `/beat:design` suggests `beat/ARCHITECTURE.md` hub updates on module-level
  changes; `/beat:apply` offers README scaffolding when creating a new module.
- `/beat:plan` and `/beat:apply` warn before operating on a distill change
  (`source: distill`) — there is nothing to plan or implement.

### Fixed

- Distill lifecycle dead end: the skill now routes to `/beat:verify` →
  `/beat:archive` (previously suggested plan/apply, which have nothing to do
  for a distill change) and sets `tasks: skipped` plus `skipped` for declined
  optional artifacts, so archive no longer warns spuriously.
- `/beat:verify` now passes the `gherkin.modified` file list (with `.orig`
  paths) to the verification subagent — semantic verification of modified
  scenarios (Dimension 1B+) could previously never trigger.
- BDD feature paths are combined whenever `beat/changes/<name>/features/`
  contains feature files — previously conditioned on `gherkin.modified`, so
  changes that only added new features never ran them in e2e regression.
- `/beat:archive` runs the last-mile ADR sweep on the gherkin-skipped path
  too (previously bypassed for exactly the technical changes that need it).
- Stale docs: verify is five dimensions (not three/four); `.orig` backups are
  created by design (not plan); ADR trigger tables now list all six points.

## [0.2.2] - 2026-05-31

### Fixed

- `/beat:verify` no longer dispatches the `superpowers:code-reviewer` agent,
  which superpowers removed in v5.1.0 (its persona/checklist moved into a
  per-skill template). Agent B now dispatches `general-purpose` with an
  internalized prompt at `skills/verify/code-reviewer-prompt.md`, reshaped to
  Beat's Dimension 4 and CRITICAL/WARNING/SUGGESTION severity. Dimension 4
  (code quality) previously failed silently when the named agent could not be
  resolved; it now also works standalone without superpowers installed.

## [0.2.1] - 2026-05-25

### Fixed

- Codex install via `npx skills add` now ships the references each skill
  cites. The plugin previously kept all references at `/references` (plugin
  root), but the skills CLI install path only copies a single skill folder
  — so agents on Codex hit path-not-found when reading schema docs like
  `references/status-schema.md`. Each skill now carries its own
  `references/` subfolder, synced from the plugin-root source of truth via
  `scripts/sync-references.mjs`.

### Internal

- `tool-mapping.md` and `codex-agents-snippet.md` stay at plugin root only
  (no SKILL.md cites them).
- `skills/setup/SKILL.md` brace-expanded references path expanded to
  explicit filenames so the sync scanner picks them up.

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
