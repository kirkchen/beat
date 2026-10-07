# Handoff Report

Every Beat skill ends with the same block so that whoever reads the end of a run — a person, a supervisor agent, or Rhythm — can decide what happens next without re-running `git status`.

The block contains only facts a command can produce. Judgements ("looks good", "should be fine") never go in it; they belong in the prose above the block.

## Format

```
## Beat Handoff
change: <name>            phase: <phase from status.yaml>   preset: <preset or standard>
commit: <short sha>       branch: <branch>                  dirty: <yes|no>
tasks: <done>/<total>     (omit when the change has no tasks.md)
checks: lint=<exit> test=<exit>   (name the commands; omit a check that was not run)
findings: critical=<n> warning=<n>   (from verify.md; omit when verify has not run)
next: <one command the reader can paste, e.g. /beat:verify <name>>
blocked-on: none | <one sentence>
```

Rules:

- `commit`, `branch`, `dirty` come from `git rev-parse --short HEAD`, `git branch --show-current`, `git status --porcelain`. Run them; do not recall them.
- `checks` lists exit codes of commands this run actually executed. Paste the last lines of their output above the block when they failed.
- `next` is one command. If the skill's natural successor needs a decision first (archive waiting on an unverified change, apply paused on a blocker), say so in `blocked-on` and make `next` the command that resolves it.
- Skills that write nothing (`/beat:explore` without artifacts) still emit the block with `commit` and `dirty`, `next` being the declared exit (see `skills/explore/SKILL.md`).

## Machine-readable suffix (optional)

When the environment injects a nonce for a stage result (Rhythm's `rhythm-stage-result[{{nonce}}]: k=v ...` contract), append it as the very last non-empty line of the run, after the block, carrying the same facts:

```
rhythm-stage-result[<nonce>]: phase=verify sha=3f9c1a2 critical=0 warning=2 next=/beat:archive
```

Without a nonce, emit nothing extra. Never invent a nonce.

## Why

Across 170 Beat tasks in Rhythm, each task needed a median of 12 human messages, and a large share of them were a supervisor relaying facts the skill already had: "apply passed spot-check, 12/12 tasks, proceed to verify". A fixed block makes that relay unnecessary when a supervisor is present, and gives Codex sessions (no supervisor, no hook) the same ending.
