---
name: ff
description: Fast-forward through Beat artifact creation. Use when the user wants to quickly create all artifacts at once (e.g., small fixes or well-understood scope). For step-by-step control over each artifact, use /beat:continue instead. Triggers on /beat:ff.
---

Fast-forward -- create a change (if needed) and generate all artifacts in one go.

**Prerequisites** (invoke before proceeding)

| Superpower | When | Priority |
|-----------|------|----------|
| brainstorming | Before creating proposal or design | MUST |
| writing-plans | When creating tasks | MUST |

If a superpower is unavailable (skill not installed), skip and continue.

**Input**: Change name (kebab-case) OR a description of what to build. Can also be an existing change name to fast-forward remaining artifacts.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use **AskUserQuestion tool** to ask what they want to build.
   Derive kebab-case name from description.

2. **Create or select change**

   - If `beat/changes/<name>/` doesn't exist: create it (same as beat:new: directory + status.yaml + features/.gitkeep)
   - If it exists: use it, read `status.yaml` (schema: `references/status-schema.md`) to find remaining artifacts

3. **Ask which optional artifacts to include**

   Read `status.yaml`. For artifacts still `pending`, ask user once upfront:

   Use **AskUserQuestion tool**:
   > "Which optional artifacts do you want?"
   > 1. Full: Proposal + Gherkin + Design + Tasks (recommended for large features)
   > 2. Standard: Proposal + Gherkin (recommended for medium features)
   > 3. Minimal: Gherkin only (recommended for small bug fixes)
   > 4. Technical: Proposal + Tasks, no Gherkin (for tooling/infra/refactor changes with no behavior change)
   > 5. Custom: Let me choose each one

   Mark skipped artifacts as `skipped` in `status.yaml`.

4. **Create artifacts in pipeline order**

   Read `beat/config.yaml` if it exists (schema: `references/config-schema.md`). Use `language` for artifact output language, inject `context`, and apply matching `rules` per artifact type throughout creation.

   For each artifact to create (pipeline order: proposal -> gherkin -> design -> tasks):
   - Read all completed artifacts for context
   - Invoke prerequisites per the table above (brainstorming before proposal/design, writing-plans for tasks)
   - Create the artifact following the patterns below
   - Update `status.yaml`
   - Show brief progress: "Created <artifact>"
   - If context is critically unclear, pause and ask

   **Artifact patterns:**
   - **Proposal**: Sections: `## Why`, `## What Changes`, `## Impact`
   - **Gherkin**: SpecFlow style, tags `@happy-path`/`@error-handling`/`@edge-case`, Feature description carries PRD essence. Every scenario MUST have a testing layer tag (`@e2e` for user journeys needing a running app, or `@behavior` for business logic testable without a full app; default `@behavior`). Write scenarios at behavior level — describe what the system does ("Monthly billing adjusts for short months"), not how a function works ("calculateNextTransactionDate clamps to last day"). If option 4 (Technical) was chosen, skip gherkin entirely.
   - **Design**: Sections: `## Approach`, `## Key Decisions`, `## Components`
   - **Tasks**: If writing-plans is invoked, adapt its output: use `- [ ]` checkboxes, `### Task N:` headings, save to `tasks.md` (not `docs/plans/`), skip execution handoff. If writing-plans unavailable, use simple checkbox checklist.

5. **Show final status**

   Update phase to `implement` in `status.yaml`.

   ```
   ## Fast-Forward Complete: <change-name>

   Created:
   - proposal.md (or skipped)
   - features/*.feature (or skipped if Technical option)
   - design.md (or skipped)
   - tasks.md (or skipped)

   All artifacts ready! Run `/beat:apply` to start implementation.
   ```

**Guardrails**
- Gherkin is mandatory by default -- only skip for purely technical changes (option 4: Technical)
- Ask upfront which optional artifacts to include (don't ask per artifact)
- If change already exists with some artifacts done, only create remaining
- If context is critically unclear, ask -- but prefer reasonable defaults to keep momentum
- Verify each artifact file exists after writing before proceeding
