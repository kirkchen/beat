<!--
References vocabulary from mattpocock/skills (MIT License) as optional precision terminology.
Original: skills/engineering/improve-codebase-architecture/LANGUAGE.md
Copyright (c) 2026 Matt Pocock
-->

# ARCHITECTURE.md Format

The single source of truth for Layer 3 living documentation:
`beat/ARCHITECTURE.md` (the hub) and per-module `README.md` files (the spokes).

`beat/ARCHITECTURE.md` is a **hub** — small, intent-focused, and links out to
module-level READMEs for detail. The hub answers *"what's here and why?"*;
module READMEs answer *"how do I use this part?"*.

## Design philosophy: Hybrid (hand-written + derive)

Architecture documentation has two ingredients with different half-lives:

- **Intent** — why these modules exist, what trade-offs shaped them, what
  invariants must hold. This **cannot be derived from code** and must be
  hand-written. ARCHITECTURE.md and module READMEs capture intent.
- **Structure** — what files exist, who imports whom, current dependency
  graph. This **rots fast when hand-maintained** and is best derived. Tools
  like Aider's repo-map, `repomix`, or DeepWiki regenerate structure on
  demand from current code.

Beat manages the **intent** side (this format). Beat does **not** generate
structure snapshots — users are encouraged to pick a derive tool that fits
their stack (e.g. `aider --map-tokens 1024`, `npx repomix`, DeepWiki) and run
it on demand when an AI needs a fresh structural map.

## `beat/ARCHITECTURE.md` (the hub)

Keep this file under **~150 lines**. The hub gets read every time someone
(human or AI) onboards into the repo — token budget matters.

### Structure

```md
# {Project Name} — Architecture

{One paragraph: what the system is and the shape that holds it together.
Roughly the elevator pitch for the codebase.}

## Diagram

\`\`\`mermaid
graph LR
  Web[packages/web] -->|enqueues| Worker[packages/worker]
  Worker -->|spawns| K8s[K8s Job]
  Web -->|reads/writes| DB[(Postgres)]
\`\`\`

Use Mermaid — lowest token cost of mainstream diagram formats and renders
natively on GitHub. Keep the diagram to one screenful; if it grows beyond
that, the architecture probably needs decomposition before the diagram does.

## Modules

| Module | Purpose | README |
|--------|---------|--------|
| `packages/web` | API + UI (Next.js App Router, SSE) | [README](../packages/web/README.md) |
| `packages/worker` | ACP bridge to Claude Code, session lifecycle | [README](../packages/worker/README.md) |

## Constraints

- Workers run as K8s Jobs (not long-lived pods) — see `docs/adr/0003-…`.
- Web ↔ Worker boundary is async-only (Redis queue) — see `docs/adr/0007-…`.

## Derive a current snapshot

For an up-to-date structural map (file tree, symbol-level), run any of:
- `aider --map-tokens 1024` (Aider repo-map, free, in-repo)
- `npx repomix` (full text pack)
- Open the repo on https://deepwiki.com (Cognition, public repos only)
```

### Rules for the hub

- **Intent only.** No "current line counts," no "list of every file," no
  exhaustive dependency graph. Those rot and belong in a derive tool's
  output.
- **Modules table is the spine.** Every module gets one row; the row points
  to its README via a relative link.
- **Constraints reference ADRs.** Don't duplicate the trade-off reasoning —
  link to `docs/adr/NNNN-`. The hub is shorter that way and ADRs stay
  authoritative.
- **One Mermaid diagram, one screen.** If you need more diagrams, they live
  in module READMEs at higher resolution. The hub diagram is the elevator
  pitch.

## Module `README.md` (the spoke)

One per module, lives at the module root (e.g. `packages/web/README.md`,
`src/billing/README.md`). Keep under **~100 lines**.

### Structure

```md
# {Module name}

{One sentence: what this module does in the system.}

## Purpose

{One short paragraph: the role this module plays. Include who depends on it
and what it depends on — at the module level, not the file level.}

## Public interface

{What callers must know to use this module correctly. The list of exported
functions/types is the surface, but include constraints that aren't visible
in the type signature: invariants, ordering, error modes, required config,
performance characteristics.}

## Internal dependencies

{Other modules in this repo that this one calls. Skip third-party deps;
those belong in package.json. One line each: "Calls `packages/worker` to
enqueue jobs.")}

## Tests

{Where the tests live and how to run them. One paragraph max.

- Behavior tests: `src/**/__tests__/*.test.ts` — `pnpm test`
- E2E scenarios: `beat/features/<capability>/` — `pnpm test:e2e`}

## Notes

{Optional. Anything a caller would want to know that doesn't fit above:
known limitations, planned changes, links to related ADRs.}
```

### Vocabulary

Beat does **not** mandate a specific structural vocabulary. Use the words
that fit the codebase:

- **Monorepo / package-oriented codebases** (Nx, Turbo, pnpm workspaces):
  *package*, *layer*, *service* are usually clearer than abstract terms.
- **Domain-oriented codebases** (DDD, hexagonal): bounded context names
  and DDD vocabulary work natively.
- **Framework-native codebases** (Next.js App Router, Rails): use the
  framework's own structure terms.

If precision around testability or refactor seams matters, mattpocock's
LANGUAGE.md (in `mattpocock-skills/skills/engineering/improve-codebase-
architecture/`) defines **Module / Interface / Implementation / Depth /
Seam / Adapter / Leverage / Locality**. These are optional — pull them in
when discussing refactors where precision pays off, not as a baseline.

### Rules for module READMEs

- **Interface is more than the type signature.** Include invariants,
  ordering, error modes, required config. A caller should be able to use the
  module correctly from the README alone.
- **No file lists.** A list of every file in the module is a derive-tool
  job. The README describes the module as a whole.
- **No implementation details that callers don't need.** Internal helpers,
  private types, internal seams — those belong in code, not the README.
- **Cross-link, don't duplicate.** Refer to ADRs and CONTEXT.md by link.
  Don't paste their content into the README.

## When Beat updates these files

| Skill | Trigger | Action |
|-------|---------|--------|
| `/beat:apply` | After implementing tasks that change a module's **public interface** | HARD-GATE prompts user to update that module's README. User may decline. |
| `/beat:apply` | When creating a new module (new directory with its own concerns) | Prompt user to scaffold a README using the structure above |
| `/beat:verify` | Verification dimension | Diff scan: if `apply` touched a module's public interface and its README didn't change in the same change, flag as **WARNING** (advisory). |
| `/beat:design` (Phase 3 only) | When `design.md` describes a module-level architecture change | Suggest updating `beat/ARCHITECTURE.md` if the change affects the modules table, hub diagram, or constraints |

Internal refactors that don't change a module's public interface do not
trigger README updates. Use the **deletion test** as a rule of thumb: if
deleting a function would break callers outside the module, it's part of
the public interface.

## Lazy creation

Like `beat/CONTEXT.md` and `docs/adr/`, Layer 3 files are created lazily:

- `beat/ARCHITECTURE.md` is created the first time `/beat:apply` or
  `/beat:design` confirms the project has multiple modules worth a hub.
- Module READMEs are created the first time a module's public interface is
  touched (by `/beat:apply`) or the first time the module is mentioned in
  the architecture hub.

A small project with one package may never need either file. Beat doesn't
force the structure on projects that don't need it.
