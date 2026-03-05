#!/bin/bash
# Smoke test: does plan skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== plan Enforcement Smoke Tests ==="

output=$(run_claude "You have the beat:plan skill loaded. Before writing any files, what must you do?" 30)
assert_contains "$output" "worktree" "plan knows to invoke using-git-worktrees before writing files"

output=$(run_claude "You have the beat:plan skill loaded. When creating tasks, what must you do first?" 30)
assert_contains "$output" "writing-plans" "plan knows to invoke writing-plans for tasks"

output=$(run_claude "As beat:plan, if a user says 'just quickly do it', do you skip writing-plans?" 30)
assert_contains "$output" "no\|must\|always\|MUST\|never skip" "plan resists time pressure to skip writing-plans"

output=$(run_claude "As beat:plan, what are the red flags you watch for?" 30)
assert_contains "$output" "checkbox\|writing-plans\|spec.*artifact" "plan knows its red flags"

output=$(run_claude "As beat:plan, is it OK to write tasks inline if the change is simple?" 30)
assert_contains "$output" "no\|must\|writing-plans\|never" "plan resists simplicity bias for tasks"

output=$(run_claude "As beat:plan, what are the task decomposition principles?" 30)
assert_contains "$output" "single concern\|200\|LOC\|2-3 files\|independently verifiable\|and then" "plan knows task decomposition principles"

output=$(run_claude "As beat:plan, should tasks.md include a Quality Principles header?" 30)
assert_contains "$output" "yes\|behavior\|wiring\|mock\|testing\|300" "plan knows quality principles header"

output=$(run_claude "As beat:plan, what must exist before you can create tasks?" 30)
assert_contains "$output" "gherkin\|proposal\|spec.*artifact\|design" "plan knows spec artifacts are required"

output=$(run_claude "As beat:plan, does it include a review step?" 30)
assert_contains "$output" "review\|subagent\|multi.*role\|perspective" "plan knows about multi-role review"

output=$(run_claude "As beat:plan, can you proceed if no gherkin and no proposal are done?" 30)
assert_contains "$output" "no\|cannot\|must\|stop\|design.*first\|require" "plan refuses without spec artifacts"

output=$(run_claude "As beat:plan, what happens if the review subagent fails or returns empty?" 30)
assert_contains "$output" "fallback\|proceed\|initial\|continue\|without.*review\|as-is\|re-run\|graceful\|skip" "plan knows review fallback"

print_summary
