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

2. **Read all artifacts**

   Read from `beat/changes/<name>/`:
   - `status.yaml` (schema: `references/status-schema.md`)
   - `features/*.feature` (all Gherkin files) -- REQUIRED
   - `proposal.md` (if exists)
   - `design.md` (if exists)
   - `tasks.md` (if exists)

3. **Dispatch verification subagent**

   Use the **Agent tool** (subagent_type: `Explore`) to dispatch an independent subagent. The subagent receives ONLY artifacts and code -- no conversation context -- to eliminate bias.

   Subagent prompt must include:
   - All artifact contents (features, proposal, design, tasks)
   - Instruction to search the codebase for implementation evidence
   - The three verification dimensions (below)
   - The report format template (below)

   **Dimension 1: Gherkin Coverage**
   For each Scenario in .feature files:
   - Does a corresponding automated test exist? (search for step definitions, test files)
   - Is the test executable (not a skeleton)?
   - Does the implementation handle the scenario's behavior?

   **Dimension 2: Proposal Alignment** (if proposal.md exists)
   For each goal in the proposal:
   - Is there implementation evidence?
   - Are there goals mentioned but not implemented?

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

   ### Final Assessment
   - "X critical issue(s) found. Fix before archiving."
   - "No critical issues. Y warning(s) to consider. Ready for archive."
   - "All checks passed. Ready for archive."
   ```

**Issue Classification**
- CRITICAL: Must fix (missing scenario test, unimplemented goal, design violation)
- WARNING: Should fix (partial coverage, possible divergence)
- SUGGESTION: Nice to fix (pattern inconsistency, minor improvement)

**Graceful Degradation**
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
