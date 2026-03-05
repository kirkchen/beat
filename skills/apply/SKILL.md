---
name: apply
description: Use when implementing a Beat change — requires gherkin or proposal artifact to be done first
---

Implement code based on the change artifacts. Supports two modes:

- **Gherkin-driven** (default): feature files drive implementation and testing
- **Proposal-driven**: when gherkin is skipped (technical changes), proposal drives testing

<decision_boundary>

**Use for:**
- Implementing code for a Beat change that has spec artifacts (gherkin or proposal) done
- TDD implementation driven by feature files or proposal risk points
- Resuming implementation of a partially completed change

**NOT for:**
- Creating spec artifacts like proposal, gherkin, or design.md (use `/beat:design`)
- Breaking down tasks or creating execution plans (use `/beat:plan`)
- Verifying implementation completeness (use `/beat:verify`)
- Exploring ideas or investigating a problem (use `/beat:explore`)

**Trigger examples:**
- "Implement the change" / "Start coding" / "Apply the plan" / "TDD the scenarios"
- Should NOT trigger: "design a feature" / "break down tasks" / "verify the implementation"

</decision_boundary>

<HARD-GATE>
Before any code changes: you MUST invoke superpowers:using-git-worktrees to verify isolation
(should already exist from design/plan; creates one if not).
In TDD mode: you MUST invoke superpowers:test-driven-development.
Invoke in order: worktrees first (verify), then TDD (discipline).
If a prerequisite skill is unavailable (not installed), continue without it — but NEVER skip
because you judged it unnecessary.
</HARD-GATE>

**Prerequisites** (invoke before proceeding)

| Superpower | When | Priority |
|-----------|------|----------|
| using-git-worktrees | Verify isolation (should exist from design/plan; creates if not) | MUST |
| test-driven-development | At start, in TDD mode | MUST |
| systematic-debugging | When stuck (3 failed attempts) | SHOULD |
| subagent-driven-development | When tasks.md has multiple independent tasks | SHOULD |

Invoke in order: worktrees first (verify isolation), then TDD (discipline). Debugging and subagent are conditional — only invoke when triggered. If a superpower is unavailable (skill not installed), skip and continue.

## Rationalization Prevention

| Thought | Reality |
|---------|---------|
| "The change is small, I don't need a worktree" | Worktrees protect against contamination. The worktree should already exist from design/plan — verify, don't skip. |
| "I'll write the test after the implementation, same result" | TDD is about design feedback, not just test coverage. Writing tests after loses the design signal. |
| "This is a refactor, TDD doesn't apply" | Refactors need tests most — they prove behavior is preserved. If testing.required is false, TDD is already skipped. |
| "I'll add @covered-by annotations at the end for all scenarios" | Annotations must be added per-scenario immediately after writing the test. Batching them leads to forgetting. |
| "The e2e test setup is too complex, I'll write a unit test instead" | The scenario is tagged @e2e for a reason. If e2e setup is genuinely blocked, announce the blocker and ask — don't silently downgrade. |
| "This @behavior test is obvious, a skeleton is enough" | Every test must be executable. A skeleton that doesn't run is not a test. |
| "These tasks are small, I'll combine them for efficiency" | Each task is bounded for a reason. Merging recreates the oversized-output problem that decomposition solved. One task = one subagent dispatch. |
| "The existing test is roughly correct, no need to update it" | If scenario steps changed, the test must reflect those changes. An old test passing does not mean the new behavior is correct. |
| "I'll create a new test file, it's faster" | If @covered-by already points to an existing test, creating a new file breaks traceability. Update the existing test. |

## Red Flags — STOP if you catch yourself:

- Writing implementation code before invoking using-git-worktrees
- Writing implementation code before writing a failing test (in TDD mode)
- Thinking "I'll set up the worktree after this first file"
- Skipping TDD because "the test would be trivial"
- Moving to the next scenario without adding `@covered-by` to the .feature file
- Skipping e2e test creation because "the e2e framework is complex to set up"
- Writing a test skeleton instead of an executable test
- Thinking "I'll add the annotations at the end after all scenarios are done"
- Dispatching a single subagent for multiple tasks to "save time"
- Creating a new test file for a scenario that already has `@covered-by` pointing to an existing test
- Modifying scenario steps without updating the corresponding e2e test

## Process Flow

