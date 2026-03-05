---
name: new
description: Start a new Beat change. Use when the user wants to create a new feature, fix, or modification with the BDD workflow. Triggers on /beat:new or when user says "start a new change", "new feature", or similar.
---

Start a new change using the Beat workflow.

**Input**: Change name (kebab-case) OR a description of what to build.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" -> `add-user-auth`).

   Do NOT proceed without understanding what the user wants to build.

2. **Check if change already exists**

   Check if `beat/changes/<name>/` directory exists.
   - If yes: inform user and suggest `/beat:continue` instead
   - If no: proceed

3. **Create the change directory and status.yaml**

   ```
   beat/changes/<name>/
   ├── status.yaml
   └── features/
       └── .gitkeep
   ```

   Write `status.yaml`:
   ```yaml
   name: <name>
   created: YYYY-MM-DD
   phase: new
   pipeline:
     proposal: { status: pending }
     gherkin: { status: pending }
     design: { status: pending }
     tasks: { status: pending }
   ```

4. **Show status and guide next step**

**Output**

Summarize:
- Change name and location (`beat/changes/<name>/`)
- Pipeline overview:
  ```
  New -> [Proposal] -> Gherkin -> [Design] -> [Tasks] -> Implement -> Verify -> Sync -> Archive
          optional     REQUIRED    optional    optional
  ```
- Current status: phase `new`, 0/4 artifacts
- Typical paths by change size:
  | Size | Path |
  |------|------|
  | Small bug fix | `New -> Gherkin -> Implement -> Archive` |
  | Medium feature | `New -> Proposal -> Gherkin -> Implement -> Verify -> Sync -> Archive` |
  | Large feature | `New -> Proposal -> Gherkin -> Design -> Tasks -> Implement -> Verify -> Sync -> Archive` |
- Prompt: "Ready? Run `/beat:continue` to build the first artifact, or `/beat:ff` to create them all at once."

**Guardrails**
- Do NOT create any artifacts -- just set up the container
- If the name is invalid (not kebab-case), ask for a valid name
- If a change with that name already exists, suggest `/beat:continue`
- Always create the `features/` directory with `.gitkeep`
