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
1. /beat:design todo-list with Minimal preset (Gherkin only — skip proposal, design)
2. /beat:apply to implement (write tests and code for each scenario)
3. /beat:verify to validate
4. /beat:archive to finalize (sync features to beat/features/ under a "todo" capability, then archive)

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
assert_skill_invoked "$LOG_FILE" "beat:design" "beat:design invoked"
assert_skill_invoked "$LOG_FILE" "beat:apply" "beat:apply invoked"
assert_skill_invoked "$LOG_FILE" "beat:verify" "beat:verify invoked"
assert_skill_invoked "$LOG_FILE" "beat:archive" "beat:archive invoked"

# Artifact existence (check both active and archived locations — archive moves the directory)
if [[ -f "$PROJECT_DIR/beat/changes/todo-list/status.yaml" ]]; then
    echo -e "${GREEN}[PASS]${NC} status.yaml created (active)"
    PASS_COUNT=$((PASS_COUNT + 1))
    STATUS_DIR="$PROJECT_DIR/beat/changes/todo-list"
elif ls "$PROJECT_DIR/beat/changes/archive/"*todo-list/status.yaml 2>/dev/null | head -1 | grep -q .; then
    echo -e "${GREEN}[PASS]${NC} status.yaml created (archived)"
    PASS_COUNT=$((PASS_COUNT + 1))
    STATUS_DIR=$(dirname "$(ls "$PROJECT_DIR/beat/changes/archive/"*todo-list/status.yaml 2>/dev/null | head -1)")
else
    echo -e "${RED}[FAIL]${NC} status.yaml not found in active or archive"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    STATUS_DIR="$PROJECT_DIR/beat/changes/todo-list"
fi

# Feature files (check active or archived location)
FEATURE_DIR="$STATUS_DIR/features"
FEATURE_COUNT=$(find "$FEATURE_DIR" -name "*.feature" 2>/dev/null | wc -l | tr -d ' ')
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

# Test files (may be in test/, src/, or alongside source files)
TEST_COUNT=$(find "$PROJECT_DIR" -not -path "*/node_modules/*" -not -path "*/.git/*" \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | wc -l | tr -d ' ')
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
FEATURE_FILES=$(find "$FEATURE_DIR" -name "*.feature" 2>/dev/null)
if [[ -n "$FEATURE_FILES" ]]; then
    SCENARIOS_WITHOUT_TAG=0
    while IFS= read -r ff; do
        COUNT=$(grep -c "^[[:space:]]*Scenario:" "$ff" 2>/dev/null) || true
        TAGGED=$(grep -cE "@(e2e|behavior)" "$ff" 2>/dev/null) || true
        COUNT=${COUNT:-0}; TAGGED=${TAGGED:-0}
        MISSING=$((COUNT - TAGGED))
        if [[ "$MISSING" -lt 0 ]]; then MISSING=0; fi
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
        C=$(grep -c "@covered-by" "$ff" 2>/dev/null) || true; C=${C:-0}
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

# Archive moved the change
if [[ -d "$PROJECT_DIR/beat/changes/archive" ]]; then
    ARCHIVE_COUNT=$(find "$PROJECT_DIR/beat/changes/archive" -maxdepth 1 -type d | wc -l | tr -d ' ')
    if [[ "$ARCHIVE_COUNT" -gt 1 ]]; then
        echo -e "${GREEN}[PASS]${NC} Change archived"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Archive directory exists but no archived change"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} No archive directory created"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Features synced to beat/features/
SYNCED_FEATURES=$(find "$PROJECT_DIR/beat/features" -name "*.feature" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SYNCED_FEATURES" -gt 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} Features synced to beat/features/ ($SYNCED_FEATURES files)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No features synced to beat/features/"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# No @no-test tags (removed from Beat workflow)
if [[ -n "$FEATURE_FILES" ]]; then
    NO_TEST_COUNT=0
    while IFS= read -r ff; do
        C=$(grep -c "@no-test\|@no_test" "$ff" 2>/dev/null) || true; C=${C:-0}
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
