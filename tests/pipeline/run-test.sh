#!/bin/bash
# Run Beat pipeline end-to-end test.
# Usage: ./run-test.sh [--plugin-dir /path/to/beat]
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Pipeline Integration Test ==="
echo "This test runs new -> ff -> apply -> verify and takes 15-30 minutes."
echo ""

# Scaffold project
PROJECT_DIR="$OUTPUT_BASE/pipeline-node-todo/project"
mkdir -p "$(dirname "$PROJECT_DIR")"
bash "$SCRIPT_DIR/node-todo/scaffold.sh" "$PROJECT_DIR"

PROMPT='Use the Beat BDD workflow to build a simple todo list module with in-memory storage.
Requirements: add todo (title), list all todos, mark todo as complete.

Execute these skills in sequence — do NOT use brainstorming, go directly to Beat skills:
1. /beat:new todo-list
2. /beat:ff with Minimal preset (Gherkin only — skip proposal, design, tasks)
3. /beat:apply to implement (write tests and code for each scenario)
4. /beat:verify to validate

Keep it simple. 3 scenarios max. Complete the full pipeline without stopping.'

# Run Claude
LOG_FILE="$OUTPUT_BASE/pipeline-node-todo/session.json"
cd "$PROJECT_DIR"
echo "Running claude -p (max-turns 80, timeout 1800s)..."
echo "Output: $LOG_FILE"
_run_with_timeout 1800 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns 80 \
    --output-format stream-json \
    --verbose \
    --dangerously-skip-permissions \
    > "$LOG_FILE" 2>&1 || true

echo ""
echo "=== Verification ==="
echo ""

# Skill invocations
assert_skill_invoked "$LOG_FILE" "beat:new" "beat:new invoked"
assert_skill_invoked "$LOG_FILE" "beat:ff" "beat:ff invoked"
assert_skill_invoked "$LOG_FILE" "beat:apply" "beat:apply invoked"
assert_skill_invoked "$LOG_FILE" "beat:verify" "beat:verify invoked"

# Artifact existence
assert_file_exists "$PROJECT_DIR/beat/changes/todo-list/status.yaml" "status.yaml created"

# Feature files
FEATURE_COUNT=$(find "$PROJECT_DIR/beat/changes/todo-list/features" -name "*.feature" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FEATURE_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} Feature files created ($FEATURE_COUNT files)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No feature files created"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Source code
SRC_COUNT=$(find "$PROJECT_DIR/src" -name "*.ts" -o -name "*.js" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SRC_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} Source code created ($SRC_COUNT files)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No source code created"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test files
TEST_COUNT=$(find "$PROJECT_DIR/test" -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TEST_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} Test files created ($TEST_COUNT files)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No test files created"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Tests pass
echo "Running tests..."
cd "$PROJECT_DIR"
if npx vitest run --reporter=verbose 2>&1; then
    echo -e "${GREEN}[PASS]${NC} Tests pass"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Tests failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Verify report
if grep -q "Verify Report\|verify.*report\|Verification" "$LOG_FILE" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Verify report generated"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No verify report found in output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Code reviewer dispatched during verify (Dimension 4)
if grep -q "superpowers:code-reviewer\|code.reviewer\|code quality" "$LOG_FILE" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Code reviewer dispatched"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Code reviewer not dispatched during verify"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Gherkin quality: scenarios have testing layer tags (@e2e or @behavior)
FEATURE_FILES=$(find "$PROJECT_DIR/beat/changes/todo-list/features" -name "*.feature" 2>/dev/null)
if [[ -n "$FEATURE_FILES" ]]; then
    SCENARIOS_WITHOUT_TAG=0
    while IFS= read -r ff; do
        COUNT=$(grep -c "^[[:space:]]*Scenario:" "$ff" 2>/dev/null || echo 0)
        TAGGED=$(grep -cE "@(e2e|behavior)" "$ff" 2>/dev/null || echo 0)
        MISSING=$((COUNT - TAGGED))
        SCENARIOS_WITHOUT_TAG=$((SCENARIOS_WITHOUT_TAG + MISSING))
    done <<< "$FEATURE_FILES"
    if [[ "$SCENARIOS_WITHOUT_TAG" -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} All scenarios have testing layer tags (@e2e/@behavior)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} $SCENARIOS_WITHOUT_TAG scenario(s) missing @e2e/@behavior tag"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} No feature files to check for tags"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# @covered-by annotations in feature files (added during apply)
if [[ -n "$FEATURE_FILES" ]]; then
    COVERED_COUNT=0
    while IFS= read -r ff; do
        C=$(grep -c "@covered-by" "$ff" 2>/dev/null || echo 0)
        COVERED_COUNT=$((COVERED_COUNT + C))
    done <<< "$FEATURE_FILES"
    if [[ "$COVERED_COUNT" -gt 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} @covered-by annotations present ($COVERED_COUNT found)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} No @covered-by annotations in feature files"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

# No @no-test tags (removed from Beat workflow)
if [[ -n "$FEATURE_FILES" ]]; then
    NO_TEST_COUNT=0
    while IFS= read -r ff; do
        C=$(grep -c "@no-test\|@no_test" "$ff" 2>/dev/null || echo 0)
        NO_TEST_COUNT=$((NO_TEST_COUNT + C))
    done <<< "$FEATURE_FILES"
    if [[ "$NO_TEST_COUNT" -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} No @no-test tags (correctly removed)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Found $NO_TEST_COUNT @no-test tag(s) — should not exist"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

# Token analysis
echo ""
echo "=== Token Usage ==="
python3 "$TESTS_DIR/analyze-token-usage.py" "$LOG_FILE" 2>/dev/null || echo "(token analysis unavailable)"

print_summary
