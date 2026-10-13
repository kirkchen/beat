English | [繁體中文](DESIGN_PRINCIPLES.zh-TW.md)

# Beat Design Principles

This document explains *why* Beat works the way it does. Each section states a principle, what we chose instead, and what that trade-off costs. Consult it when evaluating changes that affect multiple skills or the overall direction.

## Audience

This document is for Beat contributors and power users who want to understand the reasoning behind design decisions. If you're new to Beat, start with the [README](../README.md).

---

## Behavior Over Implementation

Gherkin scenarios describe **what the system does**, not how.

```gherkin
# Good — stable across refactors
Scenario: Monthly billing adjusts for short months

# Bad — breaks when you rename the function
Scenario: calculateNextTransactionDate clamps to last day of month
```

**What we rejected:** Internal implementation details in Gherkin — method signatures, database column names, internal config constants. These couple specs to implementation and break on every refactor.

**What belongs in scenarios:** Observable behavior details — HTTP status codes, response field names, business rule thresholds ("locked after 5 attempts"), user-visible messages. These are the behavior, not implementation leaking through. Scenarios should be specific about *what the system does* (see [feature-writing conventions](../references/feature-writing.md)).

**Trade-off:** Scenarios don't explain *how* something works internally. A developer still needs to read the code or `design.md` for that. We accept this because specs that survive refactors are worth more than specs that document every implementation detail.

## Gherkin as Thinking Tool

The value of writing Gherkin is in **forcing you to articulate behavior before coding**. The `.feature` files are a byproduct of good thinking, not an end goal.

**What we rejected:** Mandatory Gherkin for every change. Purely technical changes (dependency upgrades, tooling, refactoring without behavior change) don't benefit from Gherkin. Forcing it turns thinking into paperwork.

**Trade-off:** Users must judge "does this change have behavior?" That judgment call is sometimes wrong. We accept this because the alternative — Gherkin for everything — trains people to write bad scenarios just to satisfy the pipeline.

## File System as State

All state lives in files: `status.yaml`, artifact documents, directory structure. No database, no external service.

**What we rejected:** A CLI tool with its own database, a web dashboard, integration with project management tools (Jira, Linear, etc.).

**Trade-off:** No centralized view across projects. No real-time collaboration on changes. No automatic notifications. We accept this because file-based state is inspectable (`cat`), debuggable (`git diff`), version-controllable (`git log`), and requires zero infrastructure.

## Forward-Only Pipeline

Phases advance forward only: `new → proposal → gherkin → design → tasks → implement → verify → sync → archive`. You cannot rewind.

**What we rejected:** Bidirectional phase transitions ("go back to design and fix the spec"). This creates ambiguous state — is the implementation stale now? Are the tasks still valid? Which version of the spec was verified?

**Trade-off:** If you discover a spec problem during implementation, you update the artifact in-place and continue forward instead of "going back." This feels unnatural at first. We accept this because forward-only eliminates an entire class of state confusion, and updating an artifact is the same action regardless of which phase you're in.

Forward-only is about the `phase` of one change. Two loops sit around it without rewinding anything: `verify` writes findings to `verify.md` and `apply fix-from-verify` works through them (the phase stays `verify`); and `explore` can end in a route or a blocked node, which feeds a *later* change rather than reopening this one.

## Optional is Real

Proposal, design, and tasks are genuinely optional — not "optional but you should always do them."

| Change | Artifacts |
|--------|-----------|
| Fix a typo in error message | `design → gherkin → apply → archive` |
| Add password reset | `design → proposal → gherkin → apply → verify → archive` |
| Payment processing system | `design → proposal → gherkin → design.md → plan → tasks → apply → verify → archive` |

**What we rejected:** A single ceremony level for all changes. Many BDD tools require the full pipeline regardless of scope, which trains users to produce hollow artifacts for small changes.

**Trade-off:** Users must choose their ceremony level. Wrong choices happen — someone skips `plan` on a change that needed it, or writes a proposal for a one-line fix. We accept this because adaptive ceremony builds better judgment over time, while fixed ceremony builds resentment.

## Framework-Agnostic

