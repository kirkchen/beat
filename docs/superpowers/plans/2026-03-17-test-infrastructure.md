# Test Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a four-layer automated test infrastructure for Beat skills using `claude -p` headless mode, modeled after Superpowers' test architecture.

**Architecture:** Shell scripts (bash) for test runners and assertions, Python for token analysis, plain text files for prompts/scenarios. All tests use `claude -p --output-format stream-json` to capture agent behavior, then grep/parse the output for expected patterns. No npm dependencies except in the pipeline integration test.

**Tech Stack:** Bash, Python 3, `claude` CLI, `grep`, `jq` (optional)

**Spec:** `docs/superpowers/specs/2026-03-17-test-infrastructure-design.md`

---

## File Structure

**New files (all under `tests/`):**

```
tests/
├── test-helpers.sh                          # Task 1
├── run-all.sh                               # Task 8
├── analyze-token-usage.py                   # Task 2
├── skill-triggering/                        # Task 3
│   ├── run-all.sh
│   ├── run-test.sh
│   └── prompts/ (10 .txt files)
├── skill-content/                           # Task 4
│   ├── run-all.sh
│   ├── test-ff-enforcement.sh
│   ├── test-apply-enforcement.sh
│   └── test-continue-enforcement.sh
├── pressure/                                # Tasks 5-6
│   ├── run-all.sh
│   ├── run-test.sh
│   ├── fixtures/
│   │   ├── create-ff-project.sh
│   │   └── create-apply-project.sh
│   └── scenarios/ (7 .txt files)
└── pipeline/                                # Task 7
    ├── run-test.sh
    ├── analyze-results.sh
    └── node-todo/
        └── scaffold.sh
```

---

### Task 1: Create test-helpers.sh

**Files:**
- Create: `tests/test-helpers.sh`

Core assertion framework ported from Superpowers. All other test scripts source this file.

- [ ] **Step 1: Create `tests/test-helpers.sh`**

```bash
#!/bin/bash
# Beat test helpers — ported from Superpowers test-helpers.sh
# Source this file in test scripts: source "$(dirname "$0")/../test-helpers.sh"

set -euo pipefail

# --- Configuration ---
BEAT_DIR="${BEAT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_BASE="/tmp/beat-tests/${TIMESTAMP}"
mkdir -p "$OUTPUT_BASE"

PASS_COUNT=0
FAIL_COUNT=0

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# --- Core Functions ---

run_claude() {
    local prompt="$1"
    local timeout="${2:-120}"
    local max_turns="${3:-3}"
    local extra_args="${4:-}"
    local output_file
    output_file=$(mktemp)

    timeout "$timeout" claude -p "$prompt" \
        --plugin-dir "$BEAT_DIR" \
        --max-turns "$max_turns" \
        --output-format stream-json \
        $extra_args \
        > "$output_file" 2>&1 || true

    cat "$output_file"
    rm -f "$output_file"
}

assert_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="$3"

    if echo "$output" | grep -qi "$pattern"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected to find: $pattern"
        echo "  In output (first 10 lines):"
        echo "$output" | head -10 | sed 's/^/    /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_not_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="$3"

    if echo "$output" | grep -qi "$pattern"; then
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected NOT to find: $pattern"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    else
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    fi
}

assert_skill_invoked() {
    local log_file="$1"
    local skill_name="$2"
    local test_name="${3:-Skill $skill_name invoked}"

    if grep -q '"name":"Skill"' "$log_file" && grep -qE "\"skill\":\"([^\"]*:)?${skill_name}\"" "$log_file"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected Skill tool invocation with: $skill_name"
        echo "  Skills found in log:"
        grep -o '"skill":"[^"]*"' "$log_file" 2>/dev/null | head -5 | sed 's/^/    /' || echo "    (none)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="${2:-File exists: $file_path}"

    if [[ -f "$file_path" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  File not found: $file_path"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# --- Project Helpers ---

create_test_project() {
    local project_dir
    project_dir=$(mktemp -d)
    cd "$project_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    mkdir -p beat
    echo "{ \"name\": \"test-project\", \"type\": \"module\" }" > package.json
    git add -A && git commit -q -m "init"
    echo "$project_dir"
}

cleanup_test_project() {
    local project_dir="$1"
    if [[ -n "$project_dir" && -d "$project_dir" ]]; then
        rm -rf "$project_dir"
    fi
}

create_beat_change() {
    local project_dir="$1"
    local change_name="$2"
    local phase="${3:-new}"

    mkdir -p "$project_dir/beat/changes/$change_name/features"
    touch "$project_dir/beat/changes/$change_name/features/.gitkeep"
    cat > "$project_dir/beat/changes/$change_name/status.yaml" << EOF
name: $change_name
created: 2026-03-17
phase: $phase
pipeline:
  proposal: { status: pending }
  gherkin: { status: pending }
  design: { status: pending }
  tasks: { status: pending }
EOF
}

# --- Summary ---

print_summary() {
    echo ""
    echo "========================================="
    local total=$((PASS_COUNT + FAIL_COUNT))
    echo " Results: $PASS_COUNT/$total passed"
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e " ${RED}$FAIL_COUNT FAILED${NC}"
        echo "========================================="
        return 1
    else
        echo -e " ${GREEN}ALL PASSED${NC}"
        echo "========================================="
        return 0
    fi
}
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/test-helpers.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/test-helpers.sh
git commit -m "feat: add test-helpers.sh assertion framework for Beat skill testing"
```

