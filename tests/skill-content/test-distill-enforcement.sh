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

print_summary
