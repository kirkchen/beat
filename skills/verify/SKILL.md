---
name: verify
description: Three-dimensional verification of implementation against Beat artifacts. Use when the user wants to validate Gherkin coverage, proposal alignment, and design adherence before archiving. Triggers on /beat:verify.
---

Verify implementation against change artifacts using three dimensions. Uses an independent subagent to eliminate context bias.

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it
   - If multiple exist, use **AskUserQuestion tool** to let user select

2. **Read all artifacts and determine testing context**

   Read from `beat/changes/<name>/`:
   - `status.yaml` (schema: `references/status-schema.md`)
   - `features/*.feature` (all Gherkin files, if gherkin status is `done`)
   - `proposal.md` (if exists)
   - `design.md` (if exists)
   - `tasks.md` (if exists)

   Read `beat/config.yaml` (if exists, schema: `references/config-schema.md`).

   **Determine drive mode:**
   - If `gherkin` status is `done` → **Gherkin-driven verification**
   - If `gherkin` status is `skipped` → **Proposal-driven verification**

   **Determine testing context** (three-layer priority: tag > source > config):
   - **Config layer**: Is `testing.required` set to `false`? If yes, skip test existence checks globally.
   - **Source layer**: Does `status.yaml` contain `source: distill`? If yes, Dimension 1 switches to **accuracy mode** (see below).
   - **Tag layer**: Scenarios tagged `@no-test` are always excluded from test existence checks, regardless of other settings.

3. **Dispatch verification subagent**

   Use the **Agent tool** (subagent_type: `Explore`) to dispatch an independent subagent. The subagent receives ONLY artifacts and code -- no conversation context -- to eliminate bias.

   Subagent prompt must include:
   - All artifact contents (features, proposal, design, tasks)
   - Instruction to search the codebase for implementation evidence
   - The three verification dimensions (below)
   - The report format template (below)

   **Dimension 1: Gherkin Coverage** (testing-context-aware)

   The behavior of this dimension depends on testing context and drive mode:

   **When gherkin is skipped (proposal-driven):**
   - Skip Dimension 1 entirely.
   - Note in report: "Gherkin coverage skipped (gherkin: skipped, proposal-driven mode)."

   **Default mode (coverage):** `testing.required` is true (or unset), source is not `distill`.
   For each Scenario in .feature files (excluding `@no-test`):

   *`@e2e` scenarios:*
   - Does an e2e test or step definition exist for this scenario?
   - If the project uses a BDD runner: check for step definitions binding to the .feature
   - If not: check for `@covered-by` annotation (same as `@behavior`)
   - Missing test/step definition → CRITICAL. Non-executable → WARNING.

   *`@behavior` scenarios:*
   - Does the scenario have a `# @covered-by: <path>` annotation (between tag and scenario line)?
   - Does the referenced test file exist?
   - Does the test file contain a matching `// @scenario:` comment?
   - Missing `@covered-by` → WARNING.
   - `@covered-by` pointing to nonexistent file → CRITICAL.
   - File exists but no matching `@scenario` comment → WARNING.

   *Scenarios without `@e2e`/`@behavior` tag:* treat as `@behavior`.

   **Accuracy mode:** `source: distill` in status.yaml.
   For each Scenario in .feature files (excluding `@no-test`):
   - Does the code actually behave as the scenario describes? (cite specific file:line)
   - Are there behaviors in the code NOT captured by any scenario?
   - Are there scenarios that don't match the code?
   - If existing tests are found, map them to corresponding scenarios.
   - Missing test → SUGGESTION (not CRITICAL). Inaccurate scenario → CRITICAL.

   **Skipped mode:** `testing.required: false` in config.
   - Skip test existence checks entirely.
   - Still verify that the implementation handles each scenario's behavior.
   - Note in report: "Test existence checks skipped (testing.required: false)."

   **Dimension 2: Proposal Alignment** (if proposal.md exists)
   For each goal in the proposal:
   - Is there implementation evidence?
   - Are there goals mentioned but not implemented?

   *When proposal-driven:* strengthen this dimension — check that every risk point and success criterion has corresponding test coverage. Missing coverage for a risk point → CRITICAL (elevated from WARNING).

   **Dimension 3: Design Adherence** (if design.md exists)
   For each decision in the design:
   - Does the implementation follow this decision?
   - Are there contradictions?

4. **Run automated tests if available**

   Detect and run the project's test suite. Include results in the report.

5. **Present verification report**

   ```
   ## Verify Report -- <change-name>

   ### Summary
   | Dimension | Status | Issues |
   |-----------|--------|--------|
   | Gherkin Coverage | pass/partial/fail | N |
   | Proposal Alignment | pass/partial/fail/skipped | N |
   | Design Adherence | pass/partial/fail/skipped | N |

   ### CRITICAL
   - [Dimension] Description -- file:line
     Recommendation: specific action

   ### WARNING
   - [Dimension] Description -- file:line
     Recommendation: specific action

   ### SUGGESTION
   - [Dimension] Description
     Recommendation: specific action

   ### Testing Context
   - Drive mode: gherkin-driven/proposal-driven
   - Config: testing.required = true/false/unset
   - Source: normal/distill
   - @e2e scenarios: N (checked for e2e tests/step definitions)
   - @behavior scenarios: N (checked for @covered-by annotations)
   - @no-test scenarios: N excluded

   ### Final Assessment
   - "X critical issue(s) found. Fix before archiving."
   - "No critical issues. Y warning(s) to consider. Ready for archive."
   - "All checks passed. Ready for archive."
   ```

**Issue Classification**
- CRITICAL: Must fix (missing scenario test [in coverage mode], inaccurate scenario [in accuracy mode], unimplemented goal, design violation)
- WARNING: Should fix (partial coverage, possible divergence, non-executable test)
- SUGGESTION: Nice to fix (pattern inconsistency, minor improvement, missing test in distill mode)

**Graceful Degradation**
- Gherkin skipped: skip Dimension 1, strengthen Dimension 2 (proposal alignment)
- Only features exist: verify Gherkin coverage only
- Features + proposal: verify coverage + alignment
- Features + proposal + design: verify all three dimensions
- Always note which checks were skipped and why

**Guardrails**
- Always use a subagent for verification -- never self-verify in the main session
- Every issue must have a specific, actionable recommendation
- Prefer SUGGESTION over WARNING, WARNING over CRITICAL when uncertain
- Include file:line references where applicable
- If automated tests exist, run them and include results
