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
│   └── config-schema.md         # config.yaml format (single source of truth)
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
│   │   ├── features/        # Gherkin feature files (mandatory)
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
                 optional     REQUIRED   optional   optional
```

- **new**: Creates the change container (directory + status.yaml)
- **continue**: Builds one artifact at a time in pipeline order
- **ff**: Creates all artifacts in one go (shortcut for continue × N)
- **apply**: TDD implementation — every scenario must have a test
- **verify**: Dispatches independent subagent to verify against artifacts
- **sync**: Copies features to `beat/features/` as living documentation
- **archive**: Moves change to `beat/changes/archive/`

### Key Concepts

- **status.yaml** is the state machine — schema defined in `references/status-schema.md`. Phase advances forward only. Pipeline entries use inline YAML flow style: `{ status: done }`.
- **config.yaml** is optional project config — schema in `references/config-schema.md`. Controls artifact language, injects project context, and adds per-artifact rules.
- **Gherkin is the only mandatory artifact**. Proposal, design, and tasks can be skipped.
- **verify** and **distill** use independent subagents (Agent tool with `subagent_type: Explore`) to avoid context bias.
- **distill** works in reverse (code → spec) and marks features with `@distilled` tag.

## Dependencies

Requires the [superpowers](https://github.com/anthropics/superpowers) plugin for TDD, brainstorming, and debugging integrations referenced by `continue`, `apply`, and `explore` skills.

## Development Guidelines

### Editing Skills

Each skill is a single SKILL.md file with YAML frontmatter (`name`, `description`) followed by markdown instructions. Skills are self-contained — they reference schemas in `references/` but don't import code.

### Schema Changes

`references/status-schema.md` and `references/config-schema.md` are the single sources of truth. Every skill that reads/writes these files must follow the schemas exactly. If you change a schema, audit all skills that reference it.

### Testing Changes

There is no automated test suite for Beat itself. To test a skill change:
1. Install the plugin in a test project
2. Run the skill command (e.g., `/beat:new`)
3. Verify the skill produces correct artifacts and status.yaml updates
