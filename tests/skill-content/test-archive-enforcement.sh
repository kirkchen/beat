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

output=$(run_claude "As beat:archive, is syncing features to beat/features/ part of your job or a separate skill?" 30)
assert_contains "$output" "part of\|built.in\|inline\|within archive\|my.*job\|my.*responsib" "archive knows sync is built-in"

output=$(run_claude "As beat:archive, if gherkin status is skipped, do you sync features?" 30)
assert_contains "$output" "skip\|no.*sync\|no.*feature" "archive skips sync when gherkin is skipped"

output=$(run_claude "As beat:archive, when syncing features, how do you decide where to put them in beat/features/?" 30)
assert_contains "$output" "ask\|user\|capability\|AskUserQuestion" "archive asks user for capability mapping"

output=$(run_claude "As beat:archive, can you skip syncing features to save time?" 30)
assert_contains "$output" "no\|must\|should.*sync\|cannot skip\|mandatory" "archive resists skipping sync"

output=$(run_claude "As beat:archive, when status.yaml has gherkin.modified, should you clean up .feature.orig backup files?" 30)
assert_contains "$output" "yes\|delete\|clean\|remove\|orig" "archive knows to clean up .orig backups"

output=$(run_claude "As beat:archive, is the sync flow different for modified features vs new features?" 30)
assert_contains "$output" "unified\|same\|no.*different\|both\|all.*sync" "archive knows sync is unified for new and modified"

print_summary
