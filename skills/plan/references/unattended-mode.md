# Unattended Mode

How a Beat skill behaves when nobody can answer during the run: a caller (a script, a CI job, an orchestrator) invokes each phase, reads the handoff block (`references/handoff-report.md`), and decides whether to continue, stop for a human, or loop. The human appears at two points, `/beat:explore` before the change exists and the PR after it, plus every place a skill stops with a decision brief.

## When it applies

Unattended mode is on when the invocation carries `--unattended` among the skill's arguments (`/beat:apply <name> --unattended`, `/beat:apply fix-from-verify --unattended`). The flag is not part of the input: take it out before reading the rest as a change name, an issue or a description. The caller sets it, because only the caller knows whether someone can answer. Without it the skill is interactive and every `AskUserQuestion` below is asked as written. Once on, it stays on for every later turn of that phase in the same session, so a reply sent into the resumed session does not have to repeat it. A new session starts interactive: every invocation that opens one carries the flag again, and since the handoff `next` never includes it, the caller adds it.

Never infer unattended mode from anything else (a quiet user, a CI-looking environment, a headless flag, a missing question tool). The mode also lets `/beat:archive` push and open a pull request, and that takes an explicit word from the caller. No `--unattended`, no unattended mode.

## The rule

Every point where a skill would use `AskUserQuestion` becomes one of four things:

| Case | What the skill does | Handoff |
|------|---------------------|---------|
| A default exists ("What counts as a default" below) | Take it. Append one line to `beat/changes/<name>/decisions/assumed.md` (`- <phase>: <what was assumed and why>`; a judgement call starts `- <phase>: judgement: …`). | `blocked-on: none` |
| No default, and the question is a decision that meets the ADR three-condition gate (`references/adr-format.md`), matches a `sensitive.situations` entry in `beat/config.yaml`, or is on the brief list below | Write a decision brief (`references/decision-brief.md`) to `beat/changes/<name>/decisions/D<n>.md` for **each** such decision found in this phase, then print every brief in full above the handoff block and stop. | `blocked-on: decision`, `decision: D<n>` or `decision: D1,D2` |
| No default, and the blocker is environmental (e2e setup missing, a tool failing, a merge conflict the skill cannot settle) | Stop and say what is blocked in one sentence. | `blocked-on: env — <the sentence>` |
| The change turns out to need more than one PR (apply discovers a second module, a migration that must land first, a split the plan did not foresee) | Write a brief with two options (shrink this change and open a new issue for the rest / stop and re-explore as a route), stop. | `blocked-on: scope`, `decision: D<n>` |

### What counts as a default

A default is an answer that something other than this run already names. Check in this order and stop at the first that applies:

1. **The input states it.** The issue body or the prompt names the value: the preset on the `出口：` / `Exit:` line, a locked decision, an option the caller wrote out. Take it as given. It is the human's answer, not an assumption, so the value itself is not recorded in `assumed.md`.
2. **Beat names it.** The interactive prompt marks a recommended option, the schema names a default, the skill text says "suggest a default", or the per-skill table below has a row for it. Take it and record it.
3. **Nothing names it, and it is not on the brief list.** Take the plainest reading and record it as `judgement:`, so whoever reads the PR can tell a call this run made from a default Beat named.

**The brief list.** A choice that nothing names is a brief, never a judgement, when it does any of these, whether or not it meets the ADR gate:

- changes observable behaviour: a scenario's Then, an error a caller sees, a default value a user gets;
- changes a public interface, a schema, a stored format or a dependency;
- drops or relaxes a check: a skipped artifact, a weaker preset, a test left out, a review role removed.

A per-skill row never overrides the brief list. A row names what to do with the ordinary case of its prompt; when the choice in front of the run does something on the list (apply finds it needs a new dependency or a schema change that no Key Decision covers), it is a brief, whatever the row says.

"A nodding user would agree" is not a test; the list is.

**A stated value is never replaced.** When the facts seem to contradict a value the input states, the run does not substitute its own. A stated value is not a choice this run makes, so the brief list does not apply to it as such: `preset minimal` on the issue is weaker than `standard` and is still followed. Write a brief, with the stated value as option A, only when following it drops a check this change itself needs (the issue says `preset technical`, which skips gherkin, and the change has user-visible behaviour). Otherwise follow it and add one line to `assumed.md` saying what the run would have chosen and why (`- <phase>: followed <value> from the issue; would have chosen <other> because …`). A human wrote that value; only a human changes it. This covers anything the input names, a dependency, a schema or an interface included: the issue body is the human's spec, so whoever can edit it decides these without a brief. Who may edit an issue before it is dispatched is the caller's to control, not this run's.

