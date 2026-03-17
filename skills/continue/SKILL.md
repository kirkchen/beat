---
name: continue
description: Use when progressing a Beat change to its next artifact — one artifact at a time with control over each step
---

Continue working on a change by creating or skipping the next artifact in the pipeline.

<HARD-GATE>
Before creating proposal or design: you MUST invoke superpowers:brainstorming.
Before creating tasks: you MUST invoke superpowers:writing-plans.
"MUST" means unconditional. Not "if complex enough". Not "if time permits". Always.
If a prerequisite skill is unavailable (not installed), continue with fallback — but NEVER skip
because you judged it unnecessary.
</HARD-GATE>

**Prerequisites** (invoke before proceeding)

| Superpower | When | Priority |
|-----------|------|----------|
| brainstorming | Before creating proposal or design | MUST |
| writing-plans | When creating tasks | MUST |

If a superpower is unavailable (skill not installed), skip and continue.

## Rationalization Prevention

| Thought | Reality |
|---------|---------|
| "This change is simple enough to write tasks inline" | Simple changes finish writing-plans quickly. Complex changes need it most. There is no middle ground where skipping helps. |
| "I already understand the scope from the proposal/gherkin" | Understanding scope ≠ properly decomposed tasks. writing-plans catches scope gaps you haven't noticed. |
| "The user wants speed, invoking superpowers will slow us down" | Skipping prerequisites produces lower-quality artifacts that cause rework during apply and verify. |
| "brainstorming isn't needed, the user already described what they want" | A description is not a design. brainstorming surfaces assumptions, alternatives, and edge cases. |

## Red Flags — STOP if you catch yourself:

- Writing `- [ ]` task checkboxes without having invoked writing-plans
- Generating proposal sections without having invoked brainstorming
- Thinking "this prerequisite isn't needed for this particular change"
- Skipping a MUST prerequisite and planning to "compensate" later

**Pipeline order:** `proposal -> gherkin -> design -> tasks`

- `proposal`, `design`, `tasks` are **optional** (user can skip)
- `gherkin` is **mandatory by default** but can be skipped for purely technical changes (see Granularity Assessment)

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

   **If it's `gherkin`:**
   - First, assess whether Gherkin is appropriate for this change (see **Granularity Assessment** below)
   - If appropriate: announce "Next: Write Gherkin feature files" and proceed to creation
   - If not appropriate (purely technical change): use **AskUserQuestion tool** offering to skip, explaining that proposal will drive testing instead

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

   **Testing layer tags** — every scenario MUST have exactly one:
   - `@e2e` — user journey requiring a running app (tested via the project's e2e framework)
   - `@behavior` — business logic/rules testable without a full app (tested via the project's test framework with annotation linking)
   - If neither tag fits, default to `@behavior`
   - These tags coexist with other tags: `@e2e @happy-path`, `@behavior @edge-case`

   Note: during apply, `@behavior` scenarios will get `# @covered-by` annotations linking to their test files. Test files will include `@feature` and `@scenario` annotations (as comments in the project's language) for bidirectional traceability.

   Update `status.yaml`: gherkin -> `done`, phase -> `gherkin`

   ---

   **Granularity Assessment** (evaluate before writing Gherkin):

   | Signal | Write Gherkin | Skip Gherkin |
   |--------|---------------|--------------|
   | Describes user/system behavior | Yes | |
   | PM or QA can understand the scenario | Yes | |
   | Involves multiple component interaction | Yes | |
   | Describes internal function behavior | | Yes |
   | Only developers care about this | | Yes |
   | Pure infrastructure/tooling change | | Yes |

   **Write scenarios at behavior level, not function level:**

   ```gherkin
   # GOOD: describes WHAT the system does
   @behavior @edge-case
   Scenario: Monthly billing adjusts for short months
     Given the billing day is 31
     When the next billing falls in February
     Then the billing date should be the last day of February

   # BAD: describes HOW a function works
   Scenario: calculateNextTransactionDate clamps to last day
     When I call calculateNextTransactionDate(new Date("2024-01-15"), 31)
     Then the result month should be 1
   ```

   When skipping gherkin: update `status.yaml`: gherkin -> `skipped`, advance phase to next non-skipped artifact or `implement`

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

   Read all previous artifacts (proposal, gherkin, design).

   Invoke `superpowers:writing-plans` (if available) to generate a detailed implementation plan. Adapt its output into tasks.md format:
   - Keep the bite-sized step granularity (2-5 min per step)
   - Include exact file paths and code snippets where possible
   - Include test commands and expected results
   - Use `- [ ]` checkbox format for each step (Beat progress tracking)
   - Group steps under `### Task N: <Component Name>` headings
   - Save to `tasks.md` (not `docs/plans/`)
   - Skip the execution handoff section (Beat's `/beat:apply` handles execution)

   If `superpowers:writing-plans` is not available, fall back to a simple checklist:
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

**Guardrails**
- Create ONE artifact per invocation
- Always read completed artifacts before creating a new one
- Gherkin is mandatory by default -- only skip for purely technical changes after granularity assessment confirms no behavior change
- If context is unclear, ask the user before creating
- Update `status.yaml` immediately after creating or skipping
- STOP after creating one artifact -- wait for user direction
