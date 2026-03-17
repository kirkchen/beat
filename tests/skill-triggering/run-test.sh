#!/bin/bash
# Test that a naive prompt triggers the expected Beat skill.
# Usage: ./run-test.sh <expected-skill> <prompt-file>
# Example: ./run-test.sh ff prompts/create-all-specs.txt

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
    continue|ff)
        create_beat_change "$PROJECT_DIR" "test-change" "new"
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
    verify|sync|archive)
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
timeout 120 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns 3 \
    --output-format stream-json \
    > "$LOG_FILE" 2>&1 || true

# Assert skill triggered
assert_skill_invoked "$LOG_FILE" "beat:$EXPECTED_SKILL"

# Check for premature tool invocations
FIRST_SKILL_LINE=$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1 || echo "0")
if [[ "$FIRST_SKILL_LINE" -gt 0 ]]; then
    PREMATURE=$(head -n "$FIRST_SKILL_LINE" "$LOG_FILE" | \
        grep '"type":"tool_use"' | \
        grep -v '"name":"Skill"' | \
        grep -v '"name":"TodoWrite"' | \
        grep -v '"name":"TaskCreate"' || true)
    if [[ -n "$PREMATURE" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Tools invoked BEFORE Skill tool:"
        echo "$PREMATURE" | head -3 | sed 's/^/    /'
    fi
fi

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
