#!/bin/bash
# Run Beat modify-feature pipeline end-to-end test.
# Tests: plan (modify existing) -> apply (update existing tests) -> verify (semantic) -> archive (.orig cleanup)
# Usage: ./run-test.sh
set -euo pipefail
source "$(dirname "$0")/../../test-helpers.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Modify-Feature Pipeline Test ==="
echo "Tests .orig backup, Generate vs Update, semantic verification, and .orig cleanup."
echo ""

# Scaffold project with existing features + tests
PROJECT_DIR="$OUTPUT_BASE/pipeline-modify-feature/project"
mkdir -p "$(dirname "$PROJECT_DIR")"
bash "$SCRIPT_DIR/scaffold.sh" "$PROJECT_DIR"

PROMPT='I need to add rate limiting to the login feature. After 3 failed attempts, the account should be locked.

This MODIFIES the existing login behavior in beat/features/auth/login.feature — the "wrong password" scenario should now also track failed attempts.

Execute these Beat skills in sequence:
1. /beat:design add-rate-limiting with Minimal preset (Gherkin only). This modifies an existing feature file, so follow the .orig backup mechanism: rename the original to .feature.orig, copy to changes/, then modify.
2. /beat:apply to implement (update the existing tests in test/login.test.ts for modified scenarios, generate new tests for new scenarios)
3. /beat:verify to validate (should perform semantic verification on modified scenarios)
4. /beat:archive to finalize (sync features, clean up .orig backups)

Important: the existing test file at test/login.test.ts should be UPDATED for modified scenarios, not replaced with a new file. Complete the full pipeline without stopping.'

# Run Claude
LOG_FILE="$OUTPUT_BASE/pipeline-modify-feature/session.json"
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

# --- Skill invocations ---
assert_skill_invoked "$LOG_FILE" "beat:design" "beat:design invoked"
assert_skill_invoked "$LOG_FILE" "beat:apply" "beat:apply invoked"
assert_skill_invoked "$LOG_FILE" "beat:verify" "beat:verify invoked"
assert_skill_invoked "$LOG_FILE" "beat:archive" "beat:archive invoked"

# --- .orig backup mechanism (plan) ---
# After plan: original should be renamed to .orig
# After archive: .orig should be cleaned up
# We check the final state — .orig should NOT exist (archive cleaned it)
ORIG_FILES=$(find "$PROJECT_DIR/beat/features" -name "*.feature.orig" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ORIG_FILES" -eq 0 ]]; then
    echo -e "${GREEN}[PASS]${NC} No .orig files remain after archive (cleanup successful)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Found $ORIG_FILES .orig file(s) — archive should have cleaned them up"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Feature file synced back ---
# After archive: beat/features/auth/ should have the updated login.feature
if [[ -f "$PROJECT_DIR/beat/features/auth/login.feature" ]]; then
    # Check it was actually modified (should mention rate limiting or lock or failed attempts)
    if grep -qi "lock\|rate.limit\|failed.attempt\|block" "$PROJECT_DIR/beat/features/auth/login.feature" 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} Modified feature synced back with new behavior"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Feature file exists but doesn't contain the new behavior"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} login.feature not found in beat/features/auth/"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Existing test file was updated (not replaced) ---
if [[ -f "$PROJECT_DIR/test/login.test.ts" ]]; then
    # Should still contain original scenarios AND new ones
    ORIGINAL_SCENARIO=$(grep -c "@scenario:.*valid credentials\|should succeed with correct password" "$PROJECT_DIR/test/login.test.ts" 2>/dev/null || echo 0)
    NEW_SCENARIO=$(grep -ci "lock\|rate.limit\|failed.attempt\|block\|attempt" "$PROJECT_DIR/test/login.test.ts" 2>/dev/null || echo 0)
    if [[ "$ORIGINAL_SCENARIO" -gt 0 && "$NEW_SCENARIO" -gt 0 ]]; then
        echo -e "${GREEN}[PASS]${NC} Existing test file updated (contains both original and new scenarios)"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [[ "$ORIGINAL_SCENARIO" -gt 0 ]]; then
        echo -e "${RED}[FAIL]${NC} Test file has original scenarios but missing new behavior tests"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Test file may have been replaced instead of updated"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} test/login.test.ts not found"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- status.yaml had modified field ---
# Check in archived change (or active if archive didn't complete)
STATUS_FILE=""
if ls "$PROJECT_DIR/beat/changes/archive/"*rate-limiting*/status.yaml 2>/dev/null | head -1 | grep -q .; then
    STATUS_FILE=$(ls "$PROJECT_DIR/beat/changes/archive/"*rate-limiting*/status.yaml 2>/dev/null | head -1)
elif [[ -f "$PROJECT_DIR/beat/changes/add-rate-limiting/status.yaml" ]]; then
    STATUS_FILE="$PROJECT_DIR/beat/changes/add-rate-limiting/status.yaml"
fi

if [[ -n "$STATUS_FILE" ]]; then
    if grep -q "modified:" "$STATUS_FILE" 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} status.yaml contains modified field"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} status.yaml missing modified field"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} status.yaml not found in active or archive"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Tests pass ---
echo "Running tests..."
cd "$PROJECT_DIR"
if npx vitest run --reporter=verbose 2>&1; then
    echo -e "${GREEN}[PASS]${NC} Tests pass after modification"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Tests failed after modification"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Verify report mentions semantic verification ---
if grep -qi "semantic\|modified.*scenario\|scenario.*modif\|orig\|diff" "$LOG_FILE" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Verify performed semantic check on modified scenarios"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} No evidence of semantic verification in verify output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- Archive completed ---
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

# Token analysis
echo ""
echo "=== Token Usage ==="
python3 "$TESTS_DIR/analyze-token-usage.py" "$LOG_FILE" 2>/dev/null || echo "(token analysis unavailable)"

print_summary
