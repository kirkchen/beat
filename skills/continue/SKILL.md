---
name: continue
description: Continue working on a Beat change by creating or skipping the next artifact. Use when the user wants to progress their change, build the next artifact, skip an optional step, or continue the BDD pipeline. Triggers on /beat:continue.
---

Continue working on a change by creating or skipping the next artifact in the pipeline.

**Pipeline order:** `proposal -> gherkin -> design -> tasks`

- `proposal`, `design`, `tasks` are **optional** (user can skip)
- `gherkin` is **mandatory** (cannot be skipped)

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it (announce: "Using change: <name>")
   - If multiple exist, use **AskUserQuestion tool** to let user select
   - Show each change with its phase and progress

   Do NOT guess or auto-select when ambiguous.

2. **Read status.yaml**

   Read `beat/changes/<name>/status.yaml` (schema: `references/status-schema.md`) to understand:
   - Current `phase`
   - Which artifacts are `done`, `pending`, or `skipped`

3. **Determine next artifact**

   Find the first artifact in pipeline order with `status: pending`.

   **If no pending artifacts remain:**
   - All artifacts are done or skipped
   - Update phase to `implement` in `status.yaml`
   - Announce: "All artifacts complete! Run `/beat:apply` to start implementation."
   - STOP

4. **Present the artifact choice**

   **If it's `gherkin` (mandatory):**
   - Announce: "Next: Write Gherkin feature files (mandatory)"
   - Proceed directly to creation

   **If it's optional (`proposal`, `design`, `tasks`):**
   - Use **AskUserQuestion tool** with options:
     1. "Create <artifact>" -- explain what it contains
     2. "Skip <artifact>" -- explain what you'll miss
   - If user chooses skip: update `status.yaml` to `skipped`, find next pending artifact

5. **Create the artifact**

   Before creating, read all `done` artifacts for context.

   Read `beat/config.yaml` if it exists (schema: `references/config-schema.md`). Use `language` for artifact output language, inject `context` as project background, and apply matching `rules` for this artifact type.

   ---

   **Proposal** (`proposal.md`):

   Ask the user about the change if not clear from context. Write:
   ```markdown
   # <Change Name> -- Proposal

   ## Why
   [Business motivation and problem statement]

   ## What Changes
   [Scope of changes, what's in and out]

   ## Impact
   [Affected systems, users, and workflows]
   ```

   Update `status.yaml`: proposal -> `done`, phase -> `proposal`

   ---

   **Gherkin** (`features/*.feature`):

   This is the core artifact. Read the proposal (if exists) for context.

   Write one or more `.feature` files using SpecFlow style:
   ```gherkin
   @tag
   Feature: <Feature Name>
     As a <role>
     I want <goal>
     So that <benefit>

     [Rich description: business context, technical notes]

     Background:
       Given <shared precondition>

     @happy-path
     Scenario: <Specific behavior>
       Given <precondition>
       When <action>
       Then <expected result>
   ```

   Guidelines:
   - Each scenario = one verifiable behavior = one test case
   - Use tags: `@happy-path`, `@error-handling`, `@edge-case`
   - Feature description carries PRD essence (business context, technical notes)
   - Background for shared preconditions across scenarios
   - Language: follow project convention (English or Chinese keywords)
   - File organization: flat in `features/` or grouped by subdirectory

   Update `status.yaml`: gherkin -> `done`, phase -> `gherkin`

   ---

   **Design** (`design.md`):

   Read proposal and features for context. Write:
   ```markdown
   # <Change Name> -- Technical Design

   ## Approach
   [Architecture decisions and rationale]

   ## Key Decisions
   [Important technical choices with justification]

   ## Components
   [What to build/modify and how they interact]
   ```

   Update `status.yaml`: design -> `done`, phase -> `design`

   ---

   **Tasks** (`tasks.md`):

   Read all previous artifacts. Write:
   ```markdown
   # <Change Name> -- Tasks

   ## Implementation Checklist

   - [ ] Task 1: description
   - [ ] Task 2: description
   ...
   ```

   Each task should map to one or more scenarios from the feature files.
   Include tasks for writing tests, implementing code, and integration.

   Update `status.yaml`: tasks -> `done`, phase -> `tasks`

6. **Show progress after creating**

   Display:
   - Which artifact was created (or skipped)
   - Current progress (N/4 done, M skipped)
   - What's next in the pipeline
   - Prompt: "Run `/beat:continue` to proceed, or tell me what to do next."

**Superpowers Integration**

Remind the user of available tools at each stage:
- **Proposal**: "Tip: `superpowers:brainstorming` can help clarify scope if it's unclear."
- **Gherkin**: "Tip: `superpowers:brainstorming` can help co-define acceptance criteria."
- **Design**: "Tip: `superpowers:brainstorming` can help explore architectural trade-offs."

**Guardrails**
- Create ONE artifact per invocation
- Always read completed artifacts before creating a new one
- Never skip `gherkin` -- it's the only mandatory artifact
- If context is unclear, ask the user before creating
- Update `status.yaml` immediately after creating or skipping
- STOP after creating one artifact -- wait for user direction
