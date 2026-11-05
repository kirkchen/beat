# Changelog

All notable changes to Beat are documented in this file. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and Beat adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-11-04

### BREAKING

- The glossary moves from `beat/CONTEXT.md` to `GLOSSARY.md` at the project
  root, where mattpocock's `domain-modeling`, `pr` and `tdd` read it. Skills
  no longer read the old path; `/beat:setup` refuses to migrate and points at
  `docs/migrations/0.6-project-layout.md` (0261e3e refactor(skills): glossary
  is GLOSSARY.md at the project root).
- `/beat:to-issue` requires `docs/agents/issue-tracker.md`; projects that use
  an orchestrator or cadence also need `CODING_STANDARDS.md` and the
  `## Agent docs` block in `CLAUDE.md` / `AGENTS.md`. Run `/beat:setup` to
  write them.
- `/beat:explore` has a fifth exit, `drop`: the facts say not to build it, so
  explore closes the issue (when there is one) and creates nothing. Callers
  that matched on four exits must handle it (f9ca5ea, below).

### Added

- `references/project-layout.md`, the map of every project-level path Beat
  writes, with format reference and lazy / required for each (4411575
  feat(references): project-layout map; glossary moves to root GLOSSARY.md).
- Issue-tracker templates for GitHub, GitLab and other trackers, plus the
  `CODING_STANDARDS.md` template (adc7d8e feat(references): issue-tracker and
  coding-standards templates).
- Optional `issue` field on route nodes, written by `/beat:to-issue` (03d7c85
  feat(routes): optional issue field on route nodes).
- `validate-beat.mjs --layout` checks the 0.6 project layout (0240cfa
  feat(validate-beat): --layout checks the 0.6 project layout).
- `/beat:setup` writes `docs/agents/issue-tracker.md`, `CODING_STANDARDS.md`
  and the `## Agent docs` block (d741946 feat(setup): write issue-tracker.md,
  CODING_STANDARDS.md and the Agent docs block).
- `/beat:to-issue` turns a settled exploration into one tracker issue, or an
  epic with sub-issues for a too-big route (abc541c feat(to-issue):
  /beat:to-issue turns an exploration into tracker issues).
- `docs/migrations/0.6-project-layout.md`, a prompt an agent runs inside a
  0.5 project to move it to the new layout (bc03b46 docs(migrations): 0.6
  project layout migration prompt).

### Changed

- 6862e55 docs(proposals): unattended change flow — gates driven by
  stage-result, human at explore and merge.
- ee7964e feat(references): unattended mode, decision brief, stage-result
  keys, sensitive config.
- 89d5f2c feat(skills): unattended mode — defaults or decision briefs instead
  of questions, sensitivity and diverging signals, ready PR from archive.
- b042181 docs(research): mattpocock/skills workflow notes.
- 6379670 docs(proposals): keep beat-supervise answering questions for
  non-flow supervised tasks.
