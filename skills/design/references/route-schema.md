# Route Schema

Single source of truth for `beat/routes/<route-name>/`. A route is the map for work too big for one change: it names the destination, records the decisions made so far, lists what is still fog, and holds the nodes (research, prototype, decision, change) that get the work there. Adapted from the `wayfinder` skill in mattpocock/skills (MIT; see `NOTICE.md`).

**A route stores nodes and edges, never node status.** Status is derived (see below), so the route cannot drift from the changes that implement it.

## Layout

```
beat/routes/<route-name>/
├── route.md       # the map, for humans
└── status.yaml    # nodes and edges, for skills and the validator
```

## route.md

```markdown
# Route: <title>

## Destination
One paragraph: what is true when this route is done.

## Decisions so far
- YYYY-MM-DD <decision> (node: <node-id>, ADR: docs/adr/NNNN-slug.md if any)

## Not yet specified
- <what is still fog, and which node will clear it>

## Out of scope
- <what this route deliberately does not do>

## Notes
Free-form. Links to proposals, prototypes, research results.
```

`Decisions so far` is the only section that accumulates; everything else is rewritten to describe the route as it is now.

## status.yaml

```yaml
name: <route-name>               # required, kebab-case, matches the directory
created: YYYY-MM-DD              # required
nodes:                           # required, map keyed by node-id (kebab-case)
  <node-id>:
    type: <research|prototype|decision|change>   # required
    title: "<one line>"                           # required
    blocked_by: [<node-id>, ...]                  # optional, node-ids in this route; default []
    change: <change-name>                         # change nodes only — the beat/changes/<name> that implements it
    result: <path>                                # research/prototype/decision nodes — file that records the outcome
    question: "<what this node must answer>"      # research/prototype/decision nodes — required
```

Node types:

| Type | Who does it | Done when |
|------|-------------|-----------|
| `research` | Agent, unattended (AFK) | `result` file exists — a markdown note in the repo |
| `prototype` | Agent builds, human judges (HITL) | `result` file exists and names the approved option |
| `decision` | Human (HITL) | `result` file exists — may be an ADR path |
| `change` | Beat change, six phases | the change's `status.yaml` has `phase: archive` |

## Derived status

Skills and the validator compute status; nothing writes it.

| Node status | Rule |
|-------------|------|
| `done` | per the table above |
| `in-progress` | `change` node whose change directory exists and is not archived; or research/prototype/decision node whose `result` path is listed but the file doesn't exist yet |
| `blocked` | any node in `blocked_by` is not `done` |
| `open` | otherwise |

**Frontier** = nodes that are `open` (every blocker done, not started). `/beat:explore <route>` lists the frontier and offers to start a node.

A change node is linked both ways: the node has `change: <name>`, the change's `status.yaml` has `route: <route-name>/<node-id>`. The validator checks both directions.

## Rules

1. Node ids are stable once referenced from a change's `route` field — rename by adding a new node, never by editing the id.
2. `blocked_by` must not form a cycle; the validator rejects cycles.
3. A route lives in `beat/routes/`, never inside `beat/changes/`. Archiving a change does not move or edit the route; when every node is `done`, `/beat:archive` offers to move the route to `beat/routes/archive/YYYY-MM-DD-<route-name>/`.
4. If Rhythm or another dispatcher ever reads the route to start work in parallel, `status.yaml` is edited only on the main branch by one writer; changes in worktrees only report through their own `status.yaml`.

## Example

```yaml
name: slack-ingress
created: 2026-06-01
nodes:
  storage-options:
    type: research
    title: "How do agent workbenches store large attachments?"
    question: "Which storage model fits attachments up to 50MB without a new service?"
    result: docs/research/2026-06-02-attachment-storage.md
  thread-ux:
    type: prototype
    title: "Thread vs. inline reply presentation"
    question: "Should bot replies open a thread or reply inline?"
    result: docs/prototypes/2026-06-03-thread-ux.md
  dedupe:
    type: change
    title: "Deduplicate repeated HITL button submissions"
    change: slack-thread-dedupe
  attachments:
    type: change
    title: "Accept image attachments in Slack messages"
    blocked_by: [storage-options, thread-ux]
```
