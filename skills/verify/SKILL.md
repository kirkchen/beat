---
name: verify
description: Use when validating implementation against spec artifacts before archive — not for design, planning, or implementation
---

Verify implementation against change artifacts across five dimensions. Uses independent subagents to eliminate context bias.

<decision_boundary>

**Use for:**
- Validating implementation completeness against spec artifacts before archive
- Verifying distilled specs match current code behavior (accuracy mode, `source: distill`)
- Independent verification via subagents to catch context bias
- Surfacing living-doc drift (Layer 1/2/3) as advisory findings

**NOT for:**
- Creating or modifying spec artifacts (use `/beat:design`)
- Writing tasks (use `/beat:plan`)
- Running implementation (use `/beat:apply`)
- Archiving the change (use `/beat:archive`)

**Trigger examples:**
- "Verify the change" / "Check implementation against spec" / "Run verification"
- Should NOT trigger: "design a feature" / "implement the change" / "archive it"

</decision_boundary>

<HARD-GATE>
You MUST dispatch independent subagents for verification — NEVER verify implementation yourself
in the main session. The main session has context bias from the conversation history.

Dispatch the verification subagent AND code-reviewer in parallel — they are independent checks.

If a subagent fails, proceed with findings from the other. If BOTH fail, report the failure —
do NOT fall back to self-verification.

After presenting the combined report: you MUST record the outcome in the top-level
`verification` field of status.yaml (see step 6). If verification could not run at all
(both subagents failed), do NOT record — a failed run is not a verification outcome.
</HARD-GATE>

## Rationalization Prevention

| Thought | Reality |
|---------|---------|
| "The change is small, I can verify it myself" | Self-verification creates confirmation bias. You saw the implementation — you can't objectively verify it. |
| "I already reviewed the code during apply" | That's exactly why you need an independent verifier. Familiarity breeds blind spots. |
| "Running two subagents is overkill for this" | Code quality and spec alignment are independent dimensions. A single agent conflates them. |
| "I'll just run the tests, that's verification enough" | Tests verify behavior but not spec alignment, design adherence, or code quality. |
| "I'll dispatch them sequentially to save context" | They're independent — parallel dispatch is faster and prevents one report from biasing the other. |
| "The report is delivered, the status.yaml write is just bookkeeping" | The `verification` field is how archive knows verify ran. Skip it and archive warns "never verified" on a verified change. Ten seconds — write it. |

## Red Flags — STOP if you catch yourself:

- Verifying any dimension yourself instead of dispatching a subagent
- Dispatching subagents sequentially instead of in parallel
- Skipping code-reviewer because "the code is simple"
- Claiming verification passed without reading the subagent reports
- Editing code or artifacts during verification (the ONLY write is the `verification` record in status.yaml)
- Presenting the report without recording the outcome in status.yaml
- Falling back to self-verification because a subagent failed

## Process Flow

```dot
digraph verify {
    "Select change" [shape=box];
    "Read artifacts +\ntesting context" [shape=box];
    "Parallel dispatch" [shape=box, style=bold];
    "Verification\nsubagent" [shape=box];
    "Code-reviewer\nsubagent" [shape=box];
    "tests available?" [shape=diamond];
    "Run automated tests" [shape=box];
    "Present combined report" [shape=box];
    "Record verification\nin status.yaml" [shape=doublecircle];

    "Select change" -> "Read artifacts +\ntesting context";
    "Read artifacts +\ntesting context" -> "Parallel dispatch";
    "Parallel dispatch" -> "Verification\nsubagent";
    "Parallel dispatch" -> "Code-reviewer\nsubagent";
    "Verification\nsubagent" -> "tests available?";
    "Code-reviewer\nsubagent" -> "tests available?";
    "tests available?" -> "Run automated tests" [label="yes"];
    "tests available?" -> "Present combined report" [label="no"];
    "Run automated tests" -> "Present combined report";
    "Present combined report" -> "Record verification\nin status.yaml";
}
```

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
   - **Modified files**: Does `status.yaml` have `gherkin.modified`? If yes, collect the listed paths and their `.feature.orig` backup paths — the verification subagent needs them for semantic verification (Dimension 1B+).

