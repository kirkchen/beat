#!/bin/bash
# Smoke test: does to-issue know its enforcement rules?
# Every assertion checks only the final answer (assert_output_matches): the
# whole stream also holds SKILL.md text, which already contains these words.
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== to-issue Enforcement Smoke Tests ==="

log="$OUTPUT_BASE/to-issue-no-tracker.jsonl"
run_claude "As beat:to-issue, the project has no docs/agents/issue-tracker.md file. The user asks you to open an issue for the exploration that just ended small. What exactly do you do?" 60 > "$log"
assert_output_matches "$log" '/beat:setup' "to-issue refuses without docs/agents/issue-tracker.md and names /beat:setup"

log="$OUTPUT_BASE/to-issue-dispatch-label.jsonl"
run_claude "As beat:to-issue, the exploration ended standard and the user said only 'open an issue for this'. Do you add the dispatch label (e.g. rhythm-change) to the new issue? Start your answer with Yes or No." 60 > "$log"
assert_output_matches "$log" '"result":"[^a-z]*no\b' "to-issue does not add the dispatch label unless asked"

log="$OUTPUT_BASE/to-issue-too-big.jsonl"
run_claude "As beat:to-issue, the exploration's handoff declared exit too-big, but there is no directory under beat/routes/ for it. Do you create the issues anyway? What do you do instead?" 60 > "$log"
assert_output_matches "$log" '/beat:explore' "to-issue requires an existing route for too-big"

log="$OUTPUT_BASE/to-issue-locked-heading.jsonl"
run_claude "As beat:to-issue, in a project whose beat/config.yaml has language: zh-TW, what is the exact markdown heading (with ##) for the decisions the user agreed to? Reply with the heading only." 60 > "$log"
assert_output_matches "$log" '## 已定案（不要重新討論）' "to-issue uses the exact locked-decisions heading"

print_summary
