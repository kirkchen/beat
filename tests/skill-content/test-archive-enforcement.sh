#!/bin/bash
# Smoke test: does archive skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== archive Enforcement Smoke Tests ==="

output=$(run_claude "As beat:archive, after archiving a change what must you invoke?" 30)
assert_contains "$output" "finishing.*branch\|finishing-a-development-branch" "archive knows to invoke finishing-a-development-branch"

output=$(run_claude "As beat:archive, if some artifacts are still pending, do you block the archive?" 30)
assert_contains "$output" "no\|warn\|confirm\|don't block\|proceed" "archive knows warnings don't block — just confirm"

output=$(run_claude "As beat:archive, what format is the archived directory name?" 30)
assert_contains "$output" "YYYY-MM-DD\|date" "archive knows date-prefixed directory format"

print_summary
