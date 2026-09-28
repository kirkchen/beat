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

output=$(run_claude "As beat:archive, when syncing a change that has a design.md and beat/features/<capability>/design.md already exists, do you copy the change's design.md over it?" 90 5)
assert_contains "$output" "Supersedes\|## History\|Copy if absent\|append one line under" "archive merges design.md instead of overwriting the capability copy"

output=$(run_claude "As beat:archive, after moving the change directory into beat/changes/archive/, what do you do about files that still reference the old beat/changes/<name> path?" 90 5)
assert_contains "$output" "git grep\|References rewritten\|step 5b\|5b\.\|Rewrite references to the old change path" "archive rewrites stale references to the old change path"

output=$(run_claude "As beat:archive, when the user adds a new glossary term during the pre-sync scan, where in beat/CONTEXT.md does it go?" 60 5)
assert_contains "$output" "Where a new entry goes\|<group>\|before .## Relationships\|full skeleton" "archive inserts glossary terms into their section, not the file end"

output=$(run_claude "As beat:archive, when the last-mile sweep results in writing an ADR, what do you read or check before writing the file?" 60 5)
assert_contains "$output" "rules\.adr\|TEMPLATE\.md\|Before writing an ADR" "archive applies config rules.adr and project TEMPLATE.md before writing an ADR"

output=$(run_claude "As beat:archive, should a change be archived before its pull request is opened, or only after the PR is merged?" 60 5)
assert_contains "$output" "last commit on the\|before the PR\|before opening the PR\|never after\|same PR" "archive runs before the PR, not after merge"

output=$(run_claude "As beat:archive, after rewriting references to the old change path, what must you do before invoking finishing-a-development-branch?" 60 5)
assert_contains "$output" "5c\|Commit the archive\|archive(<name>)\|archive(" "archive commits its result before handing off to finishing-a-development-branch"

print_summary
