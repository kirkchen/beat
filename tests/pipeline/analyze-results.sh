#!/bin/bash
# Analyze results from a pipeline test run.
# Usage: ./analyze-results.sh <log-file> <project-dir>
set -euo pipefail

LOG_FILE="${1:?Usage: analyze-results.sh <log-file> <project-dir>}"
PROJECT_DIR="${2:?}"

echo "=== Pipeline Results Analysis ==="
echo ""

echo "Skills invoked:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn || echo "  (none found)"

echo ""
echo "Tools used:"
grep -o '"name":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -20 || echo "  (none found)"

echo ""
echo "Files created in project:"
cd "$PROJECT_DIR"
git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --stat 2>/dev/null || find . -newer .git -not -path './.git/*' -not -path './node_modules/*' | head -30

echo ""
echo "Beat change status:"
cat beat/changes/*/status.yaml 2>/dev/null || echo "  (no status.yaml found)"
