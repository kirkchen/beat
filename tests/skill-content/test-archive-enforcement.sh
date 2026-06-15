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

output=$(run_claude "As beat:archive, before syncing features what scan do you run against beat/CONTEXT.md?" 30)
assert_contains "$output" "term\|glossary\|undefined\|bolded\|CONTEXT\.md\|scan" "archive knows to scan features for undefined terms"

output=$(run_claude "As beat:archive, if zero ADRs were written for this change, what do you do before moving to archive?" 30)
assert_contains "$output" "prompt\|ask\|sweep\|last.mile\|ADR\|record" "archive knows the last-mile ADR sweep"

output=$(run_claude "As beat:archive, before archiving, which top-level field in status.yaml must you check to know whether verification ran?" 30)
assert_contains "$output" "verification" "archive knows to check the verification field before archiving"

output=$(run_claude "As beat:archive, if the verification field is absent (verify never ran), do you archive silently?" 30)
assert_contains "$output" "no\|warn\|confirm\|AskUserQuestion\|never verified" "archive warns and confirms when verification is absent"

output=$(run_claude "As beat:archive, if verification status is issues-found with unresolved criticals, what do you do before archiving?" 30)
assert_contains "$output" "warn\|confirm\|AskUserQuestion\|critical" "archive warns and confirms on issues-found verification"

print_summary