Beat works with any language, any test framework, any tech stack. Skills describe *what to do* ("write a test for this scenario") and rely on `config.yaml` or auto-detection for *how*.

The annotation convention (`@covered-by`, `@feature`, `@scenario`) uses plain-text comments. No framework dependency, no build step, no AST parsing.

**What we rejected:** Deep integration with specific frameworks (Cucumber step definitions as the only binding, Jest-specific matchers, etc.). This would make Beat powerful for one stack and useless for others.

**Trade-off:** Beat can't leverage framework-specific features (Cucumber's automatic step matching, pytest-bdd's decorator binding). Users in those ecosystems get a simpler annotation system than their framework provides. We accept this because portability across all stacks outweighs power in one stack.

## Independent Verification

`/beat:verify` dispatches a **fresh subagent** with no conversation history. It only sees the artifacts and the code.

**What we rejected:** Having the implementing agent verify its own work. The agent that wrote the code has context bias — it knows what it *intended*, so it's likely to confirm that the code does what was intended rather than what the spec says.

**Trade-off:** Verification is slower (subagent startup, re-reading files) and sometimes catches false positives (the subagent misreads context that would be obvious with history). We accept this because the false negatives from self-verification (missing real gaps) are far more costly than false positives.

## Two Drive Modes

The same pipeline serves two modes:

- **Gherkin-driven** (default): Feature files drive planning, implementation, and verification
- **Proposal-driven** (when gherkin is skipped): Proposal drives planning, risk points drive testing

**What we rejected:** Two separate pipelines. This would double the maintenance surface and create subtle inconsistencies between modes.

**Trade-off:** Skills must check "is this gherkin-driven or proposal-driven?" and branch accordingly, adding conditional logic to several skills. We accept this because one pipeline with a mode switch is simpler to reason about than two parallel pipelines.

---

## Testing Philosophy

### Three Layers, One Principle

| Layer | Purpose | Driven by | Feature binding |
|-------|---------|-----------|-----------------|
| E2E | User journeys end-to-end | `@e2e` scenarios | Step definitions or annotations |
| Behavior | Business logic and rules | `@behavior` scenarios | `@covered-by` / `@scenario` annotations |
| Unit | Technical edge cases | Developer judgment | None |

The principle: **every layer uses the project's own tools**. Beat doesn't introduce test frameworks — it tells the agent what to test and how to link tests back to specs.

### Why Text Annotations, Not Framework Bindings

Most BDD tools use framework-level bindings (Cucumber step definitions, pytest-bdd decorators). Beat uses plain-text comments:

```gherkin
# In .feature — points to test
# @covered-by: src/billing/__tests__/date-calc.test.ts
```

```typescript
// In test — points to feature
// @feature: monthly-billing.feature
// @scenario: Monthly billing adjusts for short months
```

Reasons:
1. **Zero cost** — just comments, no runtime, no build step
2. **Any language** — every language has comments
3. **Machine-checkable** — `/beat:verify` can grep for these
4. **Human-readable** — you see the link without tooling

### Granularity

Scenarios should be at the **behavior level**: a PM, QA engineer, or new team member can understand what the system does without reading code. If only the author understands a scenario, it's too granular.

Unit tests for internal functions don't need Gherkin scenarios. They're implementation details, not specifications.

---

## Pipeline Design

### Why This Order

```
design phase:  [proposal] → gherkin → [design.md]
plan phase:    tasks (with multi-role review)
```

1. **Proposal** answers "why" — without motivation, you build the wrong thing
2. **Gherkin** answers "what" — concrete scenarios force specificity that prose cannot
3. **Design** answers "how" — technical decisions are better when constrained by known behavior
4. **Tasks** answer "in what order" — implementation steps come last because they depend on all of the above

Reversing any pair degrades quality. Writing tasks before knowing behavior produces speculative plans. Writing design before knowing scenarios produces over-engineered architecture.

### Why a Pause Between Design and Plan

Design is creative — defining the problem, exploring behaviors, making technical choices. Plan is structural — decomposing into tasks, reviewing from multiple perspectives, producing a checklist.