```dot
digraph apply {
    "Select change, read artifacts" [shape=box];
    "Invoke using-git-worktrees" [shape=box, style=bold];
    "testing.required false?" [shape=diamond];
    "No-test mode" [shape=box];
    "Invoke test-driven-development" [shape=box, style=bold];
    "Gherkin done?" [shape=diamond];
    "Gherkin-driven" [shape=box];
    "Proposal-driven" [shape=box];
    "tasks.md exists?" [shape=diamond];
    "Has Task N headings?" [shape=diamond];
    "Executor mode\nfollow tasks exactly" [shape=box];
    "Planner mode\nextract scenarios/criteria" [shape=box];
    "Implementation loop" [shape=box];
    "All tasks complete" [shape=doublecircle];

    "Select change, read artifacts" -> "Invoke using-git-worktrees";
    "Invoke using-git-worktrees" -> "testing.required false?";
    "testing.required false?" -> "No-test mode" [label="yes"];
    "testing.required false?" -> "Invoke test-driven-development" [label="no"];
    "No-test mode" -> "Gherkin done?";
    "Invoke test-driven-development" -> "Gherkin done?";
    "Gherkin done?" -> "Gherkin-driven" [label="yes"];
    "Gherkin done?" -> "Proposal-driven" [label="gherkin skipped"];
    "Gherkin-driven" -> "tasks.md exists?";
    "Proposal-driven" -> "tasks.md exists?";
    "tasks.md exists?" -> "Has Task N headings?" [label="yes"];
    "tasks.md exists?" -> "Planner mode\nextract scenarios/criteria" [label="no"];
    "Has Task N headings?" -> "Executor mode\nfollow tasks exactly" [label="yes"];
    "Has Task N headings?" -> "Planner mode\nextract scenarios/criteria" [label="no"];
    "Executor mode\nfollow tasks exactly" -> "Implementation loop";
    "Planner mode\nextract scenarios/criteria" -> "Implementation loop";
    "Implementation loop" -> "All tasks complete";
}
```

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it (announce: "Using change: <name>")
   - If multiple exist, use **AskUserQuestion tool** to let user select

2. **Read status.yaml and verify readiness** (schema: `references/status-schema.md`)

   Check that either:
   - `gherkin` has `status: done` → **Gherkin-driven mode**
   - `gherkin` has `status: skipped` AND `proposal` has `status: done` → **Proposal-driven mode**

   If neither condition is met: "Features or proposal are required before implementation. Run `/beat:design` first." STOP.

3. **Read all artifacts and determine testing mode**

   Read in order:
   - `proposal.md` (if exists) -- business context and risk points
   - `features/*.feature` (all files, if gherkin is done) -- implementation targets
   - `design.md` (if exists) -- technical decisions
   - `tasks.md` (if exists) -- implementation checklist

   Read `beat/config.yaml` (if exists, schema: `references/config-schema.md`).

   **Determine testing mode:**
   - If `testing.required: false` → **no-test mode**: skip TDD cycles for all scenarios, write implementation only
   - If `testing.behavior` is set → use that framework for `@behavior` scenarios (skip auto-detection)
   - If `testing.e2e` is set → use that framework for `@e2e` scenarios (skip auto-detection)
   - If `testing.framework` is set (legacy) → treat as `testing.behavior`
   - If `testing` is absent or `testing.required: true` → **TDD mode** (default): require tests for all scenarios

   **Determine BDD feature paths** (for running e2e tests):
   - Base: `beat/features/` (unchanged features; `.feature.orig` files are invisible to BDD runners)
   - If `status.yaml` has `gherkin.modified`: add `beat/changes/<name>/features/` (modified + new features)
   - Combine both paths when invoking BDD runner (e.g., `npx cucumber-js beat/features beat/changes/<name>/features`)

4. **Determine implementation strategy**

   **If tasks.md exists:** Use it as the implementation checklist.
   - **Detailed format** (contains `### Task N:` headings with Steps): Enter **executor mode** — follow each step exactly as written, don't re-plan.
   - **Simple format** (only `- [ ]` checkboxes): Enter **planner mode** — plan each task's implementation yourself (existing behavior).

   **If no tasks.md and Gherkin-driven:** Extract each Scenario from feature files as a unit of work (planner mode).

   **If no tasks.md and Proposal-driven:** Extract success criteria and risk points from proposal.md as units of work (planner mode).

5. **Show implementation overview**

   ```
   ## Implementing: <change-name>

   ### Drive mode: gherkin-driven / proposal-driven
   ### Execution mode: executor / planner
   ### Tasks/Scenarios to implement:
   1. [source] <name>
   2. [source] <name>
   ...
   ```

