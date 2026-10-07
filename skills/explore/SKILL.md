---
name: explore
description: Use when thinking through ideas, investigating problems, or clarifying requirements — before or during a Beat change, or to pick the next node of a route
---

Enter explore mode. Think deeply. Visualize freely. Follow the conversation wherever it goes — and when it settles, say where it goes next.

<decision_boundary>

**Use for:**
- Thinking through ideas, requirements, or problems before committing to a change
- Investigating the codebase to understand architecture, feasibility, or hidden complexity
- Comparing approaches and surfacing risks without producing code
- Picking up a node of a route (`beat/routes/<name>/`) and working out what it needs

**NOT for:**
- Creating spec artifacts as a structured workflow (use `/beat:design`)
- Breaking down tasks (use `/beat:plan`)
- Implementing code (use `/beat:apply`)
- Extracting specs from existing code (use `/beat:distill`)

**Trigger examples:**
- "Let me think through X" / "Investigate why Y happens" / "What are our options for Z?" / "What's next on the slack-ingress route?"
- Should NOT trigger: "design a feature" / "implement this" / "break down the tasks"

</decision_boundary>

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must NEVER write code or implement features. If the user asks you to implement something, remind them to exit explore mode first (e.g., `/beat:design`). You MAY create Beat artifacts (proposals, designs, features, routes, nodes) if the user asks -- that's capturing thinking, not implementing.

**This is a stance, not a workflow.** No fixed steps, no required sequence. The one thing every exploration ends with is a declared exit (see "Ending Exploration") — so the next session, human or agent, knows whether this is a change, a route, or something still blocked.

<HARD-GATE>
Before any response: you MUST invoke superpowers:brainstorming.
Brainstorming structures the ideation process; explore then carries it forward as open-ended conversation.
If unavailable (not installed), proceed directly into the thinking stance — but NEVER skip
because you judged the topic too simple or the user too eager. If the user explicitly asks to
skip brainstorming, say what it would have surfaced (unstated assumptions, alternatives not yet
weighed), confirm once, then continue in the thinking stance.

Before ending: you MUST declare one exit from the table in "Ending Exploration", with the
observable facts that justify it. The user can override the exit; you cannot omit it.
</HARD-GATE>

**Prerequisites** (invoke before proceeding)

| Skill | When | Priority |
|-------|------|----------|
| superpowers:brainstorming | At the start of explore, before any response | MUST |
| mattpocock-skills:research | A `blocked` exit with `kind: research`, when the user wants it run now | OPTIONAL |
| mattpocock-skills:prototype | A `blocked` exit with `kind: prototype`, when `config.yaml` has no `prototype.surface` | OPTIONAL |

If a MUST skill is unavailable (not installed), proceed directly into the thinking stance. Optional skills are offered, never required; without them the node is still created and the user runs it however they like.

## Rationalization Prevention

| Thought | Reality |
|---------|---------|
| "The user wants a quick answer, brainstorming will slow us down" | Brainstorming IS the answer — it surfaces assumptions and alternatives. Quick answers skip the thinking explore is meant to provide. |
| "This topic is too simple for brainstorming" | Simple topics finish brainstorming quickly. The overhead is negligible, but the missed insight is not. |
| "The user said skip brainstorming, so I'll go straight to answers" | Honour it — after naming what brainstorming would have caught. The thinking stance still applies; only the structured ideation is skipped. |
| "I already understand what the user wants" | Understanding the question ≠ exploring the problem space. Brainstorming prevents premature convergence. |
| "The user knows what's next, I don't need to declare an exit" | The next session won't. Fifty-eight of 170 Beat tasks in Rhythm ended at explore with no exit and had to be re-explored. Declare it; it's two lines. |
| "This is clearly one change, I'll call it standard and move on" | Look at what you can list. One module, no open decisions, no new terms → `small`. Two modules or dependent decisions → `too-big`. The size comes from the list, not the gut. |

---

## The Stance

- **Curious, not prescriptive** -- Ask questions that emerge naturally, don't follow a script
- **Open threads, not interrogations** -- Surface multiple directions, let the user follow what resonates
- **Visual** -- Use ASCII diagrams liberally when they'd help clarify thinking
- **Adaptive** -- Follow interesting threads, pivot when new information emerges
- **Patient** -- Don't rush to conclusions, let the shape of the problem emerge
- **Grounded** -- Explore the actual codebase when relevant, don't just theorize

---

## What You Might Do

**Explore the problem space**
- Ask clarifying questions that emerge from what they said
- Challenge assumptions, reframe the problem, find analogies

**Investigate the codebase**
- Map existing architecture relevant to the discussion
- Find integration points, identify patterns, surface hidden complexity

**Compare options**
- Brainstorm multiple approaches, build comparison tables
- Sketch tradeoffs, recommend a path (if asked)

**Visualize**
```
┌─────────────────────────────────────────┐
│     Use ASCII diagrams liberally        │
├─────────────────────────────────────────┤
│   ┌────────┐         ┌────────┐        │
│   │ State  │────────▶│ State  │        │
│   │   A    │         │   B    │        │
│   └────────┘         └────────┘        │
│   System diagrams, state machines,      │
│   data flows, architecture sketches     │
└─────────────────────────────────────────┘
```

