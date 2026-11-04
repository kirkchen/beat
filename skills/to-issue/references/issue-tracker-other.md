# Issue tracker: <tracker name>

Issues for this repo live in `<tracker location>`.

## Conventions

Describe in one paragraph how issues are created, read, labelled and closed here (Jira project and transitions, Linear team, a local `docs/issues/` folder...). Skills follow this paragraph literally.

The status labels in the Vocabulary table map to whatever this tracker uses for state (Jira: transitions). Record the mapping in the paragraph above.

## Vocabulary

| Term | Value | Meaning | Set / cleared by |
|------|-------|---------|------------------|
| Dispatch label | `<dispatch-label>` (default `rhythm-change`) | A command: adding it dispatches the issue, the orchestrator removes it. | Added by a human (or `/beat:to-issue` when the user asks in words); removed by the orchestrator |
| Assignee | `<assignee>` | The account the orchestrator runs as. Required: a missing assignee is rejected. | Set when the issue is created |
| `status/ready` | label | Specified and waiting for dispatch. | Set by `/beat:to-issue`; cleared by the orchestrator on dispatch |
| `status/running` | label | A run is working on the issue. | Set and cleared by the orchestrator |
| `status/waiting` | label | The run stopped at a gate and is waiting for a human answer. | Set by the orchestrator at a gate; cleared on reply |
| `status/blocked` | label | The run failed or hit a policy stop. | Set by the orchestrator on failure or policy; a human clearing it re-dispatches |
| `status/in-review` | label | The PR is open and awaiting review. | Set by the orchestrator when the PR is open; closed by the merge |

The five `status/*` labels are mutually exclusive. An open issue with none of them is backlog. `type/*` and `priority/*` labels are orthogonal and not part of the flow.

## Epics

A too-big exploration is an epic issue whose body comes from `beat/routes/<route>/route.md`. Each change node is a sub-issue whose first body line is `Route: <route>/<node>`. A `blocked_by` edge in the route becomes a native blocked-by link. A node is dispatchable when it has `status/ready` and no open blocker.

## Gate replies

A stopped run posts its question as an issue comment and sets `status/waiting`. The human answers with a comment that starts with `D<n>:` (one line per decision), `/answer <text>` or `/resume`. Other comments are ignored.

## When a skill says "publish to the issue tracker"

Create an issue as described under Conventions.

## When a skill says "fetch the ticket"

Read it as described under Conventions.