3. **Dispatch verification subagent AND code-reviewer in parallel**

   Launch BOTH agents simultaneously using a single message with two Agent tool calls:

   **Agent A — Verification subagent** (subagent_type: `Explore`):
   Read `verification-subagent-prompt.md` for the complete subagent prompt.

   Provide ONLY:
   - All artifact contents (features, proposal, design, tasks)
   - Testing context (drive mode, testing config, source flag, tag counts)
   - Modified files list from `gherkin.modified` with their `.feature.orig` backup paths (if any)
   - Do NOT pass conversation history or session context.

   **Agent B — Code quality review** (subagent_type: `general-purpose`):
   Read `code-reviewer-prompt.md` for the complete subagent prompt.

   Provide:
   - The change name and description (from proposal or status.yaml)
   - List of files created/modified during apply
   - The planning document (tasks.md or proposal.md) as the "original plan"
   - The git range (base..head SHAs) if available, so the reviewer can read the diff

   This reviews: code quality, architecture, naming, error handling, test quality, security, and plan alignment. Its output is Dimension 4, classified in Beat's CRITICAL/WARNING/SUGGESTION vocabulary.

   **Fallback**: If one agent fails, proceed with the other's findings. If BOTH fail, report failure — do NOT self-verify.

4. **Run automated tests if available**

   Detect and run the project's test suite:
   - **Behavior tests**: run using `testing.behavior` framework (or auto-detect)
   - **E2E tests**: run using `testing.e2e` framework (or auto-detect). If `beat/changes/<name>/features/` contains feature files, combine BDD feature paths: `beat/features/` + `beat/changes/<name>/features/`
   - Report behavior and e2e results separately

5. **Present combined verification report**

   Combine both subagent reports:
   - Dimensions 1-3 from verification subagent (spec alignment)
   - Dimension 4 from code-reviewer (code quality)
   - Dimension 5 from verification subagent (living docs sync — Layer 1/2/3, advisory only)
   - Step 4 test results (if available)

6. **Record the outcome in status.yaml**

   Read `beat/changes/<name>/status.yaml` (read before write — preserve existing fields), then set the top-level `verification` field per `references/status-schema.md`:

   ```yaml
   verification: { status: passed, critical: 0, date: YYYY-MM-DD }
   ```

   - `status: passed` when zero CRITICAL findings; `issues-found` otherwise
   - `critical`: the CRITICAL count from the combined report, including failing automated tests from step 4
   - Do NOT advance `phase` — verification outcome lives only in this field
   - Skip recording entirely if verification could not run (both subagents failed) — report the failure instead

   This is the only file verify writes. `/beat:archive` uses it to warn when archiving an unverified change. Re-running verify after fixes overwrites the field.

**Issue Classification**
- CRITICAL: Must fix (missing scenario test [in coverage mode], inaccurate scenario [in accuracy mode], unimplemented goal, design violation, security vulnerability, failing automated test from step 4)
- WARNING: Should fix (partial coverage, possible divergence, non-executable test, Gherkin quality issues, code quality concerns, living-doc drift — Layer 1/2/3 sync gaps)
- SUGGESTION: Nice to fix (pattern inconsistency, minor improvement, missing test in distill mode, module without README)

**Dimension 5 is advisory** — its findings classify as WARNING or SUGGESTION only, never CRITICAL. The user decides whether to act before archiving; living-doc drift never blocks the archive.

**Graceful Degradation**
- Gherkin skipped: skip Dimension 1, strengthen Dimension 2 (proposal alignment)
- Only features exist: verify Gherkin coverage only
- Features + proposal: verify coverage + alignment
- Features + proposal + design: verify all five dimensions (Dimension 5 only when living docs exist)
- Always note which checks were skipped and why