The pause between them is intentional. It gives the team a chance to review spec artifacts, challenge assumptions, and align on approach **before** committing to execution.

**What we rejected:** A single "design-and-plan" phase. This works for small changes but collapses two distinct thinking modes (creative exploration vs. structural decomposition) into one, producing worse output for complex changes.

---

### Why Explore Declares an Exit

An exploration that just stops is the most expensive kind: the next session re-explores it. `/beat:explore` therefore ends by naming one of four exits — `small`, `standard`, `too-big`, `blocked` — with the facts that justify it (which files, which modules, which decisions are still open). The user can override the exit; the skill cannot omit it.

**What we rejected:** Asking the user a sizing question. Brainstorming already classified the work (Spike / Bounded / Architectural); explore maps that onto its exits so the work is sized once. A question would be the double prompt the exit was meant to remove.

### Why Routes Hold No State

Work too big for one change gets a route: `beat/routes/<name>/route.md` (destination, decisions so far, what is still fog) and a `status.yaml` of nodes with `blocked_by` edges. Node status is never written — a `change` node is done when its change is archived, a `research` or `prototype` node when its result file exists. The frontier is derived.

**What we rejected:** A route-level state machine. Change `status.yaml` already drifts when agents write it by hand; a second one that must agree with the first would drift faster. Storing only edges leaves nothing to disagree.

**Trade-off:** No dispatcher can read a route and start work in parallel without computing status first. We accept this: a human reading the frontier is cheap, and a tracker-backed DAG (what wayfinder does with issues) is a different product.

### Size Before Ceremony

The artifact preset chosen in design (`full`, `standard`, `minimal`, `technical`) sets the strength of every later phase: `minimal` and `technical` get a test-coverage-only plan review and one verify subagent instead of two. The judgment happens once, at design, on observable facts.

**What we rejected:** A separate "quick" skill. It would duplicate the worktree, config and commit steps of three skills and leave the user to guess which pipeline a change is in. One field in `status.yaml` is cheaper than a second pipeline.

**Trade-off:** An agent could call everything `minimal`. The guard is mechanical, not prose: `/beat:apply` measures the diff after every task and upgrades the preset to `standard` when it crosses the configured thresholds, so the review that was skipped happens at verify.

---

## Converged Enough

`/beat:verify` and `/beat:apply fix-from-verify` form a loop, and a loop that re-opens every severity on every round never ends: each fix touches code the next round reads fresh, and a careful reviewer always finds one more edge case. The loop therefore stops on a severity floor, not on an empty list. Zero open CRITICAL is converged; WARNINGs and SUGGESTIONs ride into archive with the user deciding which to fix. Later rounds admit fewer new findings (no new SUGGESTIONs on round 2, only CRITICALs from round 3), prose findings are capped at SUGGESTION, and a fourth round is never recommended. These rules come from cadence `self-review` and `pr-review`, where they were measured against real review traffic.

**What we rejected:** Requiring a full re-verify before archive. It turned verify into a gate and the gate into a loop — in the first dogfooding run every "final" full pass found a new WARNING in the code the previous fix had just touched. A passing run is converged; a full re-run is something the user asks for.

**Trade-off:** A real defect can hide behind a WARNING that nobody picks up. We accept this: the verification record lists it, the handoff block names it, and `pr-review` on the PR reads the same diff with fresh eyes. What we do not accept is a change that cannot be archived because its reviewer is thorough.

## Scripts Over Prose

A rule that can be decided by reading files is a script, not a paragraph. `validate-beat.mjs` and `lint-features.mjs` settle schema shape, annotation targets, layer tags, stale paths and `.orig` residue; the skills say "run it, fix what it lists" and spend their prose on what a script cannot judge — behavior-level wording, design adherence, whether a decision meets the ADR gate.

**What we rejected:** Keeping those rules as Hard Gates and rationalization tables. Prose enforcement works until the agent is under pressure; a non-zero exit code works every time, and it is the same on Claude Code, Codex and after `npx skills add` because each skill carries its own copy of the scripts.

