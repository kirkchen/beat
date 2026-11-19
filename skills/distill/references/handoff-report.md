# Handoff Report

Every Beat skill ends with the same block so that whoever reads the end of a run — a person, a supervisor agent, or a program that called the skill — can decide what happens next without re-running `git status`.

The block contains only facts a command can produce. Judgements ("looks good", "should be fine") never go in it; they belong in the prose above the block.

## Format

```
## Beat Handoff
change: <name>            phase: <phase from status.yaml>   preset: <preset or standard>
commit: <short sha>       branch: <branch>                  dirty: <yes|no>
tasks: <done>/<total>     (omit when the change has no tasks.md)
checks: lint=<exit> test=<exit>   (name the commands; omit a check that was not run)
findings: critical=<n> warning=<n>   (from verify.md; omit when verify has not run)
decision: <D1,D2|none>    sensitive: <yes|no>               diverging: <yes|no>   (omit when there is no change)
next: <one command the reader can paste, e.g. /beat:verify <name>>
blocked-on: <none|decision|env|scope>[ — <one sentence>]
```

Rules:

- `commit`, `branch`, `dirty` come from `git rev-parse --short HEAD`, `git branch --show-current`, `git status --porcelain`. Run them; do not recall them.
- `checks` lists exit codes of commands this run actually executed. Paste the last lines of their output above the block when they failed.
- `next` is one command, or `none` when the pipeline has nothing further to run. If the skill's natural successor needs a decision first (archive waiting on an unverified change, apply paused on a blocker), say so in `blocked-on` and make `next` the command to run once the blocker is cleared (after a decision or an `env` stop, this same command again). `next` never carries `--unattended`: a caller that runs unattended adds the flag to every command it invokes.
- `blocked-on` starts with one token, then an optional sentence after ` — `. Open finding ids may follow `none` in parentheses (`none (open: F3, F7)`).
- Skills that write nothing (`/beat:explore` without artifacts) still emit the block with `commit` and `dirty`, `next` being the declared exit (see `skills/explore/SKILL.md`). Explore also prints one `Exit: <exit> (preset <preset>)` line immediately above the block (preset only for `small` / `standard`); `/beat:to-issue` reads the exit and preset from that line.
- `/beat:to-issue` emits `change: none` and `phase: to-issue`; `next` is `/beat:design <name>`, `/beat:explore <route>` or `none`.

## Field values

The block is Beat's whole output contract: a caller that automates the pipeline reads these fields and nothing else. Field names and values change only with a version bump recorded in `CHANGELOG.md`.

| Field | Values | Who sets it |
|-------|--------|-------------|
| `phase` | the `phase` from status.yaml after this run | every skill |
| `commit` | short sha of HEAD | every skill |
| `blocked-on` | `none` — `next` can run now. `decision` — a human has to decide something first. `env` — an environmental blocker (e2e setup missing, a tool failing, a merge conflict the skill cannot settle). `scope` — the change needs more than one PR. | every skill |
| `decision` | `D<n>`, `D1,D2` (comma, no spaces) / `none` | the ids of the decision briefs this run wrote (`references/decision-brief.md`), each at `beat/changes/<name>/decisions/D<n>.md`. Anything other than `none` goes with `blocked-on: decision` or `scope`. In unattended mode a `decision` or `scope` stop always lists its ids; `blocked-on: decision` beside `decision: none` only happens in an interactive run, where the question was put to the user directly. The plan brief `P1` is never listed here: `sensitive: yes` at the end of an unattended `/beat:plan` is the sign that `decisions/P1.md` exists. |
| `sensitive` | `yes` / `no` | design (artifacts) and apply (diff), against `config.yaml` `sensitive`; recorded in `decisions/sensitive.md`; other skills repeat that file's value, or `no` when it is absent |
| `findings` | `critical=<n> warning=<n>` | verify, and any skill that can read verify.md |
| `diverging` | `yes` / `no` | verify, from its Divergence rule; other skills `no` |
| (the three above) | | A skill that runs on a change but performs none of these checks emits `decision: none`, `sensitive` from `decisions/sensitive.md` (after archive, from the archived directory) and `diverging: no`. Explore, to-issue and setup have no change and omit the line. |
| `next` | one command with its arguments, `/beat:<phase> <name>` | every skill |

When a decision brief was written, print it in full above the block so a person reading the run sees the question without opening a file. The file is the record; where it is printed is a convenience.

## Reading the block

- Find the block by its heading. It is not guaranteed to be the last thing in the run: a skill may print a line after it.
- The keys are the fixed names in the format above. Where a line holds several, a value ends at two or more spaces followed by another key; `next` and `blocked-on` each have a line to themselves and their value runs to the end of it.
- Compare `blocked-on` by its first token, never the whole line: a sentence or `(open: ...)` may follow.
- Present on every block: `change`, `phase`, `commit`, `branch`, `dirty`, `next`, `blocked-on`. Present whenever there is a change: `preset`, and the `decision` / `sensitive` / `diverging` line. `tasks`, `checks` and `findings` are omitted as the format says, so a missing `findings` means verify has not run, not zero findings.