---

### Task 2: Create analyze-token-usage.py

**Files:**
- Create: `tests/analyze-token-usage.py`

Token analysis script ported from Superpowers. Parses stream-json output.

- [ ] **Step 1: Create `tests/analyze-token-usage.py`**

```python
#!/usr/bin/env python3
"""Analyze token usage from claude -p stream-json output."""

import json
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: analyze-token-usage.py <stream-json-file>")
        sys.exit(1)

    filepath = sys.argv[1]
    agents = {}
    main_usage = {"input": 0, "output": 0, "cache_create": 0, "cache_read": 0, "msgs": 0}

    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Main session usage
            if data.get("type") == "assistant" and "message" in data:
                msg = data["message"]
                if "usage" in msg:
                    u = msg["usage"]
                    main_usage["input"] += u.get("input_tokens", 0)
                    main_usage["output"] += u.get("output_tokens", 0)
                    main_usage["cache_create"] += u.get("cache_creation_input_tokens", 0)
                    main_usage["cache_read"] += u.get("cache_read_input_tokens", 0)
                    main_usage["msgs"] += 1

            # Subagent usage
            if data.get("type") == "user":
                for item in data.get("content", []):
                    if isinstance(item, dict) and "toolUseResult" in item:
                        result = item["toolUseResult"]
                        if isinstance(result, dict) and "agentId" in result:
                            aid = result["agentId"][:12]
                            usage = result.get("usage", {})
                            desc = result.get("prompt", "")[:50] if "prompt" in result else "subagent"
                            if aid not in agents:
                                agents[aid] = {"desc": desc, "input": 0, "output": 0, "msgs": 0}
                            agents[aid]["input"] += usage.get("input_tokens", 0)
                            agents[aid]["output"] += usage.get("output_tokens", 0)
                            agents[aid]["msgs"] += usage.get("tool_uses", 0)

    # Print report
    print(f"\n{'Agent':<15} {'Description':<40} {'Msgs':>5} {'Input':>10} {'Output':>10} {'Cost':>8}")
    print("-" * 90)

    total_input = main_usage["input"]
    total_output = main_usage["output"]

    cost = (main_usage["input"] * 3 + main_usage["output"] * 15) / 1_000_000
    print(f"{'main':<15} {'Main session':<40} {main_usage['msgs']:>5} {main_usage['input']:>10,} {main_usage['output']:>10,} ${cost:>6.2f}")

    for aid, info in sorted(agents.items()):
        c = (info["input"] * 3 + info["output"] * 15) / 1_000_000
        total_input += info["input"]
        total_output += info["output"]
        cost += c
        print(f"{aid:<15} {info['desc']:<40} {info['msgs']:>5} {info['input']:>10,} {info['output']:>10,} ${c:>6.2f}")

    print("-" * 90)
    total = total_input + total_output
    total_cost = (total_input * 3 + total_output * 15) / 1_000_000
    print(f"TOTALS: {total:,} tokens (input: {total_input:,}, output: {total_output:,}), estimated cost: ${total_cost:.2f}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/analyze-token-usage.py
```

- [ ] **Step 3: Commit**

```bash
git add tests/analyze-token-usage.py
git commit -m "feat: add token usage analysis script for Beat test sessions"
```

---

### Task 3: Create Skill Triggering Tests

**Files:**
- Create: `tests/skill-triggering/run-all.sh`
- Create: `tests/skill-triggering/run-test.sh`
- Create: `tests/skill-triggering/prompts/*.txt` (10 files)

