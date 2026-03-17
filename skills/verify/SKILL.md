---
name: verify
description: Use when validating implementation completeness before archiving a Beat change
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

   Use the **Agent tool** (subagent_type: `Explore`).
   Read `verification-subagent-prompt.md` for the complete subagent prompt.

   Provide ONLY:
   - All artifact contents (features, proposal, design, tasks)
   - Testing context (drive mode, testing config, source flag, tag counts)
   - Do NOT pass conversation history or session context.

4. **Run automated tests if available**

   Detect and run the project's test suite. Include results in the report.

5. **Present verification report**

   Present the subagent's report as-is. If Step 4 produced test results, append them to the report.

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
