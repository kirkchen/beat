# Installing Beat on Codex

Beat is published as a Codex plugin **directly from this repository** — no separate marketplace fork or sync step. The repo is structured as a single-plugin Codex marketplace via `.agents/plugins/marketplace.json` at the root, which points at `./plugins/beat/` (a symlink overlay back to the repo root, so Claude Code and Codex share the same source files).

## Install

Step 1 — register this repo as a marketplace (CLI):

```bash
codex plugin marketplace add https://github.com/kirkchen/beat
```

Step 2 — install the `beat` plugin from the marketplace. The current Codex CLI does not have a plugin-install subcommand, so this step happens inside the interactive Codex UI:

1. Launch Codex (`codex`).
2. Open the plugins panel (look for "Plugins" in the menu / palette).
3. Find `Beat` under the `Beat (Kirk Chen)` marketplace and choose Install.
4. Restart Codex.

After install, Beat skills become available as `/beat:design`, `/beat:plan`, `/beat:apply`, `/beat:verify`, `/beat:archive`, etc.

## Per-project AGENTS.md snippet (replaces the SessionStart hook)

Codex doesn't run SessionStart hooks. On Claude Code, [`hooks/session-start`](../hooks/session-start) auto-detects Beat projects (`beat/config.yaml` or `beat/changes/`) and injects "use Beat workflow" guidance. On Codex, do this manually per-project:

1. In any project that uses Beat, open or create `AGENTS.md` at the project root.
2. Append the snippet from [`references/codex-agents-snippet.md`](../references/codex-agents-snippet.md).
3. Restart Codex in that project.

The snippet only fires per-project, mirroring the auto-detection logic of the Claude Code hook.

## Recommended companion: superpowers

Beat skills delegate to `superpowers:brainstorming`, `superpowers:writing-plans`, and `superpowers:test-driven-development`. Install superpowers first to get the full pipeline — it's already in the official `openai-curated` marketplace, so install it from inside the Codex plugins panel.

Without superpowers, Beat falls back to internal checklists — still works, just less rigor.

## Tool name differences

Beat skills are written using Claude Code tool names. On Codex they map to native equivalents — see [`references/tool-mapping.md`](../references/tool-mapping.md). Skills work without modification; the mapping is for human reference only.

## What Codex sees in this repo

Codex reads the marketplace manifest from `.agents/plugins/marketplace.json`. That manifest lists one plugin (`beat`) with `source.path: "./plugins/beat"`. The `plugins/beat/` directory contains symlinks back to the repo root files — `.codex-plugin/`, `skills/`, `assets/`, `references/`, `README.md`, `LICENSE`. So Codex effectively sees:

- `.codex-plugin/plugin.json` — Codex plugin manifest (name, version, interface metadata, icons)
- `skills/` — the skill files
- `assets/` — brand icons referenced by `composerIcon` and `logo`
- `references/` — schemas referenced by skills

The symlink trick keeps a single source of truth at the repo root (where Claude Code reads from via `.claude-plugin/plugin.json`), with no file duplication.

Other repo content (`hooks/`, `docs/`, `tests/`, `beat/`, `CLAUDE.md`, etc.) is not under `plugins/beat/` and is therefore not consumed by Codex.

> **Caveat for Windows users:** symlinks under `plugins/beat/` may not survive a Windows checkout cleanly. If a Windows user reports broken install, the workaround is to replace the symlinks with copies (or maintain a separate marketplace branch with copies).

## Refreshing after upstream changes

When you update beat in this repo, refresh the local Codex copy:

```bash
codex plugin marketplace upgrade kirkchen-beat
```

(For local marketplaces this may be a no-op since Codex reads source paths directly; for git-source installs it re-fetches.)

## Uninstall

Uninstall the plugin from inside the Codex plugins panel, then remove the marketplace:

```bash
codex plugin marketplace remove kirkchen-beat
```
