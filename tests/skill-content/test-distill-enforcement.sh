#!/bin/bash
# Smoke test: does distill skill know its Gherkin quality rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== distill Enforcement Smoke Tests ==="

output=$(run_claude "As beat:distill, what are the rules for writing feature files? What leaks are prohibited?" 30)
assert_contains "$output" "business.*narrative\|As a.*I want\|business.*language" "distill knows business narrative requirement"

output=$(run_claude "As beat:distill, can scenarios include concrete numeric thresholds like 0.85 or method names like detect_pii?" 30)
assert_contains "$output" "no\|prohibit\|must not\|avoid\|business" "distill knows about prohibited implementation detail leaks"

output=$(run_claude "As beat:distill, are API contract constants like entity type names or HTTP status codes allowed in scenarios?" 30)
assert_contains "$output" "yes\|allowed\|acceptable\|shared.*vocabulary\|MAY\|OK\|exception" "distill knows API contract exception"

output=$(run_claude "As beat:distill, must you invoke using-git-worktrees before writing any files?" 30)
assert_contains "$output" "yes\|must\|MUST\|before.*writ\|worktree" "distill knows worktree isolation is required"

output=$(run_claude "As beat:distill, should you scan existing feature files before generating new ones?" 30)
assert_contains "$output" "yes\|scan\|check\|existing\|duplicate\|overlap" "distill knows to scan existing features"

output=$(run_claude "As beat:distill, should you commit artifacts before presenting to the user?" 30)
assert_contains "$output" "yes\|commit\|git" "distill knows to commit before presenting"

output=$(run_claude "As beat:distill, can you verify the distilled scenarios yourself, or must you use /beat:verify?" 30)
assert_contains "$output" "verify\|independent\|never.*self\|cannot.*self\|must not.*self\|subagent" "distill knows it cannot self-verify"

output=$(run_claude "As beat:distill, what tag must all distilled scenarios have?" 30)
assert_contains "$output" "distilled\|@distilled" "distill knows @distilled tag is required"

output=$(run_claude "As beat:distill, before writing feature files, what check must you run against beat/CONTEXT.md?" 30)
assert_contains "$output" "glossary\|term\|CONTEXT\.md\|bolded\|four.challenge" "distill knows the glossary check before feature files"

output=$(run_claude "As beat:distill, for a Key Decision recovered from code where the rationale isn't in the evidence, do you invent a plausible why for the ADR?" 30)
assert_contains "$output" "no\|never\|unverified\|unconfirmed\|don't invent\|do not invent\|ask" "distill knows never to invent ADR rationale"

output=$(run_claude "As beat:distill, after you finish distilling, which skill confirms the scenarios match the code — is it plan, apply, or verify?" 30)
assert_contains "$output" "verify" "distill routes its exit to /beat:verify (accuracy mode), not plan/apply"

output=$(run_claude "As beat:distill, when creating the status.yaml for a distill change, what status do you set for tasks?" 30)
assert_contains "$output" "skipped\|skip" "distill sets tasks status to skipped"

output=$(run_claude "As beat:distill, after writing each artifact, what self-review must you run?" 30)
assert_contains "$output" "four.check\|self-review\|placeholder\|consistency\|scope\|ambiguity" "distill knows the four-check spec self-review"

print_summary
