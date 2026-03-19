# Gherkin Quality Guardrails

**Date:** 2026-03-19
**Status:** Approved
**Scope:** Add Gherkin quality rules to generation and verification skills

## Problem

Beat skills that generate or verify `.feature` files lack explicit quality guardrails. Distill (code → spec) is especially prone to leaking implementation details — concrete numeric thresholds, method names, internal constants — into scenarios that should use business language. The forward-flow skills (continue, ff) partially cover this via granularity assessment but miss specific prohibitions. Verify mentions "Gherkin quality issues" as WARNING but never defines what those are.

## Approach

Inline rules per skill (not a shared reference file), because:
- Beat's design philosophy is self-contained skills
- Generation vs verification need different framing
- Each skill has different levels of existing content to integrate

## Changes

### 1. distill/SKILL.md — Step 4 feature generation

Replace the current two-line guidance with full quality guardrails:

- Each Feature MUST include a business narrative (As a / I want / So that)
- Scenarios use business language. Prohibited leaks:
  - Concrete numeric thresholds (0.85, 1.0) → use business concepts (high confidence / low confidence)
  - Code method names (detect_pii) → use business verbs (check for personal data)
  - Internal constants (context window, checksum weights) → omit or describe effect
  - Exception: API contract constants (entity type names, HTTP status codes) are shared vocabulary and MAY appear
- Repeated Given steps across scenarios MUST use Background:
- Tags must serve a filtering purpose: @happy-path, @edge-case, @error-handling — no decorative tags
- BDD focuses on high-level acceptance (detected / blocked / passed); boundary values and algorithm details belong in unit tests

### 2. distill-subagent-prompt.md — Add check #5

Add a 5th accuracy check for Gherkin quality:
- Do scenarios leak implementation details? (concrete scores, method names, internal constants)
- Does each Feature have a business narrative?
- Are repeated Given steps consolidated into Background?
- Severity: **SUGGESTION** (not CRITICAL) — distill's primary mission is accuracy

Update Output Format summary table and SUGGESTION section accordingly.

### 3. continue/SKILL.md — Supplement existing guidelines

Add a "Gherkin quality constraints" block before the existing granularity assessment. Do not duplicate content already present (SpecFlow template has business narrative; granularity assessment has good/bad examples). Only add:
- Specific prohibited leaks (numeric thresholds, method names, internal constants) with API contract exception
- Background: mandate for repeated Given steps
- Tags must serve filtering purpose — no decorative tags
- BDD focuses on high-level acceptance; boundary values belong in unit tests

### 4. ff/SKILL.md — Expand Gherkin artifact pattern

Expand the single-line Gherkin entry in Artifact patterns to include:
- Business language mandate — no concrete numeric thresholds, code method names, or internal constants (API contract constants OK)
- Repeated Given steps use Background:
- Tags must serve filtering purpose — no decorative tags
- BDD focuses on high-level acceptance; boundary values belong in unit tests

Maintain ff's existing inline paragraph style.

### 5. verify/SKILL.md — Define Gherkin quality checks

Add an explicit "Gherkin Quality Check" section (applies to both gherkin-driven and distill-driven verification):
- Scenario implementation detail leaks (thresholds, method names, constants; API contract exception)
- Feature business narrative presence
- Background: consolidation for repeated Given steps
- Tag filtering purpose
- Severity: **WARNING** (stricter than distill-subagent's SUGGESTION, since verify is the formal quality gate)

### 6. Skill prompt wording — rules.gherkin enforcement

In distill, continue, and ff, add to the config reading paragraph:

> If `rules.gherkin` exists, apply each rule as a hard constraint when generating feature files.

No changes to config-schema.md (schema already defines `rules.gherkin` as `array of strings` with "constraints, not templates" semantics).

## Out of Scope

- No new reference files
- No config-schema.md changes
- No test changes (existing test layers cover skill content awareness)
