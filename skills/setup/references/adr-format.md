<!--
Adapted from mattpocock/skills (MIT License).
Original: skills/engineering/grill-with-docs/ADR-FORMAT.md
Copyright (c) 2026 Matt Pocock
-->

# ADR Format

The single source of truth for Architectural Decision Records used by Beat.

ADRs live in `docs/adr/` (at the project root) and use sequential numbering:
`0001-slug.md`, `0002-slug.md`, etc.

Create the `docs/adr/` directory **lazily** — only when the first ADR is added.

## Contents

- [Template](#template)
- [Optional sections](#optional-sections)
- [Numbering](#numbering)
- [When to offer an ADR — the three-condition gate](#when-to-offer-an-adr--the-three-condition-gate)
- [What qualifies (when all three conditions hold)](#what-qualifies-when-all-three-conditions-hold)
- [What does NOT qualify](#what-does-not-qualify)
- [When Beat offers an ADR](#when-beat-offers-an-adr)
- [Relationship with `design.md`](#relationship-with-designmd)

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

That's it. An ADR can be a single paragraph. The value is in recording *that*
a decision was made and *why* — not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need any of them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`)
  — useful when decisions are revisited
- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need to be called out

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one.
Slugs are kebab-case and describe the decision (`0007-use-server-sent-events.md`,
not `0007-sse.md`).

## When to offer an ADR — the three-condition gate

**All three must be true.** If any one is missing, skip the ADR.

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
   If you can swap this decision in an afternoon, it's not ADR-worthy.

2. **Surprising without context** — a future reader will look at the code and
   wonder *"why on earth did they do it this way?"*. Obvious decisions don't
   need recording.

3. **The result of a real trade-off** — there were genuine alternatives and you
   picked one for specific reasons. If there was no real alternative, there's
   nothing to record beyond "we did the obvious thing."

The gate's job is to keep the ADR folder readable. If every decision gets an
ADR, no one reads ADRs.

## What qualifies (when all three conditions hold)

- **Architectural shape.** "We're using a monorepo." "The write model is
  event-sourced; the read model is projected into Postgres."
- **Integration patterns between contexts.** "Service A and Service B
  communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth
  provider, deployment target. Not every library — only the ones that would
  take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer
  service; other services reference it by ID only." The explicit no's are as
  valuable as the yes's.
- **Deliberate deviations from the obvious path.** "We're using manual SQL
  instead of an ORM because X." Anything where a reasonable reader would
  assume the opposite. These stop the next engineer from "fixing" something
  that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of
  compliance requirements." "Response times must be under 200ms because of
  the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you
  considered GraphQL and picked REST for subtle reasons, record it —
  otherwise someone will suggest GraphQL again in six months.

## What does NOT qualify

- **Easily reversible choices.** Library version bumps, naming conventions
  (capture those in a style guide), folder layout tweaks.
- **Industry-default picks with no real alternatives considered.** "We use
  Postgres" is only an ADR if there was a real alternative (e.g., we
  evaluated DynamoDB and rejected it for X reason).
- **Per-change implementation decisions.** Those live in the change's
  `design.md` and get archived with the change. ADRs are for cross-change,
  long-lived decisions.

## When Beat offers an ADR

Beat skills surface ADR candidates at four trigger points:

| Skill | Trigger |
|-------|---------|
| `/beat:design` | While writing `design.md`, when a section describes a hard-to-reverse + surprising + real-trade-off decision |
| `/beat:plan` | When the multi-role review rejects an alternative with a load-bearing reason that future reviewers shouldn't have to re-litigate |
| `/beat:apply` | When implementation forces a hard-to-reverse choice not anticipated in `design.md` |
| `/beat:archive` | Last-mile sweep — if zero ADRs were written for this change, prompt once: "Anything from this change worth recording as an ADR?" |

At each trigger, run the three-condition gate. If all three hold, offer to
write the ADR inline and continue. If the user declines, note the skip and
move on — Beat never blocks on ADR creation.

## Relationship with `design.md`

`design.md` lives inside a change (`beat/changes/<name>/design.md`) and gets
archived when the change completes. It captures **change-specific** decisions
that don't outlive the change.

ADRs in `docs/adr/` capture **cross-change** decisions that outlive any single
change. When a section of `design.md` describes a decision that meets all
three gate conditions, it's a candidate to be lifted out into an ADR.

A useful rule of thumb: if a future change would need to re-read this
decision to know how to proceed, it's an ADR. If it's only relevant to *this*
change, it stays in `design.md`.
