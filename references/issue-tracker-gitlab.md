# Issue tracker: GitLab

Issues for this repo live in `<group>/<project>` on GitLab. Use the `glab` CLI for all operations. Command recipes adapted from mattpocock/skills (MIT; see `NOTICE.md`).

## Conventions

- **Create an issue**: `glab issue create --title "..." --description "$(cat <file>)"`. Write the description to a file first; do not pass a multi-line description inline.
- **Read an issue**: `glab issue view <number> --comments`. Use `-F json` for machine-readable output.
- **List issues by label**: `glab issue list --label "<label>" -O json`.
- **Edit labels**: `glab issue update <number> --label "..."` / `--unlabel "..."`. Multiple labels can be comma-separated or given by repeating the flag.
- **Comment on an issue**: `glab issue note <number> --message "$(cat <file>)"`. GitLab calls comments "notes".
- **Close**: `glab issue close <number>` does not accept a closing comment, so post the explanation first with `glab issue note <number> --message "..."`, then close.
- **Make an issue a sub-issue of a parent**: put `Part of #<parent>` at the top of the child description and link it: `glab issue create --linked-issues <parent> --link-type relates_to ...`. On GitLab tiers with native epics, the epic may hold the parent instead.
- **Add a blocked-by edge**: GitLab's native blocking link. Post the `/blocked_by #<blocker>` quick action as a note: `glab issue note <child> --message "/blocked_by #<blocker>"`. Native blocking links are a Premium/Ultimate feature; on the free tier (or where unavailable) fall back to a `Blocked by: #<n>, #<n>` line at the top of the description. An issue is unblocked when every blocker is closed.
- **Count open blockers**: `glab api projects/:id/issues/<iid>/links`, then count entries with `link_type` `is_blocked_by` and `state` `opened`. In the fallback case, count the open issues named in the `Blocked by` line.

Infer the repo from `git remote -v`; `glab` does this automatically inside a clone.

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
