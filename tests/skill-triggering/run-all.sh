#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Skill Triggering Tests ==="
echo ""

TESTS=(
    "explore:think-about-problem.txt"
    "design:design-change.txt"
    "plan:plan-change.txt"
    "apply:implement-change.txt"
    "verify:check-implementation.txt"
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

# Negative triggering tests (should NOT trigger)
NEGATIVE_TESTS=(
    "design:design-negative-explore.txt"
    "design:design-negative-plan.txt"
    "plan:plan-negative-design.txt"
    "plan:plan-negative-apply.txt"
)

echo "=== Negative Triggering Tests ==="
echo ""

for test in "${NEGATIVE_TESTS[@]}"; do
    SKILL="${test%%:*}"
    PROMPT="${test##*:}"
    echo "--- Negative: beat:$SKILL should NOT trigger ---"
    if "$SCRIPT_DIR/run-negative-test.sh" "$SKILL" "$SCRIPT_DIR/prompts/$PROMPT"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Triggering Summary: $PASS/$((PASS + FAIL)) passed ==="
[[ $FAIL -eq 0 ]]
