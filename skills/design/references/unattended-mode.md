# Unattended Mode

How a Beat skill behaves when nobody is watching: an orchestrator (Rhythm) runs each phase as a stage, reads the machine-readable suffix of the handoff block, and decides whether to continue, stop for a human, or loop. The human appears at two points, `/beat:explore` before the change exists and the PR after it, plus every place a skill stops with a decision brief.

## When it applies

Unattended mode is on when the run carries a stage-result nonce — the prompt or environment includes Rhythm's `rhythm-stage-result[<nonce>]` contract (see `references/handoff-report.md`). Without a nonce the skill is interactive and every `AskUserQuestion` below is asked as written.

Never infer unattended mode from anything else (a quiet user, a CI-looking environment, a headless flag). No nonce, no unattended mode.

## The rule

Every point where a skill would use `AskUserQuestion` becomes one of three things:

| Case | What the skill does | Handoff |
|------|---------------------|---------|
| A default exists | Take it. Append one line to `beat/changes/<name>/decisions/assumed.md` (`- <phase>: <what was assumed and why>`). | `blocked-on: none` |
| No default, and the question is a decision that meets the ADR three-condition gate (`references/adr-format.md`) or matches a `sensitive.situations` entry in `beat/config.yaml` | Write a decision brief (`references/decision-brief.md`) to `beat/changes/<name>/decisions/D<n>.md`, print the brief in full immediately before the handoff block, stop. | `blocked-on: decision`, suffix `decision=D<n>` |
| No default, and the blocker is environmental (e2e setup missing, a tool failing, a merge conflict the skill cannot settle) | Stop and say what is blocked in one sentence. | `blocked-on: env` |

"A default exists" means the interactive prompt already names a recommended option, the schema names a default, or the skill text says "suggest a default". Anything the skill would decide by judgement in an interactive session with a nodding user is a default.

`decisions/` is created lazily on first use. `assumed.md` is append-only and read by `/beat:archive` for the PR body. Brief ids increase within a change and are never reused, so re-running a phase after a gate reply does not collide.

## Locked decisions

When the change was dispatched from an issue, the issue body is the specification. A section titled `## 已定案（不要重新討論）` (or `## Decided (do not reopen)`) lists decisions the human already made. `/beat:design` treats every line there as settled: it does not re-ask, re-argue or run the ADR gate on it. Its own Key Decisions that are **not** covered by that section go through the gate as usual and, in unattended mode, become briefs.

After a gate reply the skill writes the answer back: one line under the issue's locked section (when the skill can reach the issue) and into `design.md`'s Key Decisions; an answer that meets the ADR gate becomes an ADR.

## Sensitivity

`beat/config.yaml` `sensitive` (schema: `references/config-schema.md`) names the situations and paths a human wants to see before implementation. `/beat:design` checks every Key Decision and every path the design names against it and reports `sensitive=yes|no` in the suffix; `/beat:apply` checks the diff the same way. The orchestrator gates once after plan when design said yes. A yes that apply discovers later is not a gate — it goes into the PR body's decisions section, because the PR is the next human checkpoint.

## Per-skill mapping

What each interactive prompt becomes. Anything not listed follows the general rule.

| Skill | Prompt | Unattended |
|-------|--------|------------|
| design | "What do you want to build?" (no input) | `env` — a dispatched change always has an input |
| design | Preset question | Default from explore's exit or `standard`; assumed |
| design | ADR gate on a Key Decision | Decision in the locked section: skip. Otherwise all three hold: write the ADR without asking (the gate is the test; asking was the courtesy). |
| design | grilling offer | Call `grilling` and `domain-modeling` directly when a term fails the four-challenge check; they are model-invoked. Never offer `grill-with-docs` (user-invoked, unreachable). |
| plan | Review roles | Use the suggested roles; assumed |
| plan | ADR gate on a rejected alternative | Write it if all three hold |
| plan | Spec-level issue found in review | Brief if it changes what gets built, otherwise fix the task list and note it in assumed |
| apply | Scenario unclear | Brief when the ambiguity changes behaviour; otherwise the reading the gherkin most plainly supports, assumed |
| apply | Design issue found while implementing | Brief if it reverses a Key Decision; otherwise update design.md and note it |
| apply | E2E regression failure, blocker | `env` |
| verify | Shared files, "offer full re-run" | Do not re-run; mention in report |
| archive | Incomplete artifacts / tasks, unverified change | These do not occur in a flow (verify precedes archive); if they do, `env` |
| archive | Capability mapping | Obvious mapping: take it, assumed. Otherwise `env`. |
| archive | Undefined glossary term | Write the one-sentence definition the scenario implies; assumed |
| archive | design.md merge conflict | `env` |
| archive | Last-mile ADR sweep | Skip (it is offer-only) |
| archive | Archive the route | Yes; assumed |
| archive | finishing-a-development-branch | Not invoked. Push the branch and open a ready PR (not draft) with the decisions section — see `skills/archive/SKILL.md` step 7. |

## What never changes

- Hard gates stay hard: TDD, subagent dispatch in verify, worktree isolation. Unattended mode removes questions, not rigour.
- CRITICAL findings are fixed, never deferred.
- Apply never pushes. Archive pushes exactly once, after its commit.
- No merge. The PR is where the human decides.
