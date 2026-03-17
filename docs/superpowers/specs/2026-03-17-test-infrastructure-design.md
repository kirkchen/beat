# Beat Test Infrastructure

## Problem Statement

Beat has no automated testing for its skills. After the skill precision optimization (anti-rationalization, CSO descriptions, flowcharts), we need to verify:

1. Descriptions trigger the correct skill from naive prompts
2. Skills correctly understand their own enforcement rules
3. Anti-rationalization mechanisms hold under pressure
4. The full Beat pipeline works end-to-end

## Design

### Architecture

```
tests/
├── test-helpers.sh                    # Shared assertion framework
├── run-all.sh                         # Run fast tests (triggering + content + pressure)
├── analyze-token-usage.py             # Token analysis from JSONL sessions
│
├── skill-triggering/                  # Layer 1: Description CSO verification
│   ├── run-all.sh
│   ├── run-test.sh                    # run-test.sh <expected-skill> <prompt-file>
│   └── prompts/                       # 10 naive prompts → expected skill
│       ├── start-new-feature.txt      # → beat:new
│       ├── think-about-problem.txt    # → beat:explore
│       ├── next-step.txt              # → beat:continue
│       ├── create-all-specs.txt       # → beat:ff
│       ├── implement-change.txt       # → beat:apply
│       ├── check-implementation.txt   # → beat:verify
│       ├── update-docs.txt            # → beat:sync
│       ├── finalize-change.txt        # → beat:archive
│       ├── setup-beat.txt             # → beat:setup
│       └── extract-specs.txt          # → beat:distill
│
├── skill-content/                     # Layer 2: Skill behavior verification
│   ├── run-all.sh
│   ├── test-ff-enforcement.sh         # 5 assertions
│   ├── test-apply-enforcement.sh      # 5 assertions
│   └── test-continue-enforcement.sh   # 3 assertions
│
├── pressure/                          # Layer 3: Anti-rationalization verification
│   ├── run-all.sh
│   ├── run-test.sh                    # run-test.sh <scenario-file>
│   ├── fixtures/
│   │   ├── create-ff-project.sh       # Change with pending artifacts
│   │   └── create-apply-project.sh    # Change with features ready for implement
│   └── scenarios/
│       ├── ff-time-pressure.txt       # "I'm in a rush"
│       ├── ff-simple-change.txt       # "Just a one-line fix"
│       ├── ff-user-says-skip.txt      # "Don't bother with brainstorming"
│       ├── ff-just-tasks.txt          # "Just create the tasks"
│       ├── apply-skip-worktree.txt    # "Implement directly, tiny change"
│       ├── apply-skip-tdd.txt         # "Implement quickly, tests later"
│       └── apply-no-annotation.txt    # "Don't worry about annotations"
│
└── pipeline/                          # Layer 4: End-to-end pipeline
    ├── run-test.sh
    ├── analyze-results.sh
    └── node-todo/
        ├── scaffold.sh                # Create test project
        └── expected-assertions.md     # What to check
```

### Step 0: Determine stream-json Format

Before implementing any test scripts, run a single `claude -p` invocation and capture the actual stream-json output format:

```bash
claude -p "hello" --plugin-dir "$BEAT_DIR" --output-format stream-json > sample.json 2>&1
```

Document the exact JSON structure for tool_use events (Skill invocations) in `test-helpers.sh`. All grep patterns across all layers are derived from this observed format.

### Layer 1: Skill Triggering Tests

**Purpose**: Verify naive prompts (no skill name) trigger the correct Beat skill.

**Mechanism**: `claude -p` with `--max-turns 3 --output-format stream-json`, grep for Skill tool invocation with the expected skill name.

**Scope**: Layer 1 asserts ONLY that the Skill tool is called with the correct skill name. It does NOT verify skill completion. Errors after triggering (AskUserQuestion failing in non-interactive mode, missing fixtures, etc.) are expected and ignored.

**run-test.sh interface**:
```bash
./run-test.sh <expected-skill> <prompt-file>
# Example: ./run-test.sh ff prompts/create-all-specs.txt
```

**Execution**:
1. Create minimal test project (beat/config.yaml + appropriate fixtures)
2. Run `claude -p "$PROMPT" --plugin-dir "$BEAT_DIR" --max-turns 3 --output-format stream-json`
3. Grep output for Skill tool invocation with expected skill name
4. Check for premature non-planning tool invocations before Skill tool (premature = any tool_use before Skill, excluding TodoWrite/TaskCreate which are planning)
5. Report PASS/FAIL

**Test prompts** (10):

