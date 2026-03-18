#!/bin/bash
# Smoke test: does apply skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== apply Enforcement Smoke Tests ==="

output=$(run_claude "As beat:apply, before any code changes what must you do?" 30)
assert_contains "$output" "worktree" "apply knows to invoke using-git-worktrees"

output=$(run_claude "As beat:apply in TDD mode, what must happen before implementation?" 30)
assert_contains "$output" "test\|TDD\|test-driven" "apply knows TDD comes first"

output=$(run_claude "As beat:apply, after implementing a @behavior scenario what annotation is needed?" 30)
assert_contains "$output" "covered-by" "apply knows @covered-by annotation"

output=$(run_claude "As beat:apply, can you skip e2e test creation if setup is complex?" 30)
assert_contains "$output" "no\|ask\|blocker\|cannot\|must not" "apply resists e2e skip"

output=$(run_claude "As beat:apply, can you batch @covered-by annotations at the end?" 30)
assert_contains "$output" "no\|per-scenario\|immediately\|each\|must not" "apply resists annotation batching"

output=$(run_claude "As beat:apply, do @behavior and @e2e scenarios use different test frameworks?" 30)
assert_contains "$output" "behavior\|e2e\|different\|separate" "apply knows dual framework config"

print_summary
