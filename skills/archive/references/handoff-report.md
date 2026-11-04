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

When the run carries a stage-result nonce (Rhythm's `rhythm-stage-result[{{nonce}}]: k=v ...` contract), append it as the very last non-empty line of the run, after the block. The nonce also switches the skill into unattended mode (`references/unattended-mode.md`).

```
rhythm-stage-result[<nonce>]: phase=verify sha=3f9c1a2 blocked-on=none decision=none sensitive=no critical=0 warning=2 diverging=no next=/beat:archive
```

Keys, every value a single token with no whitespace (the orchestrator splits on spaces and matches values by equality):

| Key | Values | Who sets it |
|-----|--------|-------------|
| `phase` | the `phase` from status.yaml after this run | every skill |
| `sha` | short sha of HEAD | every skill |
| `blocked-on` | `none` / `decision` / `env` | every skill; `decision` when a brief was written, `env` for an environmental blocker, matching the block's `blocked-on` line |
| `decision` | `D<n>` / `none` | the brief's id when `blocked-on=decision` |
| `sensitive` | `yes` / `no` | design (artifacts) and apply (diff), against `config.yaml` `sensitive`; other skills repeat the last recorded value or `no` |
| `critical`, `warning` | integers | verify, and any skill that can read verify.md |
| `diverging` | `yes` / `no` | verify, from its Divergence rule; other skills `no` |
| `next` | one command, no spaces inside arguments beyond the change name | every skill |

The block's prose line `blocked-on:` keeps its sentence; the suffix carries the token. When a decision brief was written, print the brief in full immediately above the block so that the run's last message is "brief + block + suffix".

Without a nonce, emit nothing extra. Never invent a nonce.
