#!/bin/bash
# Run a single pressure test scenario.
# Usage: ./run-test.sh <scenario-file>
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

SCENARIO_FILE="$1"
SCENARIO_NAME=$(basename "$SCENARIO_FILE" .txt)

echo "=== Pressure Test: $SCENARIO_NAME ==="

# Parse scenario file header
FIXTURE=""
MAX_TURNS=15
ASSERT_SKILLS=()
while IFS= read -r line; do
    [[ "$line" == "---" ]] && break
    if [[ "$line" == FIXTURE:* ]]; then
        FIXTURE="${line#FIXTURE: }"
    elif [[ "$line" == MAX_TURNS:* ]]; then
        MAX_TURNS="${line#MAX_TURNS: }"
    elif [[ "$line" == ASSERT_SKILL:* ]]; then
        ASSERT_SKILLS+=("${line#ASSERT_SKILL: }")
    fi
done < "$SCENARIO_FILE"

# Extract prompt (everything after ---)
PROMPT=$(sed -n '/^---$/,$ p' "$SCENARIO_FILE" | tail -n +2)

echo "Fixture: $FIXTURE"
echo "Max turns: $MAX_TURNS"
echo "Assert skills: ${ASSERT_SKILLS[*]}"
echo ""

# Create test project
PROJECT_DIR=$(mktemp -d)
FIXTURE_DIR="$(dirname "$0")/fixtures"

case "$FIXTURE" in
    ff-project)
        bash "$FIXTURE_DIR/create-ff-project.sh" "$PROJECT_DIR"
        ;;
    apply-project)
        bash "$FIXTURE_DIR/create-apply-project.sh" "$PROJECT_DIR"
        ;;
    *)
        echo "Unknown fixture: $FIXTURE"
        exit 1
        ;;
esac

# Run Claude
LOG_FILE="$OUTPUT_BASE/pressure-${SCENARIO_NAME}.json"
cd "$PROJECT_DIR"
echo "Running claude -p (max-turns $MAX_TURNS, timeout 180s)..."
_run_with_timeout 180 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    --dangerously-skip-permissions \
    > "$LOG_FILE" 2>&1 || true

# Assert expected skills
for skill in "${ASSERT_SKILLS[@]}"; do
    assert_skill_invoked "$LOG_FILE" "$skill" "Under pressure: $skill invoked despite $SCENARIO_NAME"
done

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
