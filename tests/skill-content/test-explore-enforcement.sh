#!/bin/bash
# Smoke test: does explore skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== explore Enforcement Smoke Tests ==="

output=$(run_claude "As beat:explore, what must you invoke before entering explore mode?" 30)
assert_contains "$output" "brainstorming" "explore knows to invoke brainstorming"

output=$(run_claude "As beat:explore, can you write application code or implement features?" 30)
assert_contains "$output" "no\|never\|must not\|don't\|cannot" "explore knows no-implementation guardrail"

output=$(run_claude "As beat:explore, should you automatically capture insights to Beat artifacts?" 30)
assert_contains "$output" "no\|offer\|ask\|don't auto" "explore knows not to auto-capture"

print_summary
