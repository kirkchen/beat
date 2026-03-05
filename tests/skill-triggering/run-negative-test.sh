#!/bin/bash
# Test that a prompt does NOT trigger the specified Beat skill.
# Usage: ./run-negative-test.sh <should-not-trigger-skill> <prompt-file>
# Example: ./run-negative-test.sh design prompts/design-negative-explore.txt

set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

SKILL_TO_AVOID="$1"
PROMPT_FILE="$2"
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Negative Skill Triggering Test ==="
echo "Should NOT trigger: beat:$SKILL_TO_AVOID"
echo "Prompt file: $PROMPT_FILE"
echo ""

# Create minimal test project with beat structure
PROJECT_DIR=$(create_test_project)
mkdir -p "$PROJECT_DIR/beat"
cat > "$PROJECT_DIR/beat/config.yaml" << 'EOF'
language: en
EOF

# Set up a change with spec artifacts done (needed for plan-related prompts)
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

cd "$PROJECT_DIR"
git add -A && git commit -q -m "setup" 2>/dev/null || true

# Run Claude
LOG_FILE="$OUTPUT_BASE/negative-triggering-${SKILL_TO_AVOID}-$(basename "$PROMPT_FILE" .txt).json"
echo "Running claude -p (max-turns 3, timeout 120s)..."
_run_with_timeout 120 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns 3 \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true

# Assert skill NOT triggered
assert_skill_NOT_invoked "$LOG_FILE" "beat:$SKILL_TO_AVOID" "beat:$SKILL_TO_AVOID NOT triggered by: $(basename "$PROMPT_FILE")"

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