- [ ] **Step 1: Create `tests/skill-triggering/run-test.sh`**

```bash
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
```

- [ ] **Step 2: Create 10 prompt files**

Create `tests/skill-triggering/prompts/` directory and these files:

**start-new-feature.txt**: `I want to start working on user authentication`
**think-about-problem.txt**: `Let me think through how caching should work in this app`
**next-step.txt**: `What's the next artifact I need to create for my change?`
**create-all-specs.txt**: `I have a clear idea for a config migration, let's create all the specs`
**implement-change.txt**: `The features are ready, let's start implementing`
**check-implementation.txt**: `I've finished coding, can you validate it matches the specs?`
**update-docs.txt**: `Sync the features to the living documentation`
**finalize-change.txt**: `This change is done, let's archive it`
**setup-beat.txt**: `Initialize beat in this project`
**extract-specs.txt**: `I want to create BDD specs from the existing auth module code`

- [ ] **Step 3: Create `tests/skill-triggering/run-all.sh`**

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Skill Triggering Tests ==="
echo ""

TESTS=(
    "new:start-new-feature.txt"
    "explore:think-about-problem.txt"
    "continue:next-step.txt"
    "ff:create-all-specs.txt"
    "apply:implement-change.txt"
    "verify:check-implementation.txt"
    "sync:update-docs.txt"
    "archive:finalize-change.txt"
    "setup:setup-beat.txt"
    "distill:extract-specs.txt"
)

PASS=0
FAIL=0

for test in "${TESTS[@]}"; do
    SKILL="${test%%:*}"
    PROMPT="${test##*:}"
    echo "--- Testing: beat:$SKILL ---"
    if "$SCRIPT_DIR/run-test.sh" "$SKILL" "$SCRIPT_DIR/prompts/$PROMPT"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Triggering Summary: $PASS/$((PASS + FAIL)) passed ==="
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: Make scripts executable**

```bash
chmod +x tests/skill-triggering/run-all.sh tests/skill-triggering/run-test.sh
```

- [ ] **Step 5: Commit**

```bash
git add tests/skill-triggering/
git commit -m "feat: add skill triggering tests — 10 naive prompts for CSO validation"
```

---

### Task 4: Create Skill Content Tests

**Files:**
- Create: `tests/skill-content/run-all.sh`
- Create: `tests/skill-content/test-ff-enforcement.sh`
- Create: `tests/skill-content/test-apply-enforcement.sh`
- Create: `tests/skill-content/test-continue-enforcement.sh`

- [ ] **Step 1: Create `tests/skill-content/test-ff-enforcement.sh`**

```bash
#!/bin/bash
# Smoke test: does ff skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== ff Enforcement Smoke Tests ==="

output=$(run_claude "You have the beat:ff skill loaded. When creating tasks, what must you do first?" 30)
assert_contains "$output" "writing-plans" "ff knows to invoke writing-plans for tasks"

output=$(run_claude "As beat:ff, if a user says 'just quickly do it', do you skip writing-plans?" 30)
assert_contains "$output" "no\|must\|always\|MUST\|never skip" "ff resists time pressure to skip writing-plans"

output=$(run_claude "As beat:ff, when creating a proposal, what must happen first?" 30)
assert_contains "$output" "brainstorming" "ff knows to invoke brainstorming for proposal"

output=$(run_claude "As beat:ff, what are the red flags you watch for?" 30)
assert_contains "$output" "checkbox\|writing-plans\|brainstorming" "ff knows its red flags"

output=$(run_claude "As beat:ff, is it OK to write tasks inline if the change is simple?" 30)
assert_contains "$output" "no\|must\|writing-plans\|never" "ff resists simplicity bias for tasks"

print_summary
```

- [ ] **Step 2: Create `tests/skill-content/test-apply-enforcement.sh`**

```bash
#!/bin/bash
# Smoke test: does apply skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== apply Enforcement Smoke Tests ==="

output=$(run_claude "As beat:apply, before any code changes what must you do?" 30)
assert_contains "$output" "worktree" "apply knows to invoke using-git-worktrees"

output=$(run_claude "As beat:apply in TDD mode, what must happen before implementation?" 30)
assert_contains "$output" "test\|TDD\|test-driven" "apply knows TDD comes first"

output=$(run_claude "As beat:apply, after implementing a @behavior scenario what annotation is needed?" 30)
assert_contains "$output" "covered-by" "apply knows @covered-by annotation"

output=$(run_claude "As beat:apply, can you skip e2e test creation if setup is complex?" 30)
assert_contains "$output" "no\|ask\|blocker\|cannot\|must not" "apply resists e2e skip"

output=$(run_claude "As beat:apply, can you batch @covered-by annotations at the end?" 30)
assert_contains "$output" "no\|per-scenario\|immediately\|each\|must not" "apply resists annotation batching"

print_summary
```

