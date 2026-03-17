#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Skill Triggering Tests ==="
echo ""

TESTS=(
    "new:start-new-feature.txt"
    "explore:think-about-problem.txt"
    "continue:next-step.txt"
    "ff:create-all-specs.txt"
    "apply:implement-change.txt"
    "verify:check-implementation.txt"
    "sync:update-docs.txt"
    "archive:finalize-change.txt"
    "setup:setup-beat.txt"
    "distill:extract-specs.txt"
)

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do
    SKILL="${test%%:*}"
    PROMPT="${test##*:}"
    echo "--- Testing: beat:$SKILL ---"
    if "$SCRIPT_DIR/run-test.sh" "$SKILL" "$SCRIPT_DIR/prompts/$PROMPT"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Triggering Summary: $PASS/$((PASS + FAIL)) passed ==="
[[ $FAIL -eq 0 ]]
