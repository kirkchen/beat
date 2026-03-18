---
name: verify
description: Use when validating implementation completeness before archiving a Beat change
---

Verify implementation against change artifacts using four dimensions. Uses independent subagents to eliminate context bias.

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
   - **Tag layer**: Every scenario in a .feature file is expected to have a corresponding test (in TDD mode).

3. **Dispatch verification subagent**

   Use the **Agent tool** (subagent_type: `Explore`).
   Read `verification-subagent-prompt.md` for the complete subagent prompt.

   Provide ONLY:
   - All artifact contents (features, proposal, design, tasks)
   - Testing context (drive mode, testing config, source flag, tag counts)
   - Do NOT pass conversation history or session context.

4. **Dispatch code quality review**

   Use the **Agent tool** (subagent_type: `superpowers:code-reviewer`).

   Provide:
   - The change name and description (from proposal or status.yaml)
   - List of files created/modified during apply
   - The planning document (tasks.md or proposal.md) as the "original plan"

   This reviews: code quality, architecture, naming, error handling, test quality, security, and plan alignment.

5. **Run automated tests if available**

   Detect and run the project's test suite. Include results in the report.

6. **Present combined verification report**

   Combine both subagent reports:
   - Dimensions 1-3 from verification subagent (spec alignment)
   - Dimension 4 from code-reviewer (code quality)
   - Step 5 test results (if available)

**Issue Classification**
- CRITICAL: Must fix (missing scenario test [in coverage mode], inaccurate scenario [in accuracy mode], unimplemented goal, design violation, security vulnerability)
- WARNING: Should fix (partial coverage, possible divergence, non-executable test, Gherkin quality issues, code quality concerns)
- SUGGESTION: Nice to fix (pattern inconsistency, minor improvement, missing test in distill mode)

**Graceful Degradation**
- Gherkin skipped: skip Dimension 1, strengthen Dimension 2 (proposal alignment)
- Only features exist: verify Gherkin coverage only
- Features + proposal: verify coverage + alignment
- Features + proposal + design: verify all four dimensions
- Always note which checks were skipped and why

**Guardrails**
- Always use a subagent for verification -- never self-verify in the main session
- Every issue must have a specific, actionable recommendation
- Prefer SUGGESTION over WARNING, WARNING over CRITICAL when uncertain
- Include file:line references where applicable
- If automated tests exist, run them and include results