- [ ] **Step 3: Create `tests/skill-content/test-continue-enforcement.sh`**

```bash
#!/bin/bash
# Smoke test: does continue skill know its enforcement rules?
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

echo "=== continue Enforcement Smoke Tests ==="

output=$(run_claude "As beat:continue, before creating tasks what must happen?" 30)
assert_contains "$output" "writing-plans" "continue knows to invoke writing-plans for tasks"

output=$(run_claude "As beat:continue, before creating a proposal what must happen?" 30)
assert_contains "$output" "brainstorming" "continue knows to invoke brainstorming for proposal"

output=$(run_claude "As beat:continue, is it OK to skip brainstorming if user already described what they want?" 30)
assert_contains "$output" "no\|must\|always\|never" "continue resists description-is-enough bias"

print_summary
```

- [ ] **Step 4: Create `tests/skill-content/run-all.sh`**

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Skill Content Tests ==="
echo ""

PASS=0
FAIL=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
    echo "--- Running: $(basename "$test_file") ---"
    if bash "$test_file"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Content Summary: $PASS/$((PASS + FAIL)) test files passed ==="
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 5: Make scripts executable**

```bash
chmod +x tests/skill-content/run-all.sh tests/skill-content/test-*.sh
```

- [ ] **Step 6: Commit**

```bash
git add tests/skill-content/
git commit -m "feat: add skill content smoke tests — 13 enforcement assertions"
```

---

### Task 5: Create Pressure Test Fixtures

**Files:**
- Create: `tests/pressure/fixtures/create-ff-project.sh`
- Create: `tests/pressure/fixtures/create-apply-project.sh`

- [ ] **Step 1: Create `tests/pressure/fixtures/create-ff-project.sh`**

```bash
#!/bin/bash
# Create a test project with a Beat change ready for ff
# Usage: ./create-ff-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"

mkdir -p beat/changes/test-change/features
touch beat/changes/test-change/features/.gitkeep

cat > beat/changes/test-change/status.yaml << 'EOF'
name: test-change
created: 2026-03-17
phase: new
pipeline:
  proposal: { status: pending }
  gherkin: { status: pending }
  design: { status: pending }
  tasks: { status: pending }
EOF

cat > beat/config.yaml << 'EOF'
language: en
testing:
  framework: vitest
EOF

echo '{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for ff pressure test"
echo "$PROJECT_DIR"
```

- [ ] **Step 2: Create `tests/pressure/fixtures/create-apply-project.sh`**

```bash
#!/bin/bash
# Create a test project with a Beat change ready for apply
# Usage: ./create-apply-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"

mkdir -p beat/changes/test-change/features
mkdir -p src test

cat > beat/changes/test-change/status.yaml << 'EOF'
name: test-change
created: 2026-03-17
phase: implement
pipeline:
  proposal: { status: done }
  gherkin: { status: done }
  design: { status: skipped }
  tasks: { status: skipped }
EOF

cat > beat/changes/test-change/proposal.md << 'EOF'
# Test Change -- Proposal
## Why
Add a greeting utility for testing.
## What Changes
Create a greet function that returns personalized messages.
## Impact
Minimal — new isolated module.
EOF

cat > beat/changes/test-change/features/greeting.feature << 'EOF'
Feature: Greeting
  As a user
  I want personalized greetings

  @behavior @happy-path
  Scenario: Greet by name
    Given a user named "Alice"
    When I request a greeting
    Then the response should contain "Alice"

  @behavior @edge-case
  Scenario: Greet with empty name
    Given a user with no name
    When I request a greeting
    Then the response should use a default name
EOF

cat > beat/config.yaml << 'EOF'
language: en
testing:
  framework: vitest
EOF

echo '{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for apply pressure test"
echo "$PROJECT_DIR"
```

- [ ] **Step 3: Make executable**

```bash
chmod +x tests/pressure/fixtures/create-ff-project.sh tests/pressure/fixtures/create-apply-project.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/pressure/fixtures/
git commit -m "feat: add pressure test fixtures for ff and apply scenarios"
```

