---
name: setup
description: Use when setting up Beat for the first time in a project or updating project configuration
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

4. **Ask about testing** (optional)

   Use **AskUserQuestion tool**:
   > "How should Beat handle automated testing?"

   Provide options:
   1. "Require tests (TDD)" -- default, every scenario needs a test
   2. "No tests required" -- for projects without test frameworks (e.g., docs, config, infra)
   3. "Let me specify framework" -- set a specific test framework

   **If user chooses "Require tests":**
   - Ask about **behavior test framework** (`testing.behavior`):
     - If codebase detection was done in step 3, use detected framework (vitest, jest, pytest, etc.)
     - Otherwise, ask: "What test framework do you use for unit/behavior tests?" (e.g., vitest, jest, pytest, go test)
   - Ask about **e2e test framework** (`testing.e2e`):
     - If codebase detection found e2e config (playwright.config, cypress.config, etc.), use it
     - Otherwise, ask: "Do you have an e2e test framework? (e.g., playwright, cypress, or skip if none)"
     - If user says none/skip, omit `testing.e2e` from config

   **If user chooses "No tests required":**
   - Set `testing.required: false`

   **If user chooses "Let me specify":**
   - Ask for behavior framework name → set `testing.behavior`
   - Ask for e2e framework name (optional) → set `testing.e2e` if provided

   This sets the `testing` field in config.

5. **Ask about artifact rules** (optional)

   Use **AskUserQuestion tool**:
   > "Want to set rules for how artifacts are generated?"

   1. "Yes, let me specify" -- ask per-artifact rules
   2. "Skip for now" -- create config with context only

6. **Write config**

   Create `beat/config.yaml` following the schema in `references/config-schema.md`.

   ```bash
   mkdir -p beat
   ```

   Write the file with the gathered context and rules.

7. **Create directory structure** (if not exists)

   ```bash
   mkdir -p beat/changes
   mkdir -p beat/features
   ```

8. **Show summary**

   ```
   ## Beat Initialized

   **Config:** beat/config.yaml
   **Directories:** beat/changes/, beat/features/

   Your config will be used when creating artifacts.
   Edit beat/config.yaml anytime to update preferences.

   Ready to start? Run `/beat:new` or `/beat:explore`
   ```

**Guardrails**
- Never overwrite existing config without asking
- Config is always optional -- if user wants minimal setup, just create directories
- Validate config against `references/config-schema.md` before writing
- Context should be concise -- warn if it exceeds 2KB (soft limit, 50KB hard limit)
