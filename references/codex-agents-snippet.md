# Codex AGENTS.md Snippet for Beat

Codex does not support SessionStart hooks, so the auto-context-injection that Beat provides on Claude Code (`hooks/session-start`) does **not** run on Codex.

To get equivalent behavior, copy the snippet below into the `AGENTS.md` of any project that uses Beat. Codex loads `AGENTS.md` from the project root automatically, so once it's there, every new Codex session in that project picks up the same workflow guidance the Claude Code hook would inject.

## When to install

Install the snippet **per project** (not globally) — it is meant to fire only when a repository actually uses Beat. The Claude Code hook checks for `beat/config.yaml` or `beat/changes/`; on Codex, the equivalent check is "is this snippet present in `AGENTS.md`".

## Snippet

Append this to your project's `AGENTS.md` (create one at the repo root if you don't have it):

```markdown
## Beat Workflow

This project uses the Beat BDD workflow plugin.

After brainstorming or exploration is complete, transition to Beat instead of `writing-plans`:

- Use `/beat:design` to create a change and generate spec artifacts (proposal, gherkin, design.md).
- Use `/beat:plan` to create an execution plan (`tasks.md`) with multi-role review.
- Beat's plan skill invokes `writing-plans` internally when creating tasks.
- Do NOT invoke `writing-plans` directly — Beat orchestrates the full pipeline.

Beat pipeline: `/beat:design` → `/beat:plan` → `/beat:apply` → `/beat:verify` → `/beat:archive`.

Beat maintains three project-level living-doc surfaces (all lazy — created on first use):
- `beat/CONTEXT.md` — domain glossary maintained inline by design/archive
- `docs/adr/` — ADRs gated by hard-to-reverse + surprising + real trade-off
- `beat/ARCHITECTURE.md` + module `README.md` — structure & intent, updated when public interfaces change

If the user asks to build, fix, or change something, guide them through the Beat workflow.
```

## Why not auto-inject globally

Putting this in `~/.codex/AGENTS.md` would force every Codex session — including ones in repos that don't use Beat — to bias toward the Beat workflow. The hook on Claude Code only fires when `beat/config.yaml` or `beat/changes/` exist; the per-project `AGENTS.md` placement preserves that "opt-in by repo state" property.

## Verifying

After adding the snippet, start a fresh Codex session in the project and ask "what's the workflow here?" — the agent should describe the Beat pipeline. If it doesn't, check that `AGENTS.md` is at the repo root and that Codex picked it up (Codex prints loaded `AGENTS.md` paths at session start).
