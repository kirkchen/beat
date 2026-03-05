---
name: setup
description: Use when setting up Beat for the first time in a project or updating project configuration — not for editing beat/config.yaml directly or configuring non-Beat tools
---

Initialize Beat configuration in the current project.

<decision_boundary>

**Use for:**
- Setting up Beat for the first time in a project
- Updating existing Beat configuration (language, testing frameworks, rules)
- Detecting project tech stack and recommending test frameworks

**NOT for:**
- Editing `beat/config.yaml` directly (just edit the file)
- Configuring non-Beat tools or project settings
- Creating changes or writing feature files (use `/beat:design`)

**Trigger examples:**
- "Set up Beat" / "Initialize Beat" / "Configure Beat for this project" / "Update Beat config"
- Should NOT trigger: "edit config.yaml" / "design a feature" / "create a change"

</decision_boundary>

**Input**: None required. The skill gathers information interactively.

**Steps**

1. **Check if config already exists**

   Check if `beat/config.yaml` exists.
   - If yes: read it, show current config, ask if user wants to update or keep it
   - If no: proceed to creation

2. **Check superpowers dependency**

   Check if the superpowers plugin is available by looking for any `superpowers:*` skill in the skill list.

   **If not available:**
   > "Beat works standalone, but is better with [superpowers](https://github.com/obra/superpowers) — it provides structured brainstorming, TDD discipline, task decomposition, and git worktree isolation.
   >
   > Install with: `/plugin marketplace add obra/superpowers`
   >
   > Without it, Beat falls back to simpler built-in flows."

   Use **AskUserQuestion tool**:
   1. "Install now" -- run the install command
   2. "Continue without it"

   **If available:** proceed silently.

3. **Ask artifact language**

   Use **AskUserQuestion tool**:
   > "What language should Beat use for artifacts (proposals, features, designs, tasks)?"

   Provide options:
   1. "English (en)" -- default
   2. "繁體中文 (zh-TW)"
   3. "简体中文 (zh-CN)"
   4. Other -- let user specify a BCP 47 tag

   This sets the `language` field in config.

4. **Gather project context and detect tech stack**

   Use **AskUserQuestion tool** to ask:
   > "Describe your project so Beat can tailor its artifacts. Include: tech stack, test framework, and any key conventions."

   Provide example options:
   1. "Let me describe it" -- open-ended input
   2. "Detect from codebase" -- agent scans package.json, Cargo.toml, go.mod, etc.

   **If user chooses detection:**
   - Scan common manifest files for tech stack and primary language
   - Look for test configuration (vitest.config, jest.config, pytest.ini, etc.)
   - Look for BDD runner configuration (cucumber.js, behave.ini, etc.)
   - Look for e2e configuration (playwright.config, cypress.config, etc.)
   - Check for linter/formatter configs
   - Summarize findings and confirm with user

   **Record the detected/described tech stack** — this informs Step 5 framework recommendations.

5. **Configure test frameworks**

   Based on the tech stack from Step 4, recommend appropriate frameworks.

   **Step 5a: Ask project type**

   Use **AskUserQuestion tool**:
   > "What type of project is this?"

   1. "Web app (has UI)" -- needs browser automation for e2e
   2. "API server" -- needs HTTP client for e2e
   3. "CLI tool" -- needs process execution for e2e
   4. "Library / SDK" -- e2e usually not needed, behavior tests suffice

   **Step 5b: Recommend frameworks using the table below**

   Cross-reference (language × project type) to recommend a framework pair. Present as defaults the user can accept or customize:

   > "Based on your stack ({language} + {project type}), recommended test frameworks:
   > - **Behavior tests:** {recommendation}
   > - **E2E tests:** {recommendation}
   >
   > Accept defaults or customize?"

   **Framework recommendation table:**

   *Behavior test frameworks (UT / integration):*

   | Language | Primary | Alternative |
   |----------|---------|-------------|
   | TypeScript / JavaScript | vitest | jest |
   | Python | pytest | pytest-bdd |
   | Go | go test | — |
   | Java | JUnit | TestNG |
   | C# | xUnit | NUnit |
   | Ruby | RSpec | — |
   | Rust | cargo test | — |

   *E2E frameworks (BDD runner + driver, by project type):*

   | Language | Web app (UI) | API server | CLI tool |
   |----------|-------------|------------|----------|
   | TS / JS | cucumber-js + playwright | cucumber-js + supertest | cucumber-js + execa |
   | Python | behave + playwright | behave + requests | behave + subprocess |
   | Go | godog + playwright | godog + net/http | godog + os/exec |
   | Java | Cucumber-JVM + Selenium | Cucumber-JVM + RestAssured | Cucumber-JVM + ProcessBuilder |
   | C# | Reqnroll + Playwright | Reqnroll + HttpClient | Reqnroll + Process |
   | Ruby | Cucumber + Capybara | Cucumber + Faraday | Cucumber + Open3 |

   For **Library** projects: omit `testing.e2e` — behavior tests are sufficient. Note this in the summary.

   **Step 5c: Escape hatch**

   If the user explicitly says tests are not needed (e.g., pure docs, config-only, infra project):
   - Set `testing.required: false`
   - Do NOT push back — respect the user's judgment

   This sets the `testing` field in config:
   ```yaml
   testing:
     behavior: <selected framework>     # always set (unless testing.required: false)
     e2e: <selected BDD runner + driver> # set unless Library type or testing.required: false
   ```

6. **Ask about artifact rules** (optional)

   Use **AskUserQuestion tool**:
   > "Want to set rules for how artifacts are generated?"

   1. "Yes, let me specify" -- ask per-artifact rules
   2. "Skip for now" -- create config with context only

7. **Write config**

   Create `beat/config.yaml` following the schema in `references/config-schema.md`.

   ```bash
   mkdir -p beat
   ```

   Write the file with the gathered context and rules.

8. **Create directory structure** (if not exists)

   ```bash
   mkdir -p beat/changes
   mkdir -p beat/features
   ```

9. **Show summary**

   ```
   ## Beat Initialized

   **Config:** beat/config.yaml
   **Directories:** beat/changes/, beat/features/
   **Superpowers:** installed / not installed (fallback mode)
   **Testing:** {behavior framework} + {e2e framework} (or "not required")

   Your config will be used when creating artifacts.
   Edit beat/config.yaml anytime to update preferences.

   Ready to start? Run `/beat:design` or `/beat:explore`
   ```

**Guardrails**
- Never overwrite existing config without asking
- Config is always optional -- if user wants minimal setup, just create directories
- Validate config against `references/config-schema.md` before writing
- Context should be concise -- warn if it exceeds 2KB (soft limit, 50KB hard limit)
- Framework recommendations are suggestions -- always let the user override
- Do not insist on e2e for Library projects