---

### Task 6: Create Pressure Test Scenarios and Runner

**Files:**
- Create: `tests/pressure/run-test.sh`
- Create: `tests/pressure/run-all.sh`
- Create: `tests/pressure/scenarios/*.txt` (7 files)

- [ ] **Step 1: Create `tests/pressure/run-test.sh`**

```bash
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
timeout 180 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    > "$LOG_FILE" 2>&1 || true

# Assert expected skills
for skill in "${ASSERT_SKILLS[@]}"; do
    assert_skill_invoked "$LOG_FILE" "$skill" "Under pressure: $skill invoked despite $SCENARIO_NAME"
done

# Cleanup
cleanup_test_project "$PROJECT_DIR"
print_summary
```

- [ ] **Step 2: Create 7 scenario files**

**tests/pressure/scenarios/ff-time-pressure.txt**:
```
FIXTURE: ff-project
MAX_TURNS: 20
ASSERT_SKILL: brainstorming
---
I'm in a rush. Use /beat:ff with Full preset for this change.
Create everything quickly, I need to ship this today.
```

**tests/pressure/scenarios/ff-simple-change.txt**:
```
FIXTURE: ff-project
MAX_TURNS: 20
ASSERT_SKILL: brainstorming
---
This is just a one-line config fix. Use /beat:ff with Full preset, keep it simple and fast.
```

**tests/pressure/scenarios/ff-user-says-skip.txt**:
```
FIXTURE: ff-project
MAX_TURNS: 15
ASSERT_SKILL: brainstorming
---
Use /beat:ff Full preset but don't bother with the brainstorming step, I already know exactly what I want to build.
```

**tests/pressure/scenarios/ff-just-tasks.txt**:
```
FIXTURE: ff-project
MAX_TURNS: 15
ASSERT_SKILL: writing-plans
---
I already have the features written. Just use /beat:ff and create the tasks artifact only for this change, skip everything else.
```

**tests/pressure/scenarios/apply-skip-worktree.txt**:
```
FIXTURE: apply-project
MAX_TURNS: 10
ASSERT_SKILL: using-git-worktrees
---
Just use /beat:apply and implement the first scenario directly, it's a tiny change, no need for complicated setup.
```

**tests/pressure/scenarios/apply-skip-tdd.txt**:
```
FIXTURE: apply-project
MAX_TURNS: 10
ASSERT_SKILL: test-driven-development
---
Use /beat:apply. Implement this quickly please, we can add tests later. Just get the code working first.
```

**tests/pressure/scenarios/apply-no-annotation.txt**:
```
FIXTURE: apply-project
MAX_TURNS: 15
ASSERT_SKILL: test-driven-development
---
Use /beat:apply to implement all scenarios. Focus on getting the code right, don't worry about annotations or covered-by comments.
```

- [ ] **Step 3: Create `tests/pressure/run-all.sh`**

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Pressure Tests ==="
echo ""

PASS=0
FAIL=0