**Companion skills ask too.** `superpowers:brainstorming` (design) asks questions and wants the description approved; TDD asks about test placement; `grilling` asks one question at a time. In unattended mode every one of these is answered from the issue body: the locked-decisions section **is** the approval, the user stories are the description, and an open question that the body does not answer is a decision brief, not a turn that ends on a question. A run that ends on a question has no handoff block, and the caller has nothing to act on.

**Which change.** The caller may pass the issue instead of the change name. A phase finds its change by `status.yaml` `issue` (schema: `references/status-schema.md`): the directory under `beat/changes/` (not `archive/`) whose `issue` equals the issue in the prompt. `/beat:design` writes that field when it creates the change from an issue, so later phases find it however many other changes are lying around (`validate-beat.mjs` warns about leftovers but never blocks on them). When no directory matches (the change predates the field, or the prompt names no issue), fall back to the single directory that is not `archive/`; when that still leaves more than one candidate, or two directories claim the same issue, stop with `blocked-on: env` naming them.

`decisions/` is created lazily on first use. `assumed.md` is append-only and read by `/beat:archive` for the PR body. `sensitive.md` holds the last sensitivity verdict (`yes|no`, which situation or path, which phase) so a later phase in a new session can repeat it. Brief ids increase within a change and are never reused, so re-running a phase after a gate reply does not collide.

**After a reply** the caller invokes the same phase again (the handoff `next`) with the human's answer in the prompt, or sends the answer into the resumed session (`references/decision-brief.md` "After the answer"; Beat prescribes no reply syntax). The skill records each answer in its brief file, acts on it, and does not run the gate on that decision again. After an `env` stop the caller invokes the phase again once the blocker is cleared, and the skill resumes from what is on disk. A reply to a diverging verify is passed to the next `/beat:apply fix-from-verify`, which takes it as its first work item.

## Locked decisions

When the change was dispatched from an issue, the issue body is the specification. A section titled `## 已定案（不要重新討論）` (or `## Decided (do not reopen)`) lists decisions the human already made. `/beat:design` treats every line there as settled: it does not re-ask, re-argue or run the ADR gate on it. Its own Key Decisions that are **not** covered by that section go through the gate as usual and, in unattended mode, become briefs.

After a gate reply the skill writes the answer into `design.md`'s Key Decisions; an answer that meets the ADR gate becomes an ADR. The skill never edits the issue body (`references/decision-brief.md` "After the answer").

## Sensitivity

`beat/config.yaml` `sensitive` (schema: `references/config-schema.md`) names the situations and paths a human wants to see before implementation. `/beat:design` checks every Key Decision and every path the design names against it and reports `sensitive: yes|no` in the handoff block; `/beat:apply` checks the diff the same way. The check runs in every mode, since it describes the change, not the run. Beat reports the verdict and never stops on it: what to do with a `yes` is the caller's decision (the usual choice is to show a human the plan before apply, which is what the plan brief is for). A yes that apply discovers later goes into the PR body's decisions section, because the PR is the next human checkpoint.

## Per-skill mapping

What each interactive prompt becomes. Anything not listed follows the general rule.

| Skill | Prompt | Unattended |
|-------|--------|------------|
| design | "What do you want to build?" (no input) | `env` — a dispatched change always has an input |
| design | Preset question | The preset named in the issue body (`出口：small（preset minimal）` from `/beat:to-issue`): taken as given, never replaced by another preset ("A stated value is never replaced" above). No preset named: `standard`; assumed |
| design | ADR gate on a Key Decision | Decision in the locked section: skip the gate, copy as given. Otherwise all three hold: it is a decision the human has not made — brief, stop. The ADR is written after the reply, from the answer. |
| design | grilling offer | Call `grilling` and `domain-modeling` directly when a term fails the four-challenge check; they are model-invoked. Never offer `grill-with-docs` (user-invoked, unreachable). |
| plan | Review roles | Use the suggested roles; assumed |
| plan | Sensitivity | Read `decisions/sensitive.md`; when `yes`, write the plan brief (`references/decision-brief.md` "Plan brief") to `decisions/P1.md` and print it above the handoff block |
| plan | ADR gate on a rejected alternative | Write it if all three hold |
| plan | Spec-level issue found in review | Brief if it changes what gets built, otherwise fix the task list and note it in assumed |
| apply | Scenario unclear | Brief when the ambiguity changes behaviour; otherwise the reading the gherkin most plainly supports, assumed |
| apply | Design issue found while implementing | Brief if it reverses a Key Decision or does something on the brief list (a new dependency, a schema or public-interface change, changed behaviour); otherwise update design.md and note it |
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
- Apply never pushes on its own. A caller may push between runs; that is the caller's choice, not Beat's. Archive is the only phase that opens a PR.
- No merge. The PR is where the human decides.
