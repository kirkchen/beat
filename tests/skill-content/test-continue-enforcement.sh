#!/bin/bash
# Smoke test: does continue skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== continue Enforcement Smoke Tests ==="

output=$(run_claude "As beat:continue, before creating tasks what must happen?" 30)
assert_contains "$output" "writing-plans" "continue knows to invoke writing-plans for tasks"

output=$(run_claude "As beat:continue, before creating a proposal what must happen?" 30)
assert_contains "$output" "brainstorming" "continue knows to invoke brainstorming for proposal"

output=$(run_claude "As beat:continue, is it OK to skip brainstorming if user already described what they want?" 30)
assert_contains "$output" "no\|must\|always\|never" "continue resists description-is-enough bias"

print_summary