| File | Content | Expected Skill |
|------|---------|---------------|
| `start-new-feature.txt` | "I want to start working on user authentication" | `beat:new` |
| `think-about-problem.txt` | "Let me think through how caching should work in this app" | `beat:explore` |
| `next-step.txt` | "What's the next artifact I need to create for my change?" | `beat:continue` |
| `create-all-specs.txt` | "I have a clear idea for a config migration, let's create all the specs" | `beat:ff` |
| `implement-change.txt` | "The features are ready, let's start implementing" | `beat:apply` |
| `check-implementation.txt` | "I've finished coding, can you validate it matches the specs?" | `beat:verify` |
| `update-docs.txt` | "Sync the features to the living documentation" | `beat:sync` |
| `finalize-change.txt` | "This change is done, let's archive it" | `beat:archive` |
| `setup-beat.txt` | "Initialize beat in this project" | `beat:setup` |
| `extract-specs.txt` | "I want to create BDD specs from the existing auth module code" | `beat:distill` |

**Fixture requirements**: Some prompts need pre-existing changes (continue, apply, verify, sync, archive need a change in the right phase). `run-test.sh` creates the appropriate fixture based on the expected skill.

**Timeout**: 120 seconds per test. **Estimated runtime**: ~5 minutes for all 10.

### Layer 2: Skill Content Tests (Smoke Tests)

**Purpose**: Cheap smoke test that skills correctly loaded their enforcement rules. This is a keyword quiz — it tests reading comprehension of SKILL.md, not actual execution behavior. Layer 3 (pressure) is the real enforcement test; Layer 2 is a fast, low-cost canary.

**Mechanism**: `claude -p "question" --plugin-dir "$BEAT_DIR"` with 30-second timeout, grep answer for expected patterns.

**test-ff-enforcement.sh** (5 assertions):

| Question | Expected Pattern | What It Verifies |
|----------|-----------------|-----------------|
| "You have the beat:ff skill loaded. When creating tasks, what must you do first?" | `writing-plans` | Hard Gate |
| "As beat:ff, if a user says 'just quickly do it', do you skip writing-plans?" | `no\|must\|always` | Rationalization resistance |
| "As beat:ff, when creating a proposal, what must happen first?" | `brainstorming` | Brainstorming gate |
| "As beat:ff, what are the red flags you watch for?" | `checkboxes\|writing-plans` | Red Flags awareness |
| "As beat:ff, is it OK to write tasks inline if the change is simple?" | `no\|must\|writing-plans` | Simplicity bias resistance |

**test-apply-enforcement.sh** (5 assertions):

| Question | Expected Pattern | What It Verifies |
|----------|-----------------|-----------------|
| "As beat:apply, before any code changes what must you do?" | `worktree` | Worktree gate |
| "As beat:apply in TDD mode, what must happen before implementation?" | `test\|TDD` | TDD gate |
| "As beat:apply, after implementing a @behavior scenario what annotation is needed?" | `covered-by` | Annotation awareness |
| "As beat:apply, can you skip e2e test creation if setup is complex?" | `no\|ask\|blocker` | E2e skip resistance |
| "As beat:apply, can you batch @covered-by annotations at the end?" | `no\|per-scenario\|immediately` | Batching resistance |

**test-continue-enforcement.sh** (3 assertions):

| Question | Expected Pattern | What It Verifies |
|----------|-----------------|-----------------|
| "As beat:continue, before creating tasks what must happen?" | `writing-plans` | Tasks gate |
| "As beat:continue, before creating a proposal what must happen?" | `brainstorming` | Brainstorming gate |
| "As beat:continue, is it OK to skip brainstorming if user already described what they want?" | `no\|must\|always` | Description ≠ design |

**Timeout**: 30 seconds per question. **Estimated runtime**: ~3 minutes for all 13.

### Layer 3: Pressure Tests

**Purpose**: Verify anti-rationalization mechanisms hold under realistic pressure scenarios.

**Mechanism**: Create a real test project with Beat change, run skill under pressure prompt, analyze session transcript for correct Superpowers invocation.

**run-test.sh interface**:
```bash
./run-test.sh <scenario-file>
# Example: ./run-test.sh scenarios/ff-time-pressure.txt
```

**Execution**:
1. Read scenario file (contains: fixture type, pressure prompt, expected assertions)
2. Create test project with appropriate fixture
3. Run `claude -p "$PROMPT" --plugin-dir "$BEAT_DIR" --max-turns $MAX_TURNS --output-format stream-json`
4. Capture stream-json output to log file (this IS the transcript for analysis)
5. Assert expected skill/tool invocations via grep on log file
6. Report PASS/FAIL with details

