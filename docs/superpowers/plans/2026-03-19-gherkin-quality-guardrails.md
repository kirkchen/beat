# Gherkin Quality Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Gherkin quality guardrails to Beat's generation and verification skills to prevent implementation detail leakage in feature files.

**Architecture:** Inline rules per skill (no shared reference file). Generation skills get creation-time constraints; verification skills get check-time criteria. Each edit preserves existing content and integrates with the skill's existing structure.

**Tech Stack:** Markdown skill files (no code, no tests — these are LLM prompt files)

**Spec:** `docs/superpowers/specs/2026-03-19-gherkin-quality-guardrails-design.md`

---

### Task 1: distill/SKILL.md — Extend feature generation guidance

**Files:**
- Modify: `skills/distill/SKILL.md:46-50`

- [ ] **Step 1: Read current content at lines 46-50**

Current content to preserve:
```markdown
   **features/*.feature (mandatory):**
   - Write feature files describing CURRENT behavior (not desired behavior)
   - Each scenario must accurately reflect what the code actually does
   - Use tags: `@distilled` (always), plus `@happy-path`, `@error-handling`, `@edge-case`
   - Use SpecFlow style with rich description areas
```

- [ ] **Step 2: Add quality guardrails after line 50**

Insert after `- Use SpecFlow style with rich description areas`:

```markdown
   - Each Feature MUST include a business narrative (As a / I want / So that)
   - Scenarios use business language. Prohibited leaks:
     - Concrete numeric thresholds (0.85, 1.0) → use business concepts (high confidence / low confidence)
     - Code method names (detect_pii) → use business verbs (check for personal data)
     - Internal constants (context window, checksum weights) → omit or describe effect
     - Exception: API contract constants (entity type names, HTTP status codes) are shared vocabulary and MAY appear
   - Repeated Given steps across scenarios MUST use Background:
   - Tags must serve a filtering purpose: `@happy-path`, `@edge-case`, `@error-handling` — no decorative tags
   - BDD focuses on high-level acceptance (detected / blocked / passed); boundary values and algorithm details belong in unit tests
   - Every scenario MUST have a testing layer tag (`@e2e` or `@behavior`, default `@behavior`)
```

- [ ] **Step 3: Verify the edit**

Read `skills/distill/SKILL.md` lines 46-62. Confirm:
- Original 4 lines preserved (CURRENT behavior, @distilled, SpecFlow)
- New guardrails appear after them
- No duplicate content

- [ ] **Step 4: Commit**

```bash
git add skills/distill/SKILL.md
git commit -m "feat(distill): add Gherkin quality guardrails to feature generation"
```

---

### Task 2: distill-subagent-prompt.md — Add Gherkin quality check #5

**Files:**
- Modify: `skills/distill/distill-subagent-prompt.md:32-57`

- [ ] **Step 1: Add check #5 after check #4 (after line 32)**

Insert after the check #4 block (`Missing test → SUGGESTION`):

```markdown

5. **Gherkin quality check**
   - Do scenarios leak implementation details? (concrete numeric thresholds, method names, internal constants)
     - API contract constants (entity type names, HTTP status codes) are acceptable as shared vocabulary
   - Does each Feature have a business narrative (As a / I want / So that)?
   - Are repeated Given steps consolidated into Background?
   - Quality issues → SUGGESTION
```

- [ ] **Step 2: Add Gherkin Quality row to Summary table (after line 43)**

In the Output Format summary table, add after `| Coverage Completeness |`:

```markdown
| Gherkin Quality | pass/partial | N |
```

- [ ] **Step 3: Update SUGGESTION section header (line 50)**

Change:
```markdown
### SUGGESTION (uncovered behaviors, missing tests)
```
To:
```markdown
### SUGGESTION (uncovered behaviors, missing tests, quality issues)
```

- [ ] **Step 4: Verify the edit**

