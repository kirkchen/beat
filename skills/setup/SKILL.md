---
name: setup
description: Use when initializing Beat or updating its config — not for editing config.yaml directly or non-Beat tools
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

   Keeping the config skips steps 3–7 only; steps 8–11 still run, so a project set up before the layout files existed gets them now.

   Also check for `beat/CONTEXT.md` (the glossary path before 0.6). If it exists, print exactly this one line and continue with setup:

   ```
   This project still has beat/CONTEXT.md. Run the migration: https://github.com/kirkchen/beat/blob/main/docs/migrations/0.6-project-layout.md
   ```

   Do not migrate it, move it, or create `GLOSSARY.md` in its place. The migration is the user's step.

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

   1. "Yes, let me specify" -- ask per-artifact rules (`proposal`, `gherkin`, `design`, `tasks`, and `adr` for ADRs written at any trigger point)
   2. "Skip for now" -- create config with context only

   If `docs/adr/TEMPLATE.md` already exists, mention that skills will use it as the ADR skeleton automatically — `rules.adr` is for constraints beyond the template (e.g. an index to update).

6b. **Prototype surface** (only when detectable)

   If the project has a Storybook (`.storybook/` directory or a `storybook` script in `package.json`) or another obvious prototype surface, set `prototype.surface` and `prototype.command` in the config without asking — `/beat:explore` uses them when exploration ends in a prototype node. Otherwise leave the field out; it can be added later.

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

   Do **not** create the three living-doc surfaces here. They are `GLOSSARY.md`,
   `docs/adr/` and `beat/ARCHITECTURE.md` (plus module READMEs), all lazy: each
   appears the first time a Beat skill needs it, and a small project may never
   need any of them. Their paths are mapped in `references/project-layout.md`.
   Mention this in the summary so the user knows what to expect.

Steps 9–11 write the project-layout files from `references/project-layout.md`. Each is idempotent: an existing file is completed (missing sections or placeholders filled), never overwritten, and the user's edits are kept. Re-running setup changes nothing that is already filled in.

9. **Issue tracker** (`docs/agents/issue-tracker.md`)

   Detect the tracker from `git remote -v`:
   - a `github.com` remote → template `references/issue-tracker-github.md`
   - a `gitlab` host (gitlab.com or a self-hosted `gitlab.*`) → template `references/issue-tracker-gitlab.md`
   - any other host, or no remote → template `references/issue-tracker-other.md`

   Ask with **AskUserQuestion tool** only when detection is ambiguous (remotes on more than one host, or a host that may be a self-hosted GitHub / GitLab). Put the detected answer first as the recommended option.

   Fill these setup placeholders, everywhere they appear in the template:
   - `<owner>/<repo>` (GitHub) or `<group>/<project>` (GitLab): from the remote URL. For `issue-tracker-other.md`, ask for `<tracker name>` and `<tracker location>` instead (e.g. "Jira", "project ABC").
   - `<assignee>`: ask "Which account does the orchestrator run as? (the GitHub / GitLab login that will own the PRs)".
   - `<dispatch-label>`: `rhythm-change`. Say so ("Dispatch label: `rhythm-change`") and move on unless the user objects.

   Every other `<...>` in the template (`<number>`, `<file>`, `<parent>`, `<n>`, ...) is a command argument the skills fill at run time: leave it as written.

   For `issue-tracker-other.md`, ask the user for the one-paragraph Conventions description; if they have none yet, leave its placeholder text in place.

   Copy the Vocabulary section as is, apart from the `<assignee>` and `<dispatch-label>` values filled above: the five `status/*` labels and their meanings are fixed, not per project.

   Write `docs/agents/issue-tracker.md` (`mkdir -p docs/agents`). If the file exists, fill only the setup placeholders still in it and add any template section it lacks; keep everything else.

10. **Coding standards** (`CODING_STANDARDS.md`)

    If `CODING_STANDARDS.md` already exists at the project root, keep it as is. If it is absent, write it from `references/coding-standards-template.md` and fill `## Sources` by scanning:
    - `CONTRIBUTING.md`
    - `README.md` files at the root and one level under `src/`, `packages/`, `apps/`: headings containing convention, invariant, testing or style
    - `docs/**` files whose name contains convention, standard, style or guideline

    One line per hit: `path — the heading or first sentence`. If nothing is found, leave the Sources placeholder. Leave `## Judgement rules` with its placeholder; `/retro` and reviewers fill it later.

11. **Agent docs block** (`CLAUDE.md` or `AGENTS.md`)

    Pick the file: `CLAUDE.md` if it exists, else `AGENTS.md` if it exists, else ask with **AskUserQuestion tool** which one to create (`CLAUDE.md` for Claude Code, `AGENTS.md` for Codex and other agents).

    Insert the `## Agent docs` block from `references/project-layout.md` (the heading plus its three pointer lines). If the file already has a `## Agent docs` heading, replace that section's three lines in place instead of adding a second block.

    The block points at `GLOSSARY.md` even when the glossary does not exist yet: the pointer tells agents where it goes. Do not create `GLOSSARY.md` to satisfy it.

12. **Show summary**

    ```
    ## Beat Initialized

    **Config:** beat/config.yaml
    **Directories:** beat/changes/, beat/features/
    **Superpowers:** installed / not installed (fallback mode)
    **Testing:** {behavior framework} + {e2e framework} (or "not required")
    **Issue tracker:** docs/agents/issue-tracker.md ({GitHub | GitLab | other}) — written / completed / kept
    **Coding standards:** CODING_STANDARDS.md — written ({n} sources) / kept
    **Agent docs:** {CLAUDE.md | AGENTS.md} — block added / updated / kept

    Your config will be used when creating artifacts.
    Edit beat/config.yaml anytime to update preferences.

    Beat will also lazy-create three living-doc surfaces when first needed:
    - GLOSSARY.md         — domain glossary (see references/context-format.md)
    - docs/adr/           — ADRs, three-condition gate (see references/adr-format.md)
    - beat/ARCHITECTURE.md + module READMEs (see references/architecture-format.md)

    Small projects may never need any of these.

    Ready to start? Run `/beat:design` or `/beat:explore`
    ```

    Then end with the handoff block from `references/handoff-report.md` (`next: /beat:explore`).

**Guardrails**
- Never overwrite existing config without asking
- Config is always optional -- if user wants minimal setup, just create directories
- Validate config against `references/config-schema.md` before writing
- Context should be concise -- warn if it exceeds 2KB (soft limit, 50KB hard limit)
- Framework recommendations are suggestions -- always let the user override
- Do not insist on e2e for Library projects
- Never overwrite `docs/agents/issue-tracker.md`, `CODING_STANDARDS.md`, or the rest of `CLAUDE.md` / `AGENTS.md`: complete them, do not replace them
- Never create `GLOSSARY.md` or `docs/adr/`; never migrate `beat/CONTEXT.md` (print the one-line pointer instead)
- Do not skip `docs/agents/issue-tracker.md` because the project has no orchestrator yet: `/beat:to-issue` refuses without it; write it now, it is one file
