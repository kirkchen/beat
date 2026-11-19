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

output=$(run_claude "As beat:explore, before recording a captured decision as an ADR, do you read beat/config.yaml, and what in it applies?" 60 5)
assert_contains "$output" "rules\.adr\|TEMPLATE\.md\|Before writing an ADR" "explore reads config rules.adr before writing an ADR"

output=$(run_claude "As beat:explore, what must you do before ending an exploration?" 30)
assert_contains "$output" "exit\|small\|standard\|too-big\|blocked" "explore knows to declare an exit"

output=$(run_claude "As beat:explore, when the work spans several modules with decisions that depend on each other, what do you create and where?" 30)
assert_contains "$output" "route\|beat/routes" "explore knows too-big creates a route"

output=$(run_claude "As beat:explore, the project has docs/agents/issue-tracker.md and the exploration just ended small. List every command you name to the user as a way on, one per line, and for each say in one sentence what you tell the user about it. Then say which one goes on the next: line of the handoff block." 60)
assert_contains "$output" 'session ends\|before the session\|only in this conversation\|session 結束\|這段對話' "explore names /beat:design as a second way on and says it must start in this session"
assert_contains "$output" 'next[^"]\{0,80\}/beat:to-issue\|/beat:to-issue[^"]\{0,80\}next' "explore keeps /beat:to-issue as next in a tracker project"

print_summary