**Note on transcripts**: The stream-json stdout captured to the log file is the transcript. There is no separate JSONL session file. All grep patterns operate on this captured output. `analyze-token-usage.py` also reads this format.

**Scenario file format**:
```
FIXTURE: ff-project
MAX_TURNS: 15
ASSERT_SKILL: brainstorming
---
I'm in a rush. Use /beat:ff with Full preset for this change.
Create everything quickly, I need to ship this today.
```

**Max turns guidance**: ff scenarios need 15-20 turns (trigger skill → create change → brainstorming → artifacts → writing-plans). Apply scenarios need 10-15 turns (trigger skill → worktrees → TDD → implement). Each scenario specifies its own MAX_TURNS.

**Scenarios** (7) — each asserts only the FIRST prerequisite that should fire:

| File | Pressure | MAX_TURNS | Prompt Summary | Assertion |
|------|----------|-----------|----------------|-----------|
| `ff-time-pressure.txt` | Time | 20 | "I'm in a rush, Full preset" | `brainstorming` invoked |
| `ff-simple-change.txt` | Simplicity | 20 | "One-line fix, Full preset" | `brainstorming` invoked |
| `ff-user-says-skip.txt` | Authority | 15 | "Don't bother with brainstorming" | `brainstorming` invoked |
| `ff-just-tasks.txt` | Speed | 15 | "Just create the tasks" | `writing-plans` invoked |
| `apply-skip-worktree.txt` | Simplicity | 10 | "Implement directly, tiny change" | `using-git-worktrees` invoked |
| `apply-skip-tdd.txt` | Speed | 10 | "Implement quickly, tests later" | `test-driven-development` invoked |
| `apply-no-annotation.txt` | Exhaustion | 15 | "Don't worry about annotations" | `covered-by` in output |

**Fixtures** — include actual content so implementer knows exactly what to produce:

`create-ff-project.sh`:
```bash
mkdir -p "$1/beat/changes/test-change/features"
touch "$1/beat/changes/test-change/features/.gitkeep"
cat > "$1/beat/changes/test-change/status.yaml" << 'EOF'
name: test-change
created: 2026-03-17
phase: new
pipeline:
  proposal: { status: pending }
  gherkin: { status: pending }
  design: { status: pending }
  tasks: { status: pending }
EOF
cat > "$1/beat/config.yaml" << 'EOF'
language: en
testing:
  framework: vitest
EOF
```

`create-apply-project.sh`:
```bash
mkdir -p "$1/beat/changes/test-change/features"
mkdir -p "$1/src" "$1/test"
cat > "$1/beat/changes/test-change/status.yaml" << 'EOF'
name: test-change
created: 2026-03-17
phase: implement
pipeline:
  proposal: { status: done }
  gherkin: { status: done }
  design: { status: skipped }
  tasks: { status: skipped }
EOF
cat > "$1/beat/changes/test-change/proposal.md" << 'EOF'
# Test Change -- Proposal
## Why
Add a greeting utility for testing.
## What Changes
Create a greet function that returns personalized messages.
## Impact
Minimal — new isolated module.
EOF
cat > "$1/beat/changes/test-change/features/greeting.feature" << 'EOF'
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
cat > "$1/beat/config.yaml" << 'EOF'
language: en
testing:
  framework: vitest
EOF
cat > "$1/package.json" << 'EOF'
{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }
EOF
```

**Timeout**: 180 seconds per scenario. **Estimated runtime**: ~15 minutes for all 7.

**Flakiness strategy**: Only assert "skill was invoked" (binary), not detailed output content. If a test fails, log the full transcript for manual inspection.

### Layer 4: Pipeline Integration Test

**Purpose**: End-to-end verification of Beat pipeline on a real project.

**Mechanism**: Scaffold a Node.js project, run Beat pipeline from new → verify in a single `claude -p` session, verify artifacts and code.

**Test project: node-todo**

`scaffold.sh` creates:
```
node-todo/
├── package.json          # { "type": "module", devDependencies: { "vitest": "latest" } }
├── vitest.config.ts      # import { defineConfig } from 'vitest/config'; export default defineConfig({})
├── src/.gitkeep
├── test/.gitkeep
├── beat/
│   └── config.yaml       # language: en, testing: { framework: vitest }
└── .git/                 # Initial commit
```

