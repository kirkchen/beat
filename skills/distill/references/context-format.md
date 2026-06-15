<!--
Adapted from mattpocock/skills (MIT License).
Original: skills/engineering/grill-with-docs/CONTEXT-FORMAT.md
Copyright (c) 2026 Matt Pocock
-->

# CONTEXT.md Format

The single source of truth for the `beat/CONTEXT.md` glossary format.

`beat/CONTEXT.md` is **Layer 1 living documentation** — the project's domain
glossary. It is **created lazily** (only when the first term is resolved) and
maintained inline by `/beat:design`, `/beat:distill`, and `/beat:archive`.

## Contents

- [What goes in CONTEXT.md](#what-goes-in-contextmd)
- [What does NOT go in CONTEXT.md](#what-does-not-go-in-contextmd)
- [Structure](#structure)
- [Rules](#rules)
- [Path](#path)
- [When to update](#when-to-update)
- [The four challenges (used by `/beat:design`, adapted by `/beat:distill`)](#the-four-challenges-used-by-beatdesign-adapted-by-beatdistill)
- [Optional grilling](#optional-grilling)

## What goes in CONTEXT.md

A glossary, and nothing else.

- Domain terms specific to **this project**
- The canonical word when multiple synonyms exist (with the rejected ones listed
  as aliases to avoid)
- Relationships between terms (cardinality where obvious)
- Flagged ambiguities that came up and how they were resolved

## What does NOT go in CONTEXT.md

- Implementation details (code paths, function names, framework choices)
- Spec content (those belong in `proposal.md` / `design.md` / `features/`)
- General programming concepts (timeout, retry, error handling — only project-
  specific terms belong, even if the project uses them extensively)
- ADR-shaped decisions (those belong in `docs/adr/`)
- Architecture descriptions (those belong in `beat/ARCHITECTURE.md`)

Treating `CONTEXT.md` as a scratch pad is the fastest way to make it untrustworthy.

## Structure

```md
# {Project Name}

{One or two sentences: what this project is and the domain it operates in.}

## Language

**Run**:
A single ACP session that executes one prompt to completion.
_Avoid_: execution, invocation

**Task**:
A topic-bound workspace that owns one git branch and a sequence of Runs.
_Avoid_: job, work item, ticket

**Capability**:
A user-facing area of behavior, used to organise feature files under
`beat/features/<capability>/`.
_Avoid_: module, package, feature group

## Relationships

- A **Task** owns one or more **Runs** (sequential, never parallel)
- A **Run** belongs to exactly one **Task**
- A **Capability** groups multiple feature files describing related behaviour

## Example dialogue

> **Dev:** "When a user submits a prompt, do we create a new Run or extend the current Task?"
> **Domain expert:** "If the topic stays the same, extend the Task with a new Run. Topic change = new Task."

## Flagged ambiguities

- "job" was used to mean both **Run** (ACP session) and the underlying K8s
  workload — resolved: a **Run** is the user-facing unit; the K8s workload is
  an internal implementation detail and not part of the domain vocabulary.
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the
  best one and list the others as aliases to avoid. Indecision is contagious.
- **Flag conflicts explicitly.** If a term is used ambiguously in the codebase
  or in conversation, call it out under `Flagged ambiguities` with a clear
  resolution.
- **Keep definitions tight.** One sentence max. Define what the term IS, not
  what it does or how it's implemented.
- **Show relationships.** Use bold term names and express cardinality where it
  is obvious (one-to-one, one-to-many, etc).
- **Project-specific terms only.** General programming concepts don't belong
  even if the project uses them extensively. Before adding a term ask: would a
  new joiner be confused by this word *because of this project*, or because of
  programming in general? Only the former belongs.
- **Group under subheadings** when natural clusters emerge (e.g. `## Execution`,
  `## Persistence`). If all terms belong to one cohesive area, a flat list is
  fine.
- **Write an example dialogue.** A short exchange that demonstrates how the
  terms interact naturally — this clarifies boundaries between related concepts
  better than definitions alone.

## Path

- Default location: `<project-root>/beat/CONTEXT.md`
- This keeps `CONTEXT.md` co-located with Beat's other artifacts under `beat/`
- Single glossary per project — multi-context (DDD bounded contexts) is not
  supported in this iteration

## When to update

`CONTEXT.md` is touched inline as terms resolve — not batched.

| Skill | Trigger |
|-------|---------|
| `/beat:design` | Before writing gherkin: scan four challenges (see below) |
| `/beat:design` | Within scenario writing: every bolded term in a scenario must exist in the glossary; new term → add inline |
| `/beat:distill` | Before writing feature files: glossary check — terms recovered from code must be defined before scenarios use them (four challenges adapted: the code, not user intent, is the source) |
| `/beat:archive` | Before sync: scan `features/*.feature` for bolded terms not in the glossary; prompt to add |

## The four challenges (used by `/beat:design`, adapted by `/beat:distill`)

When a scenario or description is being written, the design skill checks for
these four signals and updates `CONTEXT.md` inline as they fire. `/beat:distill`
adapts the same four challenges with the code (not user intent) as the source —
see the distill skill for the adapted wording.

1. **Challenge against the glossary** — the user uses a term that conflicts
   with an existing entry. Call it out: *"Your glossary defines X as A, but
   you seem to mean B — which is it?"* Update the entry or reject the new
   usage.

2. **Sharpen fuzzy language** — the user uses a vague or overloaded term.
   Propose a precise canonical term: *"You're saying 'account' — do you mean
   the Customer or the User? Those are different concepts here."* Add the
   canonical term, list the overloaded one as `_Avoid_`.

3. **Stress-test with concrete scenarios** — when domain relationships are
   being discussed, invent edge cases that probe the boundaries: *"What
   happens when a Task is mid-Run and the user starts a Run on a different
   topic?"* Force the boundary to be named.

4. **Cross-reference with code** — when the user states how something works,
   check whether the code agrees. If they diverge, surface it: *"Your code
   cancels entire Orders, but you just said partial cancellation is possible —
   which is right?"* Decide which is the source of truth, update the loser.

## Optional grilling

If `grill-with-docs` (from `mattpocock-skills`) is installed and the
ambiguity is complex enough that a full grilling session is warranted,
`/beat:design` may offer to invoke it. The choice is the user's — if they
decline, or the skill is not installed, proceed with the four challenges
inline. Beat never hard-requires grill-with-docs.
