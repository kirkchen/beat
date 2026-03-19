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

print_summary
