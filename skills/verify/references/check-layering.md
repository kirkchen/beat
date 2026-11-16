# Check Layering

Principles for deciding when each automated check runs. The principles hold across repos; the timing table is filled in by each repo and lives in that repo's testing docs. A repo that does not use Beat can link to this file directly.

Put every check at the earliest point where its wait is affordable, and keep the full suite in CI as the backstop.

## Principles

1. Wait cost = check time × how often that point fires. Commits fire most, so only checks that finish in seconds belong there.
2. Block by who is affected by a mistake that gets through. A local commit affects nobody yet, so do not block it. A push occupies CI and reviewers, so block it.
3. The full suite runs only in CI. Do not repeat it locally. Exception: changes to test infrastructure (test config, dependencies).
4. "Run only the affected tests" is a speed-up, never the only gate. Selection relies on static analysis and misses things; some place must run the full suite every time.
5. Test time must buy something. A real database or a real subprocess buys "same as production", so keep it. Real timers, repeated identical work and repeated loading buy nothing, so remove them.
6. Accept an optimization by the thing you changed, not by total time. CI total time moves with runner load; look at two runs at least.
7. Anything that must always hold goes into a hook or CI, not only into prose.

## Timing table (each repo fills in its own)

| Point | Budget | What runs | On failure |
| --- | --- | --- | --- |
| commit | seconds | format, commit message | block |
| during development (manual) | minutes | affected tests | n/a |
| push | 30 s, cap ___ min | types, static checks, affected tests | block, `--no-verify` allowed |
| every PR/MR push | ___ min | full suite | block merge |
| merge to trunk | ___ min | ___ | block or warn |

Fill each cell with the real command and a measured time; write "not measured" if you have not measured it.

## When to add a check

When the same kind of mistake happens a second time, turn it into an automated check instead of relying on memory or a doc reminder.

- First time: fix it and record the cause. A costly mistake (data leak, data corruption) gets a check the first time.
- Second time: write the check. If you cannot, change the design so the mistake becomes impossible.
- Prove a new check catches the mistake before placing it: run it against the broken version and see it fail. Then decide which point it goes to.

Not worth a check: a one-off event; a check that costs more than the mistake (long wait, frequent false alarms); anything that needs human judgement (put it on the review checklist instead).

## Where a new check goes (ask in order)

1. How long does it take? Seconds: commit. Within 30 seconds: push. Longer: CI.
2. Does it need an external service (database, container)? If yes, not at commit.
3. If it fails, does it affect anyone else? If not, warn instead of block.
4. Does another point already run the same thing? If yes, do not duplicate it.

## When to revisit

- The push checks routinely exceed their budget, or people habitually use `--no-verify`.
- CI full-suite time shifts by more than 30%.
- A change passes on its own, then breaks after merge.
- The same kind of mistake happens a second time and no check exists for it yet.
