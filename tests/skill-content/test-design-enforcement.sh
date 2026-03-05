#!/bin/bash
# Smoke test: does design skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== design Enforcement Smoke Tests ==="

output=$(run_claude "You have the beat:design skill loaded. Before writing any artifact files, what must you do?" 30)
assert_contains "$output" "worktree" "design knows to invoke using-git-worktrees before writing files"

output=$(run_claude "You have the beat:design skill loaded. When creating a proposal, what must happen first?" 30)
assert_contains "$output" "brainstorming" "design knows to invoke brainstorming for proposal"

output=$(run_claude "As beat:design, if a user says 'just quickly do it', do you skip brainstorming?" 30)
assert_contains "$output" "no\|must\|always\|MUST\|never skip" "design resists time pressure to skip brainstorming"

output=$(run_claude "As beat:design, what are the red flags you watch for?" 30)
assert_contains "$output" "brainstorming\|proposal\|prerequisite" "design knows its red flags"

output=$(run_claude "As beat:design, before writing Gherkin, should you check existing feature files?" 30)
assert_contains "$output" "beat/features\|existing.*feature\|scan\|overlap\|duplicat" "design knows to scan existing features before writing gherkin"

output=$(run_claude "As beat:design, can Gherkin scenarios use concrete numeric thresholds or internal constants?" 30)
assert_contains "$output" "no\|prohibit\|must not\|avoid\|business.*language\|leak" "design knows about prohibited implementation detail leaks"

output=$(run_claude "As beat:design, when modifying an existing scenario in beat/features/, what should you do with the original file?" 30)
assert_contains "$output" "orig\|backup\|rename\|copy" "design knows .orig backup for modifications"

output=$(run_claude "As beat:design, if beat/features/auth/login.feature.orig already exists from another change, what should you do?" 30)
assert_contains "$output" "warn\|conflict\|stop\|another.*change\|already.*modif\|cannot\|block\|wait\|exist" "design knows .orig conflict detection"

output=$(run_claude "As beat:design, does it create tasks.md?" 30)
assert_contains "$output" "no\|plan\|not\|separate\|beat:plan" "design knows tasks are handled by /beat:plan"

output=$(run_claude "As beat:design, when does it skip Gherkin?" 30)
assert_contains "$output" "technical\|tooling\|infra\|refactor\|no behavior" "design knows Technical preset skips gherkin"

output=$(run_claude "As beat:design, what is the tasks status after design completes?" 30)
assert_contains "$output" "pending\|not.*create\|beat:plan\|separate" "design knows tasks stay pending after design"

print_summary