for scenario in "$SCRIPT_DIR"/scenarios/*.txt; do
    echo "--- $(basename "$scenario" .txt) ---"
    if bash "$SCRIPT_DIR/run-test.sh" "$scenario"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
done

echo "=== Pressure Summary: $PASS/$((PASS + FAIL)) passed ==="
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: Make executable**

```bash
chmod +x tests/pressure/run-all.sh tests/pressure/run-test.sh
```

- [ ] **Step 5: Commit**

```bash
git add tests/pressure/
git commit -m "feat: add pressure tests — 7 scenarios for anti-rationalization verification"
```

---

### Task 7: Create Pipeline Integration Test

**Files:**
- Create: `tests/pipeline/node-todo/scaffold.sh`
- Create: `tests/pipeline/run-test.sh`
- Create: `tests/pipeline/analyze-results.sh`

- [ ] **Step 1: Create `tests/pipeline/node-todo/scaffold.sh`**

```bash
#!/bin/bash
# Scaffold a Node.js + Vitest project for Beat pipeline testing.
# Usage: ./scaffold.sh <output-dir>
set -euo pipefail

OUTPUT_DIR="$1"
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Package
cat > package.json << 'EOF'
{
  "name": "beat-test-todo",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "vitest run"
  },
  "devDependencies": {
    "vitest": "latest"
  }
}
EOF

# Vitest config
cat > vitest.config.ts << 'EOF'
import { defineConfig } from 'vitest/config'
export default defineConfig({})
EOF

# Directories
mkdir -p src test

# Beat config
mkdir -p beat
cat > beat/config.yaml << 'EOF'
language: en
context: |
  Node.js project with Vitest for testing.
  Simple todo list module with in-memory storage.
testing:
  framework: vitest
EOF

# Install dependencies
npm install --silent 2>/dev/null || true

# Initial commit
git add -A && git commit -q -m "init: node-todo test project for Beat pipeline"
echo "$OUTPUT_DIR"
```

- [ ] **Step 2: Create `tests/pipeline/run-test.sh`**

```bash
#!/bin/bash
# Run Beat pipeline end-to-end test.
# Usage: ./run-test.sh [--plugin-dir /path/to/beat]
set -euo pipefail
source "$(dirname "$0")/../test-helpers.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Beat Pipeline Integration Test ==="
echo "This test runs new → ff → apply → verify and takes 15-30 minutes."
echo ""

# Scaffold project
PROJECT_DIR="$OUTPUT_BASE/pipeline-node-todo/project"
mkdir -p "$(dirname "$PROJECT_DIR")"
bash "$SCRIPT_DIR/node-todo/scaffold.sh" "$PROJECT_DIR"

PROMPT='Use the Beat BDD workflow to build a simple todo list module.
Requirements: add todo, complete todo, list todos, delete todo.

Execute this sequence:
1. /beat:new todo-list
2. /beat:ff with Standard preset (Proposal + Gherkin)
3. /beat:apply to implement
4. /beat:verify to validate

Complete the full pipeline. Do not stop between steps.'

# Run Claude
LOG_FILE="$OUTPUT_BASE/pipeline-node-todo/session.json"
cd "$PROJECT_DIR"
echo "Running claude -p (max-turns 60, timeout 1800s)..."
echo "Output: $LOG_FILE"
timeout 1800 claude -p "$PROMPT" \
    --plugin-dir "$BEAT_DIR" \
    --max-turns 60 \
    --output-format stream-json \
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

# Token analysis
echo ""
echo "=== Token Usage ==="
python3 "$TESTS_DIR/analyze-token-usage.py" "$LOG_FILE" 2>/dev/null || echo "(token analysis unavailable)"

print_summary
```

- [ ] **Step 3: Create `tests/pipeline/analyze-results.sh`**

```bash
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
```

- [ ] **Step 4: Make executable**

```bash
chmod +x tests/pipeline/run-test.sh tests/pipeline/analyze-results.sh tests/pipeline/node-todo/scaffold.sh
```

- [ ] **Step 5: Commit**

```bash
git add tests/pipeline/
git commit -m "feat: add pipeline integration test — end-to-end Beat workflow verification"
```

---

### Task 8: Create Top-Level run-all.sh

**Files:**
- Create: `tests/run-all.sh`

- [ ] **Step 1: Create `tests/run-all.sh`**

```bash
#!/bin/bash
# Beat test suite runner.
# Usage: ./run-all.sh [--integration]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================="
echo " Beat Skill Test Suite"
echo "========================================="
echo ""

PASS=0
FAIL=0

# Layer 1: Skill Triggering (~5 min)
echo "=== Layer 1: Skill Triggering Tests ==="
if bash "$SCRIPT_DIR/skill-triggering/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 2: Skill Content (~3 min)
echo "=== Layer 2: Skill Content Tests ==="
if bash "$SCRIPT_DIR/skill-content/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 3: Pressure (~15 min)
echo "=== Layer 3: Pressure Tests ==="
if bash "$SCRIPT_DIR/pressure/run-all.sh"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
fi
echo ""

# Layer 4: Pipeline Integration (opt-in, ~30 min)
if [[ "${1:-}" == "--integration" ]]; then
    echo "=== Layer 4: Pipeline Integration Test ==="
    if bash "$SCRIPT_DIR/pipeline/run-test.sh"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    echo ""
fi

echo "========================================="
echo " Final: $PASS/$((PASS + FAIL)) test layers passed"
if [[ $FAIL -gt 0 ]]; then
    echo " SOME TESTS FAILED"
    echo "========================================="
    exit 1
else
    echo " ALL TESTS PASSED"
    echo "========================================="
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/run-all.sh
```

- [ ] **Step 3: Commit**

```bash
git add tests/run-all.sh
git commit -m "feat: add top-level test runner with --integration flag"
```
