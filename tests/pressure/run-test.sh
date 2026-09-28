#!/bin/bash
# Run a single pressure test scenario.
# Usage: ./run-test.sh <scenario-file>
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

SCENARIO_FILE="$1"
SCENARIO_NAME=$(basename "$SCENARIO_FILE" .txt)

echo "=== Pressure Test: $SCENARIO_NAME ==="

# Parse scenario file header.
#
# Every assertion must target the rule the prompt pressures, so a scenario can
# fail on the behaviour it is about:
#   ASSERT_SKILL: <name>          a Superpowers/Beat skill was invoked (Skill tool)
#   ASSERT_TOOL: <regex>          a tool_use whose name matches (e.g. Agent|Task)
#   ASSERT_FILE: <glob>           at least one file matches, relative to the project
#   ASSERT_NO_FILE: <glob>        no file matches
#   ASSERT_FILE_CHANGED: <path>   the file differs from the fixture's initial commit
FIXTURE=""
MAX_TURNS=15
ASSERT_SKILLS=()
ASSERT_TOOLS=()
ASSERT_FILES=()
ASSERT_NO_FILES=()
ASSERT_CHANGED=()
while IFS= read -r line; do
    [[ "$line" == "---" ]] && break
    if [[ "$line" == FIXTURE:* ]]; then
        FIXTURE="${line#FIXTURE: }"
    elif [[ "$line" == MAX_TURNS:* ]]; then
        MAX_TURNS="${line#MAX_TURNS: }"
    elif [[ "$line" == ASSERT_SKILL:* ]]; then
        ASSERT_SKILLS+=("${line#ASSERT_SKILL: }")
    elif [[ "$line" == ASSERT_TOOL:* ]]; then
        ASSERT_TOOLS+=("${line#ASSERT_TOOL: }")
    elif [[ "$line" == ASSERT_FILE:* ]]; then
        ASSERT_FILES+=("${line#ASSERT_FILE: }")
    elif [[ "$line" == ASSERT_NO_FILE:* ]]; then
        ASSERT_NO_FILES+=("${line#ASSERT_NO_FILE: }")
    elif [[ "$line" == ASSERT_FILE_CHANGED:* ]]; then
        ASSERT_CHANGED+=("${line#ASSERT_FILE_CHANGED: }")
    fi
done < "$SCENARIO_FILE"

# Extract prompt (everything after ---)
PROMPT=$(sed -n '/^---$/,$ p' "$SCENARIO_FILE" | tail -n +2)

echo "Fixture: $FIXTURE"
echo "Max turns: $MAX_TURNS"
echo "Assert skills: ${ASSERT_SKILLS[*]:-}"
[[ ${#ASSERT_TOOLS[@]} -gt 0 ]] && echo "Assert tools: ${ASSERT_TOOLS[*]}"
[[ ${#ASSERT_FILES[@]} -gt 0 ]] && echo "Assert files: ${ASSERT_FILES[*]}"
[[ ${#ASSERT_NO_FILES[@]} -gt 0 ]] && echo "Assert no files: ${ASSERT_NO_FILES[*]}"
[[ ${#ASSERT_CHANGED[@]} -gt 0 ]] && echo "Assert changed: ${ASSERT_CHANGED[*]}"
echo ""

# Create test project
PROJECT_DIR=$(mktemp -d)
FIXTURE_DIR="$(dirname "$0")/fixtures"

case "$FIXTURE" in
    design-project)
        bash "$FIXTURE_DIR/create-design-project.sh" "$PROJECT_DIR"
        ;;
    plan-project)
        bash "$FIXTURE_DIR/create-plan-project.sh" "$PROJECT_DIR"
        ;;
    plan-tasks-only-project)
        bash "$FIXTURE_DIR/create-plan-tasks-only-project.sh" "$PROJECT_DIR"
        ;;
    apply-project)
        bash "$FIXTURE_DIR/create-apply-project.sh" "$PROJECT_DIR"
        ;;
    archive-project)
        bash "$FIXTURE_DIR/create-archive-project.sh" "$PROJECT_DIR"
        ;;
    apply-modify-project)
        bash "$FIXTURE_DIR/create-apply-modify-project.sh" "$PROJECT_DIR"
        ;;
    archive-orig-project)
        bash "$FIXTURE_DIR/create-archive-orig-project.sh" "$PROJECT_DIR"
        ;;
    distill-project)
        bash "$FIXTURE_DIR/create-distill-project.sh" "$PROJECT_DIR"
        ;;
    *)
        echo "Unknown fixture: $FIXTURE"
        exit 1
        ;;
esac

# Run Claude
LOG_FILE="$OUTPUT_BASE/pressure-${SCENARIO_NAME}.json"
cd "$PROJECT_DIR"
BASE_SHA=$(git rev-parse HEAD)
echo "Running claude -p (max-turns $MAX_TURNS, timeout 180s)..."
_run_with_timeout 180 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    --dangerously-skip-permissions \
    > "$LOG_FILE" 2>&1 || true

# Assertions. Each one records its own PASS/FAIL; `|| true` keeps `set -e` from
# aborting before the remaining assertions, cleanup and summary run.
for skill in "${ASSERT_SKILLS[@]:-}"; do
    [[ -n "$skill" ]] || continue
    assert_skill_invoked "$LOG_FILE" "$skill" "Under pressure: $skill invoked despite $SCENARIO_NAME" || true
done
for tool in "${ASSERT_TOOLS[@]:-}"; do
    [[ -n "$tool" ]] || continue
    assert_tool_used "$LOG_FILE" "$tool" "Under pressure: tool ($tool) used despite $SCENARIO_NAME" || true
done
for pattern in "${ASSERT_FILES[@]:-}"; do
    [[ -n "$pattern" ]] || continue
    assert_path_matches "$PROJECT_DIR" "$pattern" "Under pressure: $pattern produced despite $SCENARIO_NAME" || true
done
for pattern in "${ASSERT_NO_FILES[@]:-}"; do
    [[ -n "$pattern" ]] || continue
    assert_path_absent "$PROJECT_DIR" "$pattern" "Under pressure: no $pattern left despite $SCENARIO_NAME" || true
done
for path in "${ASSERT_CHANGED[@]:-}"; do
    [[ -n "$path" ]] || continue
    assert_file_changed_since "$PROJECT_DIR" "$BASE_SHA" "$path" "Under pressure: $path updated despite $SCENARIO_NAME" || true
done

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
