---
name: apply
description: Implement code based on Beat feature files. Use when the user wants to start or continue implementation of a change, write tests and code for Gherkin scenarios. Triggers on /beat:apply.
---

Implement code based on the feature files in a change. Every scenario MUST have a corresponding automated test.

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it (announce: "Using change: <name>")
   - If multiple exist, use **AskUserQuestion tool** to let user select

2. **Read status.yaml and verify readiness**

   Check that `gherkin` has `status: done`.
   If not: "Gherkin features are required before implementation. Run `/beat:continue` first." STOP.

3. **Read all artifacts for context**

   Read in order:
   - `proposal.md` (if exists) -- business context
   - `features/*.feature` (all files) -- implementation targets
   - `design.md` (if exists) -- technical decisions
   - `tasks.md` (if exists) -- implementation checklist

4. **Determine implementation strategy**

   **If tasks.md exists:** Use it as the implementation checklist.
   **If no tasks.md:** Extract each Scenario from feature files as a unit of work.

5. **Show implementation overview**

   ```
   ## Implementing: <change-name>

   ### Scenarios to implement:
   1. [feature.feature] Scenario: <name>
   2. [feature.feature] Scenario: <name>
   ...

   ### Approach:
   - For each scenario: write automated test + implementation code
   - Every scenario MUST have a corresponding automated test
   ```

6. **Implement (loop)**

   For each task (from tasks.md) or scenario (from features):

   a. **Announce**: "Working on: <description>"

   b. **Write automated test first** (TDD):
      - Create or update test file with a test covering the scenario
      - The test framework is the project's existing one (detect from codebase)
      - The test should correspond to the Given/When/Then steps

   c. **Write implementation code**:
      - Follow design.md decisions if available
      - Keep changes minimal and focused on the scenario

   d. **If using tasks.md**: Mark task complete `- [ ]` -> `- [x]`

   e. **Continue to next**

   **Pause if:**
   - Task/scenario is unclear -> ask for clarification
   - Implementation reveals design issue -> suggest updating artifacts
   - Error or blocker -> report and wait

7. **On completion or pause, show status**

   If all done: update `status.yaml` phase to `verify`
   ```
   ## Implementation Complete

   **Change:** <name>
   **Scenarios:** N/N implemented with tests

   Suggested next steps:
   - `/beat:verify` -- validate implementation against artifacts
   - `/beat:sync` -- sync features to specs/
   - `/beat:archive` -- archive the change
   ```

**Mandatory Rule: Every Scenario Must Have a Test**

Non-negotiable. For every Scenario in every .feature file:
- There MUST be a corresponding automated test
- The test MUST be executable (not just a skeleton)
- The test framework is the project's choice (Cucumber, pytest-bdd, Jest, etc.)

**Superpowers Integration**

- At start: "Tip: `superpowers:test-driven-development` enforces TDD cycles."
- If stuck: "Tip: `superpowers:systematic-debugging` can help diagnose issues."
- For parallel work: "Tip: `superpowers:subagent-driven-development` can parallelize independent scenarios."

**Guardrails**
- Never implement without reading feature files first
- Always write test before implementation (TDD)
- Keep each change scoped to one scenario/task
- Update task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements -- don't guess
- If implementation reveals issues with features/design, suggest updating artifacts