**Trade-off:** A linter has false positives (a bare decimal in a step, a tag the project invented). Those are warnings, configurable in `config.yaml` `lint`, and the agent decides. Errors are reserved for things that are wrong in every project.

## Companions, Not Owners

Beat invokes other skill sets at fixed points and takes their result back; it never hands them the state. superpowers supplies rigor inside a phase (brainstorming, worktrees, writing-plans, TDD, finishing the branch). mattpocock-skills supplies what a phase cannot produce on its own (a grilling, a research note, a prototype, a retro). Both are optional with inline fallbacks.

**What we rejected:** Letting a companion skill decide the next step. brainstorming wants to hand off to writing-plans, subagent-driven-development wants to finish the branch, writing-plans wants to ask how to execute. Beat's phases answer those questions, so the skills are invoked for their work and the hand-offs are suppressed.

**Trade-off:** Some duplication — a spec self-review in both brainstorming and design, a plan review in both writing-plans and plan. We accept it because the alternative is two owners of one state.

---

## Living Documentation in Layers

Gherkin scenarios describe **behavior**. They do not describe **vocabulary** (what does "Run" mean here?), **decisions** (why did we pick X over Y?), or **structure** (which module owns this?). Beat maintains three additional living-doc surfaces alongside features, each with a different half-life:

- **Layer 1 — `beat/CONTEXT.md`** (vocabulary): one canonical term per concept, opinionated about synonyms. Half-life: very long (domain words change slowly).
- **Layer 2 — `docs/adr/`** (decisions): 1-3 sentence ADRs, gated by hard-to-reverse + surprising + real trade-off. Half-life: indefinite (once written, rarely revisited).
- **Layer 3 — `beat/ARCHITECTURE.md` + module `README.md`** (structure & intent): hub + spokes, hand-written. Half-life: short (must update with code).

**What we rejected:**

- *One mega-doc.* A single ARCHITECTURE-everything.md rots fastest and conflates concerns with different half-lives.
- *Mandatory on day one.* All three are lazy — a small project with one package and no surprising decisions may never need them.
- *Beat-owned ADRs.* ADRs live at `docs/adr/` (industry standard, since Nygard 2011) rather than `beat/adr/`, because the format predates Beat and is read by other tools; Beat only triggers and offers.
- *Deriving intent from code.* Structure can be derived (Aider repo-map, DeepWiki) — intent cannot. Beat hand-writes intent; users pick their own derive tool for structure snapshots.

**Trade-off:** Three surfaces add friction at design / apply / archive. We accept this because Gherkin alone leaves vocabulary, decisions, and structure invisible — and the cost of re-litigating those is higher than the cost of one extra prompt per change.

## Hard Prompt, Soft Action

Layer 3 module README sync is a mandatory mid-implementation trigger in `/beat:apply` — the skill MUST prompt the user when a public interface changes. But the **action** is soft: the user can decline and continue. `/beat:verify` re-surfaces the gap as a WARNING (advisory, never CRITICAL).

This pattern — hard prompt, soft action — applies broadly to all living-doc enforcement. The skills are accountable for raising the question; the user is accountable for the answer.

**What we rejected:** Blocking merge when living docs drift. This makes living-doc maintenance feel like a tax and trains users to silence the gate (find the magic flag, suppress the warning). Instead Beat trusts that an unignorable prompt at the right moment is enough.

**Trade-off:** Disciplined users get gentle reminders; lazy users can ignore them entirely. We accept this because the alternative — gates that block work — is worse: it produces "doc theatre" where everyone games the gate and the docs still rot.

---

## What Beat Is Not

- **Not a test runner** — Beat produces specifications and guides implementation, but doesn't execute tests
- **Not a project management tool** — changes are lightweight containers for thinking, not tickets
- **Not opinionated about architecture** — Beat doesn't care if you use microservices or monoliths
- **Not a replacement for human judgment** — skills guide the agent, the developer decides what's appropriate

---

## Evolving This Document

Update when:
- A design decision affects multiple skills
- Real-world usage reveals an implicit principle that should be explicit
- A principle is found to be wrong or outdated

Changes should be committed with a clear explanation of why the principle was added, modified, or removed.