6. **Implement (loop)**

   For each task (from tasks.md) or scenario (from features) or risk point (from proposal):

   a. **Announce**: "Working on: <description>"

   b. **Write automated test first** (TDD mode only):
      - Skip this step if **no-test mode**
      - The test framework: use `testing.behavior` or `testing.e2e` from config (depending on scenario tag), or detect from codebase

      **Generate vs Update** (see `references/testing-conventions.md` for details):
      - `@covered-by` present + test file exists → **Update**: modify the existing test to reflect new scenario steps
      - `@covered-by` present + test file missing → **Generate** + WARNING (stale annotation)
      - `@covered-by` absent → **Generate**: create new test (existing flow)

      **For `@e2e` scenarios (Gherkin-driven):**
      - Generate (or update) e2e test or step definitions using `testing.e2e` framework from config, or auto-detect from codebase
      - If the project uses a BDD runner (Cucumber, pytest-bdd, etc.), generate step definitions that bind to the .feature file
      - If no BDD runner, generate a regular e2e test with `@feature`/`@scenario` annotations (same as `@behavior`)

      **For `@behavior` scenarios (Gherkin-driven):**
      - Generate a test file (using `testing.behavior` from config, or auto-detect) with annotation comments:
        ```
        @feature: <feature-filename>.feature
        @scenario: <exact scenario name>
        ```
        (Use the project language's comment syntax: `//` for JS/TS/Java/C#, `#` for Python/Ruby, etc.)
      - After writing the test, update the .feature file with a `@covered-by` annotation (placed between the tag and the scenario line):
        ```gherkin
        @behavior @happy-path
        # @covered-by: <relative path to test file>
        Scenario: <name>
        ```

      **For proposal-driven units:**
      - Generate test files covering the risk point using the project's test framework
      - No annotation conventions needed (no features to link to)
      **For pytest-bdd projects:** the `@scenario` decorator serves as the annotation — no separate `# @feature` / `# @scenario` comments needed (see `references/testing-conventions.md`).

      Follow the conventions in `references/testing-conventions.md` for annotation format, e2e test style, and Generate vs Update path.

   c. **Write implementation code**:
      - Follow design.md decisions if available
      - Keep changes minimal and focused on the scenario
      - In no-test mode: still write implementation, just without preceding test

   d. **If using tasks.md**: Mark task complete `- [ ]` -> `- [x]`

   e. **Continue to next**

   f. **Scenario completion checklist** (verify before moving to next scenario):

      **For `@e2e` scenarios (TDD mode):**
      - [ ] E2e test or step definition exists and is executable
      - [ ] Test references the scenario (`@feature`/`@scenario` annotations or BDD binding)
      - [ ] `# @covered-by: <path>` annotation added to .feature file (between tag and Scenario line)

      **For `@behavior` scenarios (TDD mode):**
      - [ ] Test file exists with `@feature` and `@scenario` comments
      - [ ] `# @covered-by: <path>` annotation added to .feature file (between tag and Scenario line)
      - [ ] Test is executable (not a skeleton)

      **For all scenarios:**
      - [ ] Implementation code handles the scenario's behavior
      - [ ] Task checkbox marked complete (if using tasks.md)

      Do NOT move to the next scenario until all applicable items are checked.

   **Pause if:**
   - Task/scenario is unclear -> ask for clarification
   - Implementation reveals design issue -> suggest updating artifacts
   - Error or blocker -> report and wait

7. **E2E regression check** (after all scenarios implemented)

   If `@e2e` scenarios exist and `testing.e2e` is configured (or auto-detected):
   - Run the full e2e test suite using the combined BDD feature paths
   - If any failures → report and pause. Do NOT advance to verify phase.
   - All passing → continue to completion.

   Skip if no `@e2e` scenarios or no-test mode.

8. **On completion or pause, show status**

   If all done: update `status.yaml` phase to `verify`
   ```
   ## Implementation Complete

   **Change:** <name>
   **Scenarios:** N/N implemented with tests

   Suggested next steps:
   - `/beat:verify` -- validate implementation against artifacts
   - `/beat:archive` -- sync features and archive the change
   ```

**Testing Rule: Conditional TDD**

**In TDD mode** (default when `testing.required` is true or unset):
- For every Scenario in every .feature file: there MUST be a corresponding automated test
- `@e2e` scenarios → e2e test or step definitions (using project's e2e framework)
- `@behavior` scenarios → test with `@feature`/`@scenario` annotations + `@covered-by` comment in .feature
- The test MUST be executable (not just a skeleton)
- The test framework: `testing.behavior` (for @behavior) or `testing.e2e` (for @e2e) from config, or auto-detect from codebase
- If the project has a BDD runner (Cucumber, pytest-bdd, etc.), generate step definitions that bind directly to .feature files

**In proposal-driven mode** (gherkin skipped):
- Tests are driven by proposal.md success criteria and risk points
- Each risk point should have corresponding test coverage
- No annotation conventions (no features to link to)

**In no-test mode** (`testing.required: false`):
- Tests are not required. Implementation code is written directly.
- Developers may still write tests voluntarily using `testing.behavior`/`testing.e2e` if specified.

**Guardrails**
- Never implement without reading artifacts first (features in gherkin-driven, proposal in proposal-driven)
- In TDD mode: always write test before implementation
- For `@behavior` scenarios: always add `@covered-by` annotation to .feature after writing the test
- For `@behavior` scenarios: always add `@feature`/`@scenario` annotations in the test file
- Keep each change scoped to one scenario/task
- Update task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements -- don't guess
- If implementation reveals issues with features/design, suggest updating artifacts
