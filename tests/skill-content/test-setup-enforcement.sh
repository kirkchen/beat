#!/bin/bash
# Smoke test: does setup skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== setup Enforcement Smoke Tests ==="

output=$(run_claude "As beat:setup, when asking about testing, do you ask for both behavior and e2e frameworks?" 30)
assert_contains "$output" "behavior\|e2e\|both\|separate" "setup knows to ask about dual frameworks"

output=$(run_claude "As beat:setup, what fields does the testing config have?" 30)
assert_contains "$output" "behavior\|e2e\|required" "setup knows testing config fields"

output=$(run_claude "As beat:setup, do you check if superpowers is installed?" 30)
assert_contains "$output" "yes\|check\|superpowers\|available\|install" "setup knows to check superpowers dependency"

output=$(run_claude "As beat:setup, does the project type affect which e2e framework you recommend?" 30)
assert_contains "$output" "web.*app\|API\|CLI\|library\|project.*type\|depends" "setup knows project type affects e2e recommendation"

output=$(run_claude "As beat:setup, for a Python web app, what e2e framework would you recommend?" 30)
assert_contains "$output" "behave\|cucumber\|BDD" "setup recommends BDD runner for Python"

output=$(run_claude "As beat:setup, does a Library project need an e2e framework?" 30)
assert_contains "$output" "no\|not needed\|omit\|sufficient\|skip\|unnecessary" "setup knows Library projects don't need e2e"

# The next two check only the final answer (assert_output_matches): the whole
# stream also holds the SessionStart context and SKILL.md text, which already
# contain these words.
log="$OUTPUT_BASE/setup-issue-tracker.jsonl"
run_claude "As beat:setup, which file do you write to record how this project's issue tracker works (tracker, assignee, dispatch label)? Give the exact path." 30 > "$log"
assert_output_matches "$log" 'docs/agents/issue-tracker\.md' "setup knows it writes docs/agents/issue-tracker.md"

log="$OUTPUT_BASE/setup-glossary.jsonl"
run_claude "As beat:setup, do you create the project's domain glossary file during setup? Answer yes or no and name the file." 30 > "$log"
assert_output_matches "$log" '\b(no|never|not|lazy|lazily)\b[^.]*GLOSSARY\.md|不會|不建立' "setup does not create GLOSSARY.md"

print_summary
