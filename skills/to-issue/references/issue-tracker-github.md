# Issue tracker: GitHub

Issues for this repo live in `<owner>/<repo>` on GitHub. Use the `gh` CLI for all operations. Command recipes adapted from mattpocock/skills (MIT; see `NOTICE.md`).

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <file>`. Write the body to a file first; do not pass a multi-line body inline.
- **Read an issue**: `gh issue view <number> --json number,title,body,labels,comments`.
- **List issues by label**: `gh issue list --state open -L <n> --label "<label>" --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`. The default limit is 30, which truncates large epics; set `-L` to at least the expected count.
- **Edit the body**: `gh issue edit <number> --body-file <file>` (add `--title "..."` to change the title). Write the new body to a file first.
- **Edit labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`.
- **Comment on an issue**: `gh issue comment <number> --body-file <file>`.
- **Close**: post the explanation with `gh issue comment <number> --body-file <file>`, then `gh issue close <number>`. On an already-closed issue, `gh issue close --comment` drops the comment and still exits 0.
- **Make an issue a sub-issue of a parent**: `gh issue create --parent <parent> ...`, or `gh issue edit <parent> --add-sub-issue <child>` afterwards (`gh` 2.94+). Older `gh`: `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, see **Add a blocked-by edge**). Without sub-issues, put `Part of #<parent>` at the top of the child body.
- **Add a blocked-by edge**: GitHub's native issue dependencies. Works on any `gh`: `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric database id (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, not the `#number` or `node_id`). On `gh` 2.94+ the shorter flags also work: `gh issue create --blocked-by <n>,<n> ...` or `gh issue edit <child> --add-blocked-by <blocker>`. Where dependencies are unavailable, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. An issue is unblocked when every blocker is closed.
- **Count open blockers**: `gh api repos/<owner>/<repo>/issues/<n> --jq .issue_dependencies_summary.blocked_by` (open blockers only; 0 means startable).

Infer the repo from `git remote -v`; `gh` does this automatically inside a clone. In a fork, `gh` can default to the upstream parent, so before the first `gh issue create` of a session check the target with `gh repo view --json nameWithOwner`.

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