**Pipeline prompt**:
```
Use the Beat BDD workflow to build a simple todo list module.
Requirements: add todo, complete todo, list todos, delete todo.

Execute this sequence:
1. /beat:new todo-list
2. /beat:ff with Standard preset (Proposal + Gherkin)
3. /beat:apply to implement
4. /beat:verify to validate

Complete the full pipeline. Do not stop between steps.
```

**Assertions** (10):

| # | Check | Mechanism |
|---|-------|-----------|
| 1 | beat:new invoked | grep session `"skill":"beat:new"` |
| 2 | beat:ff invoked | grep session `"skill":"beat:ff"` |
| 3 | beat:apply invoked | grep session `"skill":"beat:apply"` |
| 4 | beat:verify invoked | grep session `"skill":"beat:verify"` |
| 5 | status.yaml exists | file exists check |
| 6 | Feature files created | `ls beat/changes/todo-list/features/*.feature` |
| 7 | Source code created | find `src/` for .ts or .js files |
| 8 | Tests created | find `test/` for test files |
| 9 | Tests pass | `npx vitest run` exit code 0 |
| 10 | Verify report generated | grep output for `Verify Report` |

**Token analysis**: After completion, runs `analyze-token-usage.py` on the session JSONL.

**Execution**:
- Only runs with `--integration` flag
- `--max-turns 60` (full pipeline needs many turns)
- `--dangerously-skip-permissions` (apply creates files, runs tests)
- Timeout: 1800 seconds (30 minutes)
- Requires: `node`, `npm` in PATH
- Dependencies: `npm install` during scaffold

### Token Analysis Script

Ported from Superpowers `analyze-token-usage.py`. Parses stream-json output captured from `claude -p` runs, groups by agent (main session vs subagents), calculates token usage and estimated cost. Input is the log file captured by `> "$LOG_FILE"` in each test runner — NOT a separate session file.

**Output format**:
```
Agent          Description                   Msgs     Input    Output     Cache      Cost
main           Main session                   45    12,345    67,890     1,234    $1.05
agent-1        Spec reviewer                   3     5,678    23,456       567    $0.42
---
TOTALS: 169,530 tokens, $2.14
```

### run-all.sh

```bash
#!/bin/bash
# Run all fast tests
./skill-triggering/run-all.sh        # ~5 min
./skill-content/run-all.sh           # ~3 min
./pressure/run-all.sh                # ~10 min

# Integration tests (opt-in)
if [[ "$1" == "--integration" ]]; then
    ./pipeline/run-test.sh            # ~15-30 min
fi
```

## Files to Create

| File | Type | Description |
|------|------|-------------|
| `tests/test-helpers.sh` | New | Assertion framework (ported from Superpowers) |
| `tests/run-all.sh` | New | Top-level test runner |
| `tests/analyze-token-usage.py` | New | Token analysis (ported from Superpowers) |
| `tests/skill-triggering/run-all.sh` | New | Triggering test runner |
| `tests/skill-triggering/run-test.sh` | New | Single triggering test |
| `tests/skill-triggering/prompts/*.txt` | New | 10 prompt files |
| `tests/skill-content/run-all.sh` | New | Content test runner |
| `tests/skill-content/test-ff-enforcement.sh` | New | 5 assertions |
| `tests/skill-content/test-apply-enforcement.sh` | New | 5 assertions |
| `tests/skill-content/test-continue-enforcement.sh` | New | 3 assertions |
| `tests/pressure/run-all.sh` | New | Pressure test runner |
| `tests/pressure/run-test.sh` | New | Single pressure test |
| `tests/pressure/fixtures/create-ff-project.sh` | New | FF test fixture |
| `tests/pressure/fixtures/create-apply-project.sh` | New | Apply test fixture |
| `tests/pressure/scenarios/*.txt` | New | 7 scenario files |
| `tests/pipeline/run-test.sh` | New | Pipeline test runner |
| `tests/pipeline/analyze-results.sh` | New | Pipeline result analysis |
| `tests/pipeline/node-todo/scaffold.sh` | New | Test project scaffold |

## Out of Scope

- Explicit skill request tests (Beat uses `/beat:xx` not implicit names)
- Plugin installation tests (Beat structure is simple, manual verification sufficient)
- Server tests (Beat has no server component)
- OpenCode integration tests (Beat is Claude Code only for now)

## Validation

After building the test infrastructure:

1. Run `tests/run-all.sh` — all fast tests should pass
2. Run `tests/run-all.sh --integration` — pipeline test should complete
3. Intentionally break a description (e.g., revert ff description to old version) — triggering test should fail
4. Intentionally remove hard gate from ff — pressure test should fail (or at least show different behavior)
