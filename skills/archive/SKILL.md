---
name: archive
description: Archive a completed Beat change. Use when the user wants to finalize and archive a change after implementation is complete. Offers sync before archiving if needed. Triggers on /beat:archive.
---

Archive a completed change. Checks completion, offers sync if needed, then moves to archive.

**Input**: Optionally specify a change name. If omitted, infer from context or prompt.

**Steps**

1. **Select the change**

   If no name provided:
   - Look for `beat/changes/` directories (excluding `archive/`)
   - If only one exists, use it
   - If multiple exist, use **AskUserQuestion tool** to let user select
   - Show only active (non-archived) changes

2. **Check artifact completion**

   Read `beat/changes/<name>/status.yaml` (schema: `references/status-schema.md`).
   Check which artifacts are `done` vs `pending` (not `skipped`).

   **If any non-skipped artifacts are still `pending`:**
   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

3. **Check task completion** (if tasks.md exists)

   Read `tasks.md`. Count `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning: "N/M tasks incomplete"
   - Use **AskUserQuestion tool** to confirm
   - Proceed if user confirms

4. **Assess sync state**

   Check if `features/*.feature` files have been synced to `beat/features/`.
   Look for corresponding files in `beat/features/` directories.

   **If feature files exist but not synced:**
   - Use **AskUserQuestion tool**:
     1. "Sync now (recommended)" -- run beat:sync logic first
     2. "Archive without syncing"
   - If user chooses sync: execute sync (same logic as beat:sync skill), then continue to archive

   **If no feature files or already synced:** Proceed directly.

5. **Perform the archive**

   ```bash
   mkdir -p beat/changes/archive
   ```

   Generate target name: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: fail with error, suggest renaming
   - If no: move the directory

   ```bash
   mv beat/changes/<name> beat/changes/archive/YYYY-MM-DD-<name>
   ```

6. **Show summary**

   ```
   ## Archive Complete

   **Change:** <change-name>
   **Archived to:** beat/changes/archive/YYYY-MM-DD-<name>/
   **Features:** Synced to beat/features/ (or "Sync skipped" or "No features to sync")
   **Artifacts:** N done, M skipped
   **Tasks:** X/Y complete (or "No tasks file")
   ```

**Guardrails**
- Always prompt for change selection if not provided
- Don't block archive on warnings -- inform and confirm
- If sync is requested, use beat:sync logic (agent-driven)
- Show clear summary of what happened
- If archive target already exists, don't overwrite