- 0c485c3 docs(proposals): v3 — explore is the only intake, status/*
  vocabulary, issue-tracker config, spec vs ticket scale, mattpocock repo
  files.
- 4163abe docs(proposals): v4 — 24 review findings resolved; PR stage leaves
  the change flow; gate onReply.
- f9ca5ea feat(skills): v4 review fixes — briefs before ADRs, multi-decision
  stops, plan brief, scope exit, sensitive.md, drop exit, archive re-entry.
- e2aa03d fix(references): tracker recipes version-safe, list limits, GitLab
  sub-issue wording.
- c689b8e fix(setup): new assertions check only the final answer; clarify
  kept files and default label note.
- 1d425e2 fix(to-issue): force yes/no in enforcement tests, keep Route line
  first on rewrite.
- Issue-tracker templates gain an edit-the-body recipe; `/beat:design` reads
  the preset from an English `Exit:` line as well as `出口：`.

## [0.5.0] - 2026-10-29

### Added

- `/beat:explore` ends by declaring an exit — `small`, `standard`, `too-big`
  or `blocked` — with the observable facts behind it. `too-big` creates a
  route (`beat/routes/<name>/`, `references/route-schema.md`): a map plus
  research / prototype / decision / change nodes with `blocked_by` edges.
  Node status is derived from the changes, never written.
- `preset` in status.yaml drives later-phase strength: `minimal` and
  `technical` get a test-coverage-only plan review and one verify subagent;
  `/beat:apply` upgrades them to `standard` when the diff crosses
  `config.yaml` `preset_upgrade` thresholds (`preset_upgrade` is recorded).
- `/beat:verify` writes `verify.md` (`references/verify-findings.md`): YAML
  front matter with one line per finding, then the report. `/beat:apply
  fix-from-verify` works through the open findings and marks them fixed.
  Re-runs are incremental from `verification.sha` and bounded by convergence
  rules adapted from cadence: zero open CRITICAL is converged and CRITICAL is
  never lowered or deferred; non-CRITICAL findings carry `reach` (reachable /
  speculative) and speculative ones — most race conditions — cap at
  SUGGESTION, recorded once; prose findings of the wording class cap at
  SUGGESTION; round 2 records no new SUGGESTIONs, round 3+ no new WARNINGs,
  round 4+ hunts only CRITICAL. `fix-from-verify` fixes CRITICAL and
  reachable WARNING by default and takes explicit ids for the rest. Archive never requires a
  full re-run.
- Every skill ends with a `## Beat Handoff` block
  (`references/handoff-report.md`) of command-derived facts and the next
  command; an optional `rhythm-stage-result[nonce]` line when a nonce is
  injected.
- `config.yaml` `prototype.surface` / `prototype.command` tell explore where
  a prototype node is built (for example Storybook). Stories may be merged;
  prototype implementation code never is.
- `scripts/validate-beat.mjs` checks status.yaml (schema, phase vs. artifacts,
  preset, route link, verify.md cross-check, sha ancestry), route status.yaml,
  verify.md, `beat/config.yaml` and `.feature.orig` residue, with `--pre-archive`,
  `--stale-paths` and `--handoff` modes. `scripts/lint-features.mjs` lints
  feature files (annotations, layer tags, user story, tags, placeholders, README
  index). Skills run both at fixed steps (`references/lint-tools.md`); the
  prose those checks replaced is gone. `tests/validator/` runs the fixtures;
  `.github/workflows/ci.yml` runs them on every PR.
- Scripts are synced into each skill folder (`skills/<name>/scripts/`) and
  symlinked into the Codex overlay, so they are available under the Claude
  Code plugin, the Codex plugin and `npx skills add`.
- `config.yaml` `lint` section: `tags`, `layer_tags`, `pending_tag`.
- Optional `mattpocock-skills` hooks: `research` and `prototype` from explore,
  `retro` mentioned at the end of archive.

### Changed

- `/beat:apply` never pushes; pushing belongs to
  `finishing-a-development-branch` after `/beat:archive`.
- `status.yaml` forbids fields outside the schema; `verification` gains
  `warning`, `sha`, `mode`.
- SessionStart hook and the Codex `AGENTS.md` snippet describe the exits,
  verify loop and handoff block.
- README "Companion Skills" says which superpowers / mattpocock skill each
  phase invokes and when; `docs/DESIGN_PRINCIPLES.md` gains "Why Explore
  Declares an Exit", "Why Routes Hold No State", "Size Before Ceremony",
  "Scripts Over Prose" and "Companions, Not Owners" (zh-TW mirrored).

## [0.4.0] - 2026-09-28

### Added

- `rules.adr` in `beat/config.yaml`: rules applied at every ADR trigger point
  (`/beat:explore`, `/beat:design`, `/beat:plan`, `/beat:apply`,
  `/beat:distill`, `/beat:archive`). A project `docs/adr/TEMPLATE.md`, when
  present, replaces Beat's built-in ADR skeleton.
- Beat's ADR template now carries front matter (`status`, `date`, `source`).
  `source` points at the originating change directory and is kept current by
  `/beat:archive`.
- `references/context-format.md` specifies where a new glossary entry goes:
  inside its group section (or `## Language`), never appended after
  `## Flagged ambiguities`.

### Changed

- `/beat:archive` states when it runs: on the feature branch after
  `/beat:verify` and before the PR/merge. It now commits its result (step 5c,
  `archive(<name>): ...`) before handing off to
  `superpowers:finishing-a-development-branch`, so the archive ships in the
  same PR as the code and is never deferred until after merge.
- Explicit skips are informed skips. When the user asks to skip feature sync
  or `.orig` cleanup (`/beat:archive`), the verification subagents
  (`/beat:verify`), TDD (`/beat:apply`), the worktree (`/beat:distill`) or
  brainstorming (`/beat:explore`), the skill names what is lost,
  confirms once, then honours the answer and records the skip — `/beat:verify`
  writes no `verification` record for a main-session check. Speed alone is
  still never a reason for the skill to skip on its own.
- `/beat:archive` merges the change's `design.md` into an existing
  `beat/features/<capability>/design.md` and rewrites it as the current state
  (with a `## History` line) instead of overwriting it.
- `/beat:archive` rewrites every tracked reference to `beat/changes/<name>`
  to the archived path after moving the directory, so ADR `source` fields and
  living-doc links keep resolving.
- `/beat:design`, `/beat:plan`, and `/beat:distill` commit the ADRs, ADR
  index, `beat/CONTEXT.md`, and `beat/ARCHITECTURE.md` edits they made
  together with the change directory, instead of staging only
  `beat/changes/<name>/`.

### Fixed

- `/beat:explore` did not read `beat/config.yaml` before writing an ADR, and
  no ADR trigger point applied config rules — ADRs written outside
  `/beat:design` could not follow project conventions.

## [0.3.0] - 2026-06-15

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
