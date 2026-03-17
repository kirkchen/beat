#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Pressure Tests ==="
echo ""

PASS=0
FAIL=0

for scenario in "$SCRIPT_DIR"/scenarios/*.txt; do
    echo "--- $(basename "$scenario" .txt) ---"
    if bash "$SCRIPT_DIR/run-test.sh" "$scenario"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Pressure Summary: $PASS/$((PASS + FAIL)) passed ==="
[[ $FAIL -eq 0 ]]
