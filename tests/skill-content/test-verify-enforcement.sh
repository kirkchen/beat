#!/bin/bash
# Smoke test: does verify skill know its new enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== verify Enforcement Smoke Tests ==="

output=$(run_claude "As beat:verify, how many dimensions do you check?" 30)
assert_contains "$output" "four\|five\|4\|5" "verify knows the number of dimensions (4 + advisory Dimension 5)"

output=$(run_claude "As beat:verify, what does Dimension 4 check?" 30)
assert_contains "$output" "code.*quality\|code.*review\|code-reviewer" "verify knows Dimension 4 is code quality"

output=$(run_claude "As beat:verify, does Gherkin quality check include testing layer tags?" 30)
assert_contains "$output" "e2e\|behavior\|tag" "verify knows to check @e2e/@behavior tags"

output=$(run_claude "As beat:verify, what severity are implementation detail leaks in scenarios — like concrete numeric thresholds or method names?" 30)
assert_contains "$output" "WARNING\|warning" "verify knows implementation detail leaks are WARNING"

output=$(run_claude "As beat:verify, what severity is a missing business narrative in a Feature?" 30)
assert_contains "$output" "WARNING\|warning" "verify knows missing business narrative is WARNING"

output=$(run_claude "As beat:verify, is @no-test a valid tag in feature files?" 30)
assert_contains "$output" "no\|not\|removed\|invalid" "verify knows @no-test is removed"

output=$(run_claude "As beat:verify, what severity should mock-heavy tests receive — where most assertions use toHaveBeenCalledWith instead of checking return values?" 30)
assert_contains "$output" "WARNING\|warning" "verify knows mock-heavy tests are WARNING"

output=$(run_claude "As beat:verify, when status.yaml has gherkin.modified, should you just check that tests exist, or also verify that the test content matches the modified scenario steps?" 30)
assert_contains "$output" "semantic\|content\|match\|step\|align\|reflect\|verif" "verify knows semantic check for modified scenarios"

output=$(run_claude "As beat:verify, can you verify the implementation yourself in the main session, or must you dispatch subagents?" 30)
assert_contains "$output" "subagent\|must.*dispatch\|never.*self\|independent\|cannot.*self\|must not.*self" "verify knows it must dispatch subagents, not self-verify"

output=$(run_claude "As beat:verify, should the verification subagent and code-reviewer be dispatched sequentially or in parallel?" 30)
assert_contains "$output" "parallel\|simultaneous\|both.*same\|at.*same.*time" "verify knows to dispatch subagents in parallel"

output=$(run_claude "As beat:verify, if one subagent fails, can you fall back to self-verification?" 30)
assert_contains "$output" "no\|never\|must not\|cannot\|don't\|proceed.*other\|other.*finding" "verify knows no self-verification fallback"

output=$(run_claude "As beat:verify, what does Dimension 5 check and what severity tier are its findings?" 30)
assert_contains "$output" "living.*doc\|advisory\|WARNING\|warning\|CONTEXT\.md\|ADR\|README\|sync" "verify knows Dimension 5 is living-doc sync, advisory only"

output=$(run_claude "As beat:verify, after presenting the verification report, what must you write to status.yaml?" 30)
assert_contains "$output" "verification" "verify knows to record the verification field in status.yaml"

output=$(run_claude "As beat:verify, what status values can the top-level verification field record?" 30)
assert_contains "$output" "passed\|issues-found" "verify knows verification status values (passed / issues-found)"

output=$(run_claude "As beat:verify, if both verification subagents failed and verification could not run, do you still write a verification record to status.yaml?" 30)
assert_contains "$output" "no\|skip\|don't record\|do not record\|not.*record\|never" "verify knows a failed run records nothing"

print_summary
