#!/bin/bash
# Smoke test: does verify skill know its new enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== verify Enforcement Smoke Tests ==="

output=$(run_claude "As beat:verify, how many dimensions do you check?" 30)
assert_contains "$output" "four\|4" "verify knows it has 4 dimensions"

output=$(run_claude "As beat:verify, what does Dimension 4 check?" 30)
assert_contains "$output" "code.*quality\|code.*review\|code-reviewer" "verify knows Dimension 4 is code quality"

output=$(run_claude "As beat:verify, does Gherkin quality check include testing layer tags?" 30)
assert_contains "$output" "e2e\|behavior\|tag" "verify knows to check @e2e/@behavior tags"

output=$(run_claude "As beat:verify, is @no-test a valid tag in feature files?" 30)
assert_contains "$output" "no\|not\|removed\|invalid" "verify knows @no-test is removed"

print_summary
