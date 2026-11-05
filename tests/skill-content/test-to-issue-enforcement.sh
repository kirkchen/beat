#!/bin/bash
# Smoke test: does to-issue know its enforcement rules?
# Every assertion checks only the final answer (assert_output_matches): the
# whole stream also holds SKILL.md text, which already contains these words.
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== to-issue Enforcement Smoke Tests ==="

log="$OUTPUT_BASE/to-issue-no-tracker.jsonl"
run_claude "As beat:to-issue, the project has no docs/agents/issue-tracker.md file, but git remote points at GitHub. The exploration just ended small. Do you open the issue anyway? Start your answer with Yes or No, then quote exactly what you tell the user." 60 > "$log"
assert_output_matches "$log" '"result":"[^a-z]*no\b' "to-issue does not open an issue without docs/agents/issue-tracker.md"
assert_output_matches "$log" 'Run /beat:setup to create it' "to-issue prints the exact refusal line naming /beat:setup"

log="$OUTPUT_BASE/to-issue-dispatch-label.jsonl"
run_claude "As beat:to-issue, the exploration ended standard and the user said only 'open an issue for this'. Do you add the dispatch label (e.g. rhythm-change) to the new issue? Start your answer with Yes or No." 60 > "$log"
assert_output_matches "$log" '"result":"[^a-z]*no\b' "to-issue does not add the dispatch label unless asked"

log="$OUTPUT_BASE/to-issue-too-big.jsonl"
run_claude "As beat:to-issue: the exploration ended too-big but beat/routes/checkout-revamp/ does not exist. Do you create the issues? Start your answer with Yes or No, then say what you tell the user." 60 > "$log"
assert_output_matches "$log" '"result":"[^a-z]*no\b' "to-issue does not create issues for too-big without a route"
assert_output_matches "$log" '(rerun|re-run|重新跑|重跑)[^.。]{0,20}/beat:explore|no route|沒有 route|route 不存在' "to-issue sends too-big without a route back to /beat:explore"

log="$OUTPUT_BASE/to-issue-locked-heading.jsonl"
run_claude "As beat:to-issue, in a project whose beat/config.yaml has language: zh-TW, what is the exact markdown heading (with ##) for the decisions the user agreed to? Reply with the heading only." 60 > "$log"
assert_output_matches "$log" '## 已定案（不要重新討論）' "to-issue uses the exact locked-decisions heading"

print_summary
