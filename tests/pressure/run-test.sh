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
#   ASSERT_FILE_MATCH: <glob> :: <regex>   a file matching the glob has a line matching the regex
#   ASSERT_OUTPUT: <regex>        the final assistant result text matches (case-insensitive)
#   ASSERT_NO_BASH: <regex>       no Bash tool_use whose command matches (e.g. git push)
#   TIMEOUT: <seconds>            wall-clock limit for the run (default 180)
#
# Two kinds of scenario live here. A *pressure* scenario tempts the agent
# (deadline, "it's tiny", sunk cost) without telling it to skip anything, and
# asserts the gate held. An *explicit-override* scenario has the user order a
# skip, and asserts Beat's promise for that case: name what is lost, then honour
# the decision — never skip silently.
FIXTURE=""
MAX_TURNS=15
TIMEOUT=180
ASSERT_MATCHES=()
ASSERT_SKILLS=()
ASSERT_TOOLS=()
ASSERT_FILES=()
ASSERT_NO_FILES=()
ASSERT_CHANGED=()
ASSERT_OUTPUTS=()
ASSERT_NO_BASH=()
while IFS= read -r line; do
    [[ "$line" == "---" ]] && break
    if [[ "$line" == FIXTURE:* ]]; then
        FIXTURE="${line#FIXTURE: }"
    elif [[ "$line" == MAX_TURNS:* ]]; then
        MAX_TURNS="${line#MAX_TURNS: }"
    elif [[ "$line" == TIMEOUT:* ]]; then
        TIMEOUT="${line#TIMEOUT: }"
    elif [[ "$line" == ASSERT_FILE_MATCH:* ]]; then
        ASSERT_MATCHES+=("${line#ASSERT_FILE_MATCH: }")
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
    elif [[ "$line" == ASSERT_OUTPUT:* ]]; then
        ASSERT_OUTPUTS+=("${line#ASSERT_OUTPUT: }")
    elif [[ "$line" == ASSERT_NO_BASH:* ]]; then
        ASSERT_NO_BASH+=("${line#ASSERT_NO_BASH: }")
    fi
done < "$SCENARIO_FILE"

# Extract prompt (everything after ---). The preamble closes the "I'd ask the
# user first" exit that headless mode cannot answer (superpowers: testing setup
# — make the agent choose and act, not defer).
PROMPT="IMPORTANT: This is a real session, not a quiz. Nobody can answer questions here — when a step would ask the user, make the call the skill's guidance implies, say so, and continue. Act on the request below.

$(sed -n '/^---$/,$ p' "$SCENARIO_FILE" | tail -n +2)"

echo "Fixture: $FIXTURE"
echo "Max turns: $MAX_TURNS"
echo "Assert skills: ${ASSERT_SKILLS[*]:-}"
[[ ${#ASSERT_TOOLS[@]} -gt 0 ]] && echo "Assert tools: ${ASSERT_TOOLS[*]}"
[[ ${#ASSERT_FILES[@]} -gt 0 ]] && echo "Assert files: ${ASSERT_FILES[*]}"
[[ ${#ASSERT_NO_FILES[@]} -gt 0 ]] && echo "Assert no files: ${ASSERT_NO_FILES[*]}"
[[ ${#ASSERT_CHANGED[@]} -gt 0 ]] && echo "Assert changed: ${ASSERT_CHANGED[*]}"
[[ ${#ASSERT_MATCHES[@]} -gt 0 ]] && echo "Assert file match: ${ASSERT_MATCHES[*]}"
[[ ${#ASSERT_OUTPUTS[@]} -gt 0 ]] && echo "Assert output: ${ASSERT_OUTPUTS[*]}"
[[ ${#ASSERT_NO_BASH[@]} -gt 0 ]] && echo "Assert no bash: ${ASSERT_NO_BASH[*]}"
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
    archive-ready-project)
        # archive-project plus the implementation, its test and the annotations
        # lint-features requires, so nothing but the rule under test can stop the run.
        bash "$FIXTURE_DIR/create-archive-project.sh" "$PROJECT_DIR"
        (
            cd "$PROJECT_DIR"
            mkdir -p src test
            echo 'export function greet(name) { return `Hello, ${name}!`; }' > src/greet.js
            cat > test/greet.test.js << 'TEST'
// @feature: greeting.feature
// @scenario: Greet by name
import { expect, test } from 'vitest';
import { greet } from '../src/greet.js';

test('Greet by name', () => {
  expect(greet('Alice')).toContain('Alice');
});
TEST
            perl -0pi -e 's/  I want personalized greetings\n/  I want personalized greetings\n  So that the app feels addressed to me\n/; s/(  \@behavior \@happy-path\n)/$1  # \@covered-by: test\/greet.test.js\n/' beat/changes/test-change/features/greeting.feature
            git add -A && git commit -q -m "implement greeting" || true
        )
        ;;
    apply-modify-project)
        bash "$FIXTURE_DIR/create-apply-modify-project.sh" "$PROJECT_DIR"
        ;;
    archive-orig-project)
        bash "$FIXTURE_DIR/create-archive-orig-project.sh" "$PROJECT_DIR"
        ;;
    verify-project)
        bash "$FIXTURE_DIR/create-verify-project.sh" "$PROJECT_DIR"
        ;;
    verify-minimal-project)
        bash "$FIXTURE_DIR/create-verify-project.sh" "$PROJECT_DIR"
        perl -0pi -e 's/^phase: verify$/phase: verify\npreset: minimal/m' "$PROJECT_DIR/beat/changes/test-change/status.yaml"
        (cd "$PROJECT_DIR" && git add -A && git commit -q -m "preset minimal" || true)
        ;;
    apply-conflict-project)
        # Two scenarios with the same Given and opposite Thens: both cannot be
        # built, and nothing in the artifacts says which one is meant.
        bash "$FIXTURE_DIR/create-apply-project.sh" "$PROJECT_DIR"
        cat >> "$PROJECT_DIR/beat/changes/test-change/features/greeting.feature" << 'FEATURE'

  @behavior @error-handling
  Scenario: Reject a missing name
    Given a user with no name
    When I request a greeting
    Then the request is rejected with "name required"
FEATURE
        (cd "$PROJECT_DIR" && git add -A && git commit -q -m "add conflicting scenario" || true)
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
echo "Running claude -p (max-turns $MAX_TURNS, timeout ${TIMEOUT}s)..."
_run_with_timeout "$TIMEOUT" claude -p "$PROMPT" \
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
for spec in "${ASSERT_MATCHES[@]:-}"; do
    [[ -n "$spec" ]] || continue
    assert_file_content_matches "$PROJECT_DIR" "${spec%% :: *}" "${spec#* :: }" "Under pressure: $spec despite $SCENARIO_NAME" || true
done
for regex in "${ASSERT_OUTPUTS[@]:-}"; do
    [[ -n "$regex" ]] || continue
    assert_output_matches "$LOG_FILE" "$regex" "Final answer mentions ($regex) in $SCENARIO_NAME" || true
done
for regex in "${ASSERT_NO_BASH[@]:-}"; do
    [[ -n "$regex" ]] || continue
    assert_no_bash_command "$LOG_FILE" "$regex" "Under pressure: no Bash ($regex) despite $SCENARIO_NAME" || true
done

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
