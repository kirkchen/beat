#!/bin/bash
# Smoke test: does setup skill know about dual framework config?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== setup Enforcement Smoke Tests ==="

output=$(run_claude "As beat:setup, when asking about testing, do you ask for both behavior and e2e frameworks?" 30)
assert_contains "$output" "behavior\|e2e\|both\|separate" "setup knows to ask about dual frameworks"

output=$(run_claude "As beat:setup, what fields does the testing config have?" 30)
assert_contains "$output" "behavior\|e2e\|required" "setup knows testing config fields"

print_summary
