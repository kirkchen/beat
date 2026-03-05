---
name: distill
description: Reverse-engineer Gherkin feature files and docs from existing code. Use when adopting the BDD workflow for an existing codebase, migrating legacy code to BDD, or documenting existing behavior as feature specs. Triggers on /beat:distill.
---

Distill -- reverse-engineer Gherkin feature files from existing code.

Use this to bring existing codebases into the Beat workflow. The output is draft `.feature` files that describe **current behavior** (not aspirational), verified by an independent subagent.

**Input**: User specifies the code scope to distill (module, directory, or functionality).

**Steps**

1. **Ask for scope**

   If not specified, use **AskUserQuestion tool**:
   > "What code do you want to distill into BDD specs? Specify a module, directory, or describe the functionality."

2. **Read and understand the code**

   Read the specified code. Map out:
   - User-visible behaviors (functionality)
   - Edge cases handled
   - Error conditions
   - Existing tests (if any) that reveal behavior

3. **Create a change container**

   Create `beat/changes/distill-<scope-name>/` with `status.yaml` (schema: `references/status-schema.md`):
   ```yaml
   name: distill-<scope-name>
   created: YYYY-MM-DD
   phase: new
   source: distill
   pipeline:
     proposal: { status: pending }
     gherkin: { status: pending }
     design: { status: pending }
     tasks: { status: pending }
   ```

4. **Generate draft artifacts**

   Read `beat/config.yaml` if it exists (schema: `references/config-schema.md`). Use `language` for artifact output language, inject `context` as project background, and apply matching `rules` per artifact type.

   **features/*.feature (mandatory):**
   - Write feature files describing CURRENT behavior (not desired behavior)
   - Each scenario must accurately reflect what the code actually does
   - Use tags: `@distilled` (always), plus `@happy-path`, `@error-handling`, `@edge-case`
   - Use SpecFlow style with rich description areas

   **proposal.md (optional):**
   - If the purpose is clear from code/docs: write a brief "why this exists" proposal

   **design.md (optional):**
   - Document the current technical architecture and key decisions visible in the code

   Update `status.yaml` for each artifact created.

5. **Dispatch verification subagent**

   Use **Agent tool** (subagent_type: `Explore`) to dispatch an independent subagent:

   ```
   You are a verification agent. Compare these draft .feature files against
   the actual code. For each scenario:
   - Does the code actually behave this way? (cite specific file:line)
   - Are there behaviors in the code NOT captured by any scenario?
   - Are there scenarios that don't match the code?

   Artifacts:
   [include all draft feature file contents]

   Code scope:
   [include the code paths to verify against]

   Report inaccuracies and omissions with specific evidence.
   ```

6. **Fix drafts based on verification feedback**

   Address inaccuracies and omissions identified by the subagent.

7. **Present to user for review**

   Show:
   - All generated feature files
   - Verification report summary
   - Any remaining uncertainties
   - Prompt: "Review these drafts. Tell me what to fix, or run `/beat:sync` to sync to beat/features/."

**Distill vs Normal Flow**

```
Normal:  Spec -> Code   (write spec first, then implement)
Distill: Code -> Spec   (extract spec from existing code)
              |
         Verification subagent confirms accuracy
              |
         Future changes use normal BDD flow
```

**Guardrails**
- Feature files must describe CURRENT behavior, not desired behavior
- Always use verification subagent -- never self-verify distilled specs
- Mark distilled features with `@distilled` tag for traceability
- If behavior is ambiguous, note it as uncertain rather than guessing
- The user has final say on accuracy -- always present for review
