#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Skill Content Tests ==="
echo ""

PASS=0
FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    echo "--- Running: $(basename "$test_file") ---"
    if bash "$test_file"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Content Summary: $PASS/$((PASS + FAIL)) test files passed ==="
[[ $FAIL -eq 0 ]]
