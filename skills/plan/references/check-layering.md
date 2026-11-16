# Check Layering

Principles for deciding when each automated check runs. The defaults below apply to every project; a project that wants different layering writes its own in `CLAUDE.md` / `AGENTS.md`, which the agent already reads, and the project's version wins. A repo that does not use Beat can link to this file directly.

Put every check at the earliest point where its wait is affordable, and keep the full suite in CI as the backstop.

## Default layering

| Point | What runs | On failure |
| --- | --- | --- |
| commit hook | format, commit message; no tests | block |
| inside a task (`/beat:apply`) | only the tests the task affects | fix before the next task |
| end of `/beat:apply` | the full e2e suite, when the change has `@e2e` scenarios | pause; do not advance to verify |
| `/beat:verify` | the full suite (behavior and e2e), every run | reported in the verification report |
| CI, every PR/MR push | the full suite | block merge |

A project override names the real commands for each point (for example, the command that runs only affected tests).

## Principles

1. Wait cost = check time × how often that point fires. Commits fire most, so only checks that finish in seconds belong there.
2. Block by who is affected by a mistake that gets through. A local commit affects nobody yet, so keep its hook light. A push occupies CI and reviewers, so CI blocks.
3. Never run the full suite per task. It runs at change wrap-up (`/beat:verify`; the e2e suite also at the end of `/beat:apply`) and on every CI run. Exception: a task that changes test infrastructure (test config, dependencies) runs it inside the task.
4. "Run only the affected tests" is a speed-up, never the only gate. Selection relies on static analysis and misses things; the wrap-up run and CI run the full suite.
5. Test time must buy something. A real database or a real subprocess buys "same as production", so keep it. Real timers, repeated identical work and repeated loading buy nothing, so remove them.
6. Accept an optimization by the thing you changed, not by total time. CI total time moves with runner load; look at two runs at least.
7. Anything that must always hold goes into a hook or CI, not only into prose.

## When to add a check

When the same kind of mistake happens a second time, turn it into an automated check instead of relying on memory or a doc reminder.

- First time: fix it and record the cause. A costly mistake (data leak, data corruption) gets a check the first time.
- Second time: write the check. If you cannot, change the design so the mistake becomes impossible.
- Prove a new check catches the mistake before placing it: run it against the broken version and see it fail. Then decide which point it goes to.

Not worth a check: a one-off event; a check that costs more than the mistake (long wait, frequent false alarms); anything that needs human judgement (put it on the review checklist instead).

## Where a new check goes (ask in order)

1. Does it need an external service (database, container) or the whole test suite? If yes, CI (and the wrap-up run), not the commit hook.
2. Is it a fast, local check on the changed files only (format, lint, message)? Commit hook.
3. If it fails, does it affect anyone else? If not, warn instead of block.
4. Does another point already run the same thing? If yes, do not duplicate it.

## When to revisit

- People habitually skip the commit hook (`--no-verify`).
- Waiting for CI or the wrap-up run starts to change how people work (batching unrelated changes, skipping the run).
- A change passes on its own, then breaks after merge.
- The same kind of mistake happens a second time and no check exists for it yet.