Read full file. Confirm:
- 5 checks total (original 4 + new #5)
- Summary table has 3 rows
- SUGGESTION section header updated
- Severity is SUGGESTION, not CRITICAL

- [ ] **Step 5: Commit**

```bash
git add skills/distill/distill-subagent-prompt.md
git commit -m "feat(distill): add Gherkin quality check to verification subagent"
```

---

### Task 3: continue/SKILL.md — Add quality constraints before granularity assessment

**Files:**
- Modify: `skills/continue/SKILL.md:155-161`

- [ ] **Step 1: Insert quality constraints block**

Insert after `Update status.yaml: gherkin -> done, phase -> gherkin` (line 157) and before the `---` separator (line 159), which places it before the Granularity Assessment section:

```markdown

   **Gherkin quality constraints:**
   - Scenarios use business language. Prohibited leaks:
     - Concrete numeric thresholds (0.85, 1.0) → use business concepts (high confidence / low confidence)
     - Code method names (detect_pii) → use business verbs (check for personal data)
     - Internal constants (context window, checksum weights) → omit or describe effect
     - Exception: API contract constants (entity type names, HTTP status codes) are shared vocabulary and MAY appear
   - Repeated Given steps across scenarios MUST use Background:
   - Tags must serve a filtering purpose: `@happy-path`, `@edge-case`, `@error-handling` — no decorative tags
   - BDD focuses on high-level acceptance (detected / blocked / passed); boundary values and algorithm details belong in unit tests

```

- [ ] **Step 2: Verify the edit**

Read `skills/continue/SKILL.md` lines 149-175. Confirm:
- Quality constraints block appears after testing layer tags section
- Granularity assessment still follows after
- No duplication with existing business narrative (already in SpecFlow template at line 125) or existing good/bad examples (lines 174-186)

- [ ] **Step 3: Commit**

```bash
git add skills/continue/SKILL.md
git commit -m "feat(continue): add Gherkin quality constraints to feature generation"
```

---

### Task 4: ff/SKILL.md — Expand Gherkin artifact pattern

**Files:**
- Modify: `skills/ff/SKILL.md:143`

- [ ] **Step 1: Replace Gherkin paragraph**

Replace the current Gherkin bullet (line 143):
```markdown
   - **Gherkin**: SpecFlow style, tags `@happy-path`/`@error-handling`/`@edge-case`, Feature description carries PRD essence. Every scenario MUST have a testing layer tag (`@e2e` for user journeys needing a running app, or `@behavior` for business logic testable without a full app; default `@behavior`). Write scenarios at behavior level — describe what the system does ("Monthly billing adjusts for short months"), not how a function works ("calculateNextTransactionDate clamps to last day"). If option 4 (Technical) was chosen, skip gherkin entirely.
```

With:
```markdown
   - **Gherkin**: SpecFlow style, tags `@happy-path`/`@error-handling`/`@edge-case`, Feature description carries PRD essence (must include business narrative: As a / I want / So that). Every scenario MUST have a testing layer tag (`@e2e` for user journeys needing a running app, or `@behavior` for business logic testable without a full app; default `@behavior`). Write scenarios at behavior level — describe what the system does ("Monthly billing adjusts for short months"), not how a function works ("calculateNextTransactionDate clamps to last day"). Scenarios use business language — no concrete numeric thresholds, code method names, or internal constants (API contract constants are OK as shared vocabulary). Repeated Given steps use Background:. Tags must serve a filtering purpose — no decorative tags. BDD focuses on high-level acceptance; boundary values and algorithm details belong in unit tests. If option 4 (Technical) was chosen, skip gherkin entirely.
```

- [ ] **Step 2: Verify the edit**

Read `skills/ff/SKILL.md` lines 141-146. Confirm:
- Single paragraph style preserved
- New rules added: business narrative, prohibited leaks, Background, tag purpose, BDD focus
- Original content preserved (SpecFlow style, testing layer tags, behavior level, option 4 skip)

- [ ] **Step 3: Commit**

```bash
git add skills/ff/SKILL.md
git commit -m "feat(ff): add Gherkin quality rules to artifact pattern"
```

---

### Task 5: verification-subagent-prompt.md — Extend Section 1A quality checks

**Files:**
- Modify: `skills/verify/verification-subagent-prompt.md:34-57`

- [ ] **Step 1: Extend Scenario level checks in Section 1A (after line 46)**

After the existing `@e2e` vs `@behavior` misclassification check (ending at line 46 with `Misclassified → SUGGESTION`), add:

```markdown
- Do scenarios leak implementation details?
  - Concrete numeric thresholds (0.85, 1.0) instead of business concepts → WARNING
  - Code method names (detect_pii) instead of business verbs → WARNING
  - Internal constants (context window, checksum weights) → WARNING
  - Exception: API contract constants (entity type names, HTTP status codes) are shared vocabulary and OK
- Are repeated Given steps across scenarios not consolidated into Background? → WARNING
- Do any tags lack a filtering purpose (decorative tags with no test selection use)? → SUGGESTION
```

- [ ] **Step 2: Elevate Feature description check (line 54-55)**

Change:
```markdown
- Does the Feature have a description (As a / I want / So that or equivalent business context)?
  - Missing description → SUGGESTION
```
To:
```markdown
- Does the Feature have a business narrative (As a / I want / So that or equivalent business context)?
  - Missing narrative → WARNING
```

- [ ] **Step 3: Verify the edit**

Read `skills/verify/verification-subagent-prompt.md` lines 34-65. Confirm:
- New checks inserted after existing @e2e/@behavior check
- Implementation detail leak check is WARNING (not SUGGESTION)
- Feature narrative elevated from SUGGESTION to WARNING
- API contract exception included
- No duplication with existing function-level indicator check (the new checks are more specific — they extend it)

- [ ] **Step 4: Commit**

```bash
git add skills/verify/verification-subagent-prompt.md
git commit -m "feat(verify): define explicit Gherkin quality checks in verification subagent"
```
