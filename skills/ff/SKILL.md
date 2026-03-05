---
name: ff
description: Fast-forward through Beat artifact creation. Use when the user wants to quickly create all artifacts needed for implementation in one go, or create a new change and generate everything at once. Triggers on /beat:ff.
---

Fast-forward -- create a change (if needed) and generate all artifacts in one go.

**Input**: Change name (kebab-case) OR a description of what to build. Can also be an existing change name to fast-forward remaining artifacts.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use **AskUserQuestion tool** to ask what they want to build.
   Derive kebab-case name from description.

2. **Create or select change**

   - If `beat/changes/<name>/` doesn't exist: create it (same as beat:new: directory + status.yaml + features/.gitkeep)
   - If it exists: use it, read `status.yaml` to find remaining artifacts

3. **Ask which optional artifacts to include**

   Read `status.yaml`. For artifacts still `pending`, ask user once upfront:

   Use **AskUserQuestion tool**:
   > "Which optional artifacts do you want? (Gherkin is always created)"
   > 1. Full: Proposal + Gherkin + Design + Tasks (recommended for large features)
   > 2. Standard: Proposal + Gherkin (recommended for medium features)
   > 3. Minimal: Gherkin only (recommended for small bug fixes)
   > 4. Custom: Let me choose each one

   Mark skipped artifacts as `skipped` in `status.yaml`.

4. **Create artifacts in pipeline order**

   For each artifact to create (pipeline order: proposal -> gherkin -> design -> tasks):
   - Read all completed artifacts for context
   - Create the artifact (same logic as beat:continue step 5)
   - Update `status.yaml`
   - Show brief progress: "Created <artifact>"
   - If context is critically unclear, pause and ask

5. **Show final status**

   Update phase to `implement` in `status.yaml`.

   ```
   ## Fast-Forward Complete: <change-name>

   Created:
   - proposal.md (or skipped)
   - features/*.feature
   - design.md (or skipped)
   - tasks.md (or skipped)

   All artifacts ready! Run `/beat:apply` to start implementation.
   ```

**Guardrails**
- Always create gherkin -- it's mandatory
- Ask upfront which optional artifacts to include (don't ask per artifact)
- If change already exists with some artifacts done, only create remaining
- If context is critically unclear, ask -- but prefer reasonable defaults to keep momentum
- Verify each artifact file exists after writing before proceeding
