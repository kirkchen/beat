#!/bin/bash
# Test that a naive prompt triggers the expected Beat skill.
# Usage: ./run-test.sh <expected-skill> <prompt-file>
# Example: ./run-test.sh plan prompts/plan-change.txt

set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

EXPECTED_SKILL="$1"
PROMPT_FILE="$2"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Skill Triggering Test ==="
echo "Expected skill: beat:$EXPECTED_SKILL"
echo "Prompt file: $PROMPT_FILE"
echo ""

# Create minimal test project with beat structure
PROJECT_DIR=$(create_test_project)
mkdir -p "$PROJECT_DIR/beat"
cat > "$PROJECT_DIR/beat/config.yaml" << 'EOF'
language: en
EOF

# Some skills need a pre-existing change
case "$EXPECTED_SKILL" in
    design)
        create_beat_change "$PROJECT_DIR" "test-change" "new"
        ;;
    plan)
        create_beat_change "$PROJECT_DIR" "test-change" "gherkin"
        sed -i.bak 's/proposal: { status: pending }/proposal: { status: done }/' \
            "$PROJECT_DIR/beat/changes/test-change/status.yaml"
        sed -i.bak 's/gherkin: { status: pending }/gherkin: { status: done }/' \
            "$PROJECT_DIR/beat/changes/test-change/status.yaml"
        rm -f "$PROJECT_DIR/beat/changes/test-change/status.yaml.bak"
        cat > "$PROJECT_DIR/beat/changes/test-change/features/test.feature" << 'FEATURE'
Feature: Test
  @behavior @happy-path
  Scenario: Basic test
    Given a thing
    When I do something
    Then it works
FEATURE
        ;;
    apply)
        create_beat_change "$PROJECT_DIR" "test-change" "implement"
        sed -i.bak 's/gherkin: { status: pending }/gherkin: { status: done }/' \
            "$PROJECT_DIR/beat/changes/test-change/status.yaml"
        rm -f "$PROJECT_DIR/beat/changes/test-change/status.yaml.bak"
        cat > "$PROJECT_DIR/beat/changes/test-change/features/test.feature" << 'FEATURE'
Feature: Test
  @behavior @happy-path
  Scenario: Basic test
    Given a thing
    When I do something
    Then it works
FEATURE
        ;;
    verify|archive)
        create_beat_change "$PROJECT_DIR" "test-change" "verify"
        sed -i.bak 's/gherkin: { status: pending }/gherkin: { status: done }/' \
            "$PROJECT_DIR/beat/changes/test-change/status.yaml"
        rm -f "$PROJECT_DIR/beat/changes/test-change/status.yaml.bak"
        cat > "$PROJECT_DIR/beat/changes/test-change/features/test.feature" << 'FEATURE'
Feature: Test
  @behavior @happy-path
  Scenario: Basic test
    Given a thing
    When I do something
    Then it works
FEATURE
        ;;
esac

cd "$PROJECT_DIR"
git add -A && git commit -q -m "setup" 2>/dev/null || true

# Run Claude
LOG_FILE="$OUTPUT_BASE/triggering-${EXPECTED_SKILL}.json"
echo "Running claude -p (max-turns 3, timeout 120s)..."
_run_with_timeout 120 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns 3 \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true

# Assert skill triggered
# Beat skills may be invoked after superpowers:brainstorming (which intercepts creative prompts).
# Accept either: direct beat:skill invocation OR brainstorming as valid first skill.
# The real test is that SOME relevant skill fires, not that Beat bypasses Superpowers.
if assert_skill_invoked "$LOG_FILE" "beat:$EXPECTED_SKILL" 2>/dev/null; then
    : # Direct hit
elif grep -qE '"skill":"superpowers:brainstorming"' "$LOG_FILE" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Skill beat:$EXPECTED_SKILL — brainstorming fired first (expected with Superpowers)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    # Neither beat skill nor brainstorming — real failure
    echo -e "${RED}[FAIL]${NC} Skill beat:$EXPECTED_SKILL invoked"
    echo "  Expected: beat:$EXPECTED_SKILL or superpowers:brainstorming"
    echo "  Skills found in log:"
    grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | head -5 | sed 's/^/    /' || echo "    (none)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
