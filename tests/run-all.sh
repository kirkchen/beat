#!/bin/bash
# Beat test suite runner.
# Usage: ./run-all.sh [--integration]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo " Beat Skill Test Suite"
echo "========================================="
echo ""

PASS=0
FAIL=0

# Layer 1: Skill Triggering (~5 min)
echo "=== Layer 1: Skill Triggering Tests ==="
if bash "$SCRIPT_DIR/skill-triggering/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 2: Skill Content (~3 min)
echo "=== Layer 2: Skill Content Tests ==="
if bash "$SCRIPT_DIR/skill-content/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 3: Pressure (~15 min)
echo "=== Layer 3: Pressure Tests ==="
if bash "$SCRIPT_DIR/pressure/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 4: Pipeline Integration (opt-in, ~30 min)
if [[ "${1:-}" == "--integration" ]]; then
    echo "=== Layer 4: Pipeline Integration Test ==="
    if bash "$SCRIPT_DIR/pipeline/run-test.sh"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
fi

echo "========================================="
echo " Final: $PASS/$((PASS + FAIL)) test layers passed"
if [[ $FAIL -gt 0 ]]; then
    echo " SOME TESTS FAILED"
    echo "========================================="
    exit 1
else
    echo " ALL TESTS PASSED"
    echo "========================================="
fi