**Surface risks and unknowns**
- Identify what could go wrong, find gaps in understanding
- Suggest spikes or investigations

---

## Beat Awareness

At the start, check for existing work:
- Look for `beat/changes/` directories — read their artifacts for context, reference them naturally
- Look for `beat/routes/` directories (schema: `references/route-schema.md`). If the user named a route, or only one route is active, read its `route.md` and `status.yaml`, derive each node's status, and list the **frontier** (nodes whose blockers are all done). Offer to pick one up; a `change` node leads to `/beat:design`, the others to a `blocked`-style exit below.

### When no change exists

Think freely. When insights crystallize, declare the exit (below) rather than drifting.

### When a change exists

If the user mentions a change or one is relevant:

1. Read existing artifacts for context (`proposal.md`, `features/*.feature`, `design.md`, `tasks.md`)
2. Reference them naturally in conversation
3. Offer to capture when decisions are made:

   | Insight Type | Where to Capture |
   |--------------|------------------|
   | New behavior discovered | `features/<name>.feature` |
   | Behavior changed | `features/<name>.feature` |
   | Design decision made | `design.md` |
   | Scope changed | `proposal.md` |
   | New work identified | `tasks.md` |
   | Decision that belongs to the route | `beat/routes/<route>/route.md` under "Decisions so far" |

   When capturing a design decision, run the three-condition ADR gate from `references/adr-format.md` (hard-to-reverse + surprising + real trade-off). If all three hold, offer to record it in `docs/adr/` instead of (or in addition to) `design.md`.

   **Before writing any ADR** (with or without an active change): read `beat/config.yaml` if it exists and apply `rules.adr`; use the project's `docs/adr/TEMPLATE.md` if present, otherwise Beat's template — the "Before writing an ADR" section of `references/adr-format.md` spells this out. Set `source` to the change directory when a change is active, or `/beat:explore` when none is. Explore writes no spec artifacts, but an ADR it writes must still match the project's ADR conventions.

4. The user decides -- offer and move on. Don't pressure. Don't auto-capture.

---

## Ending Exploration

Exploration ends when the user is done or the shape is clear. Before ending, **declare one exit** — state it, give the facts that justify it, and apply the default unless the user objects. Do not ask a question; brainstorming already classified the work, and the exit is that classification carried into Beat. Only ask when the facts below point two ways.

| Exit | Declare it when you can list... | What happens next |
|------|--------------------------------|-------------------|
| `small` | the affected files or directories, all in one module; no decision still open; no new domain term | "Ready for `/beat:design <name>` with preset `minimal`" (or `technical` when there is no behaviour change). Design skips the preset question. |
| `standard` | the affected area fits one change, but one or more decisions are still to be made in design | "Ready for `/beat:design <name>`" — design asks for the preset as usual. |
| `too-big` | more than one module, or decisions that depend on each other, or more than one PR | Create `beat/routes/<name>/` (schema: `references/route-schema.md`): `route.md` from the brainstorming output, `status.yaml` with the nodes you can already name. Next: `/beat:explore <route>` to pick the first frontier node. |
| `blocked` | the one thing that must exist before any of the above can be chosen | Create a node (in the active route, or a one-node route when there is none) with `kind` = `research` (an agent can answer it unattended), `prototype` (a human must look at something — see below), or `decision` (only a human can decide). Next: whoever resolves it, then `/beat:explore` again. |

Map from brainstorming's own classification so the work is sized once, not twice: Spike → `blocked`; Bounded → `small`; Architectural → `standard` or `too-big` by the module count.

**Prototype nodes.** Read `beat/config.yaml`; if `prototype.surface` is set (for example `storybook`), the node says which states or variants to build there and what the human is judging between. Stories built for a prototype may be kept on the branch and merged as real stories once a variant is approved; the implementation code written to make them render stays on a `prototype/<node-id>` branch and is never merged — `/beat:apply` rewrites it from the gherkin under TDD. If `prototype.surface` is absent, offer `mattpocock-skills:prototype` when installed, otherwise ask where the prototype should live.

**Research nodes.** The node carries the question and the sources to consult; the result is a markdown file in the repo at the node's `result` path, never only in chat. Offer `mattpocock-skills:research` when installed.

Then end with the handoff block from `references/handoff-report.md`, `next` being the command above. Exploration may also just stop ("continue later") — still declare the exit so the thread can be picked up.

---

## Guardrails

- **Don't implement** -- Never write application code. Creating Beat artifacts, routes and nodes is fine.
- **Don't fake understanding** -- If something is unclear, dig deeper
- **Don't rush** -- Exploration is thinking time, not task time
- **Don't force structure** -- Let patterns emerge naturally; the exit is declared at the end, not imposed at the start
- **Don't auto-capture** -- Offer to save insights, don't just do it
- **Do declare an exit** -- With the facts that justify it; the user can override
- **Do visualize** -- A good diagram is worth many paragraphs
- **Do explore the codebase** -- Ground discussions in reality
- **Do question assumptions** -- Including the user's and your own
