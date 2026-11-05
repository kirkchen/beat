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
| No default, and the question is a decision that meets the ADR three-condition gate (`references/adr-format.md`) or matches a `sensitive.situations` entry in `beat/config.yaml` | Write a decision brief (`references/decision-brief.md`) to `beat/changes/<name>/decisions/D<n>.md` for **each** such decision found in this phase, then print every brief in full as the last thing before the handoff block and stop. The brief is the phase's final action: no commit, lint or tool call after it, because the orchestrator reads the run's last message. | `blocked-on: decision`, suffix `decision=D<n>` or `decision=D1,D2` |
| No default, and the blocker is environmental (e2e setup missing, a tool failing, a merge conflict the skill cannot settle) | Stop and say what is blocked in one sentence. | `blocked-on: env` |
| The change turns out to need more than one PR (apply discovers a second module, a migration that must land first, a split the plan did not foresee) | Write a brief with two options (shrink this change and open a new issue for the rest / stop and re-explore as a route), stop. | `blocked-on: scope` |

"A default exists" means the interactive prompt already names a recommended option, the schema names a default, or the skill text says "suggest a default". Anything the skill would decide by judgement in an interactive session with a nodding user is a default.

**Companion skills ask too.** `superpowers:brainstorming` (design) asks questions and wants the description approved; TDD asks about test placement; `grilling` asks one question at a time. In unattended mode every one of these is answered from the issue body: the locked-decisions section **is** the approval, the user stories are the description, and an open question that the body does not answer is a decision brief, not a turn that ends on a question. A run that ends on a question has no stage result and the orchestrator treats it as unreadable.

**Which change.** The orchestrator passes the issue, not the change name. A phase finds its change by `status.yaml` `issue` (schema: `references/status-schema.md`): the directory under `beat/changes/` (not `archive/`) whose `issue` equals the issue in the prompt. `/beat:design` writes that field when it creates the change from an issue, so later phases find it however many other changes are lying around (`validate-beat.mjs` warns about leftovers but never blocks on them). When no directory matches (the change predates the field, or the prompt names no issue), fall back to the single directory that is not `archive/`; when that still leaves more than one candidate, or two directories claim the same issue, stop with `blocked-on: env` naming them.

`decisions/` is created lazily on first use. `assumed.md` is append-only and read by `/beat:archive` for the PR body. `sensitive.md` holds the last sensitivity verdict (`yes|no`, which situation or path, which phase) so a later phase in a new session can repeat it. Brief ids increase within a change and are never reused, so re-running a phase after a gate reply does not collide.

**After a gate reply** the same phase resumes in the same session; the reply is in the prompt (`D1: A` per decision, `/answer <text>` for a plan or divergence brief, `/resume` after a failure). The skill records each answer in its brief file, acts on it, and does not run the gate on that decision again. For a sensitivity confirmation the orchestrator moves on to apply; for a divergence reply it moves to fix-from-verify with the reply as the first work item.

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
| design | Preset question | The preset named in the issue body (`出口：small（preset minimal）` from `/beat:to-issue`), else `standard`; assumed |
| design | ADR gate on a Key Decision | Decision in the locked section: skip the gate, copy as given. Otherwise all three hold: it is a decision the human has not made — brief, stop. The ADR is written after the reply, from the answer. |
| design | grilling offer | Call `grilling` and `domain-modeling` directly when a term fails the four-challenge check; they are model-invoked. Never offer `grill-with-docs` (user-invoked, unreachable). |
| plan | Review roles | Use the suggested roles; assumed |
| plan | Sensitivity | Read `decisions/sensitive.md`; when `yes`, print the plan brief (`references/decision-brief.md` "Plan brief") as the last action so the orchestrator can gate on it |
| plan | ADR gate on a rejected alternative | Write it if all three hold |
| plan | Spec-level issue found in review | Brief if it changes what gets built, otherwise fix the task list and note it in assumed |
| apply | Scenario unclear | Brief when the ambiguity changes behaviour; otherwise the reading the gherkin most plainly supports, assumed |
| apply | Design issue found while implementing | Brief if it reverses a Key Decision; otherwise update design.md and note it |
| apply | E2E regression failure, blocker | `env` |
| apply | The change needs a second PR | `scope` brief |
| verify | Shared files, "offer full re-run" | Do not re-run; mention in report |
| archive | Incomplete artifacts / tasks, unverified change | These do not occur in a flow (verify precedes archive); if they do, `env` |
| archive | Capability mapping | Obvious mapping: take it, assumed. Otherwise `env`. |
| archive | Undefined glossary term | Write the one-sentence definition the scenario implies; assumed |
| archive | design.md merge conflict | `env` |
| archive | Last-mile ADR sweep | Skip (it is offer-only) |
| archive | Archive the route | Yes; assumed |
| archive | finishing-a-development-branch | Not invoked. Open a ready PR (not draft) with the decisions section and `Closes #<n>` — see `skills/archive/SKILL.md` step 7. |
| archive | Re-entry after an `env` stop | Resume from what exists: directory already under `archive/` → skip the move; commit already made → skip; PR already open → report it. Never redo a step whose result is on disk. |

## What never changes

- Hard gates stay hard: TDD, subagent dispatch in verify, worktree isolation. Unattended mode removes questions, not rigour.
- CRITICAL findings are fixed, never deferred.
- Apply never pushes on its own; under an orchestrator the worker may push after every run, which is its contract, not Beat's. Archive is the only phase that opens a PR.
- No merge. The PR is where the human decides.
