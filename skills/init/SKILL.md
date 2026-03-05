---
name: init
description: Initialize Beat in a project. Creates beat/config.yaml with project context and rules. Use when the user wants to set up Beat for the first time, configure project preferences, or create a beat config. Triggers on /beat:init or when user says "initialize beat", "set up beat", or similar.
---

Initialize Beat configuration in the current project.

**Input**: None required. The skill gathers information interactively.

**Steps**

1. **Check if config already exists**

   Check if `beat/config.yaml` exists.
   - If yes: read it, show current config, ask if user wants to update or keep it
   - If no: proceed to creation

2. **Ask artifact language**

   Use **AskUserQuestion tool**:
   > "What language should Beat use for artifacts (proposals, features, designs, tasks)?"

   Provide options:
   1. "English (en)" -- default
   2. "繁體中文 (zh-TW)"
   3. "简体中文 (zh-CN)"
   4. Other -- let user specify a BCP 47 tag

   This sets the `language` field in config.

3. **Gather project context**

   Use **AskUserQuestion tool** to ask:
   > "Describe your project so Beat can tailor its artifacts. Include: tech stack, test framework, and any key conventions."

   Provide example options:
   1. "Let me describe it" -- open-ended input
   2. "Detect from codebase" -- agent scans package.json, Cargo.toml, go.mod, etc.

   **If user chooses detection:**
   - Scan common manifest files for tech stack
   - Look for test configuration (vitest.config, jest.config, pytest.ini, etc.)
   - Check for linter/formatter configs
   - Summarize findings and confirm with user

4. **Ask about artifact rules** (optional)

   Use **AskUserQuestion tool**:
   > "Want to set rules for how artifacts are generated?"

   1. "Yes, let me specify" -- ask per-artifact rules
   2. "Skip for now" -- create config with context only

5. **Write config**

   Create `beat/config.yaml` following the schema in `references/config-schema.md`.

   ```bash
   mkdir -p beat
   ```

   Write the file with the gathered context and rules.

6. **Create directory structure** (if not exists)

   ```bash
   mkdir -p beat/changes
   mkdir -p beat/features
   ```

7. **Show summary**

   ```
   ## Beat Initialized

   **Config:** beat/config.yaml
   **Directories:** beat/changes/, beat/features/

   Your config will be used when creating artifacts.
   Edit beat/config.yaml anytime to update preferences.

   Ready to start? Run `/beat:new` or `/beat:explore`.
   ```

**Guardrails**
- Never overwrite existing config without asking
- Config is always optional -- if user wants minimal setup, just create directories
- Validate config against `references/config-schema.md` before writing
- Context should be concise -- warn if it exceeds 2KB (soft limit, 50KB hard limit)
