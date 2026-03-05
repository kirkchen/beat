---
name: sync
description: Sync features and docs from a Beat change to the persistent beat/features/ directory. Use when the user wants to update the project's living documentation after implementation. Triggers on /beat:sync.
---

Sync features and documentation from a change to the project's persistent `beat/features/` directory.

This is an **agent-driven** operation -- you read change files and organize them into the beat/features/ structure.

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it (announce: "Using change: <name>")
   - If multiple exist, use **AskUserQuestion tool** to let user select
   - If none exist: inform user and stop

2. **Read change artifacts**

   Read from `beat/changes/<name>/`:
   - `features/*.feature` (all Gherkin files) -- REQUIRED for sync
   - `proposal.md` (if exists)
   - `design.md` (if exists)

   If no feature files exist: inform user and stop.

3. **Determine capability mapping**

   For each feature file, the user decides which capability directory it belongs to.

   Use **AskUserQuestion tool**:
   > "Where should each feature be synced? Existing capabilities: [list from beat/features/]. Or enter a new name."

   If only one feature file and the mapping is obvious from context, suggest a default.

4. **Sync files**

   For each mapping:

   If `beat/features/` doesn't exist, create it: `mkdir -p beat/features`

   **Feature files:**
   - Copy `features/<file>.feature` -> `beat/features/<capability>/<file>.feature`
   - If file already exists in beat/features/: update with new content
   - If new: create

   **Proposal:**
   - Copy `proposal.md` -> `beat/features/<capability>/proposal.md`

   **Design:**
   - Copy `design.md` -> `beat/features/<capability>/design.md`

   **Capability README:**
   - If `beat/features/<capability>/README.md` doesn't exist, create:
     ```markdown
     # <Capability Name>

     [Brief description -- TBD]
     ```

   **Global README:**
   - If `beat/features/README.md` doesn't exist: create with global navigation
   - If it exists: update to include the new capability

5. **Update status.yaml** (schema: `references/status-schema.md`)

   Update phase to `sync`.

6. **Show summary**

   ```
   ## Features Synced: <change-name>

   **<capability>/**:
   - Synced: login.feature, session.feature
   - Added: proposal.md, design.md
   - Created: README.md

   Features are now updated. Run `/beat:archive` to archive the change.
   ```

**Sync Rules**

| Source (change) | Target (beat/features/) | Behavior |
|-----------------|------------------------|----------|
| `features/*.feature` | `beat/features/<capability>/` | Add or update feature files |
| `proposal.md` | `beat/features/<capability>/proposal.md` | Copy to capability |
| `design.md` | `beat/features/<capability>/design.md` | Copy to capability |

**Guardrails**
- Always ask user for capability mapping -- don't guess
- If capability directory doesn't exist, create it
- Preserve existing content in beat/features/ not related to this change
- Show what's being synced before doing it
- The operation should be idempotent -- running twice gives same result
