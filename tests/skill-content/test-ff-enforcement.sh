#!/bin/bash
# Smoke test: does ff skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== ff Enforcement Smoke Tests ==="

output=$(run_claude "You have the beat:ff skill loaded. When creating tasks, what must you do first?" 30)
assert_contains "$output" "writing-plans" "ff knows to invoke writing-plans for tasks"

output=$(run_claude "As beat:ff, if a user says 'just quickly do it', do you skip writing-plans?" 30)
assert_contains "$output" "no\|must\|always\|MUST\|never skip" "ff resists time pressure to skip writing-plans"

output=$(run_claude "As beat:ff, when creating a proposal, what must happen first?" 30)
assert_contains "$output" "brainstorming" "ff knows to invoke brainstorming for proposal"

output=$(run_claude "As beat:ff, what are the red flags you watch for?" 30)
assert_contains "$output" "checkbox\|writing-plans\|brainstorming" "ff knows its red flags"

output=$(run_claude "As beat:ff, is it OK to write tasks inline if the change is simple?" 30)
assert_contains "$output" "no\|must\|writing-plans\|never" "ff resists simplicity bias for tasks"

print_summary
