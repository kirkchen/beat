#!/bin/bash
# Beat test helpers — ported from Superpowers test-helpers.sh
# Source this file in test scripts: source "$(dirname "$0")/../test-helpers.sh"

set -euo pipefail

# --- Configuration ---
# Use BASH_SOURCE[0] to resolve paths relative to test-helpers.sh itself,
# not the calling script ($0 points to the caller when sourced).
_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BEAT_DIR="${BEAT_DIR:-$(cd "$_HELPERS_DIR/.." && pwd)}"
TESTS_DIR="$_HELPERS_DIR"
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

# --- Timeout helper (macOS compatible) ---

_run_with_timeout() {
    local secs="$1"
    shift
    if command -v gtimeout &>/dev/null; then
        gtimeout "$secs" "$@"
    elif command -v timeout &>/dev/null; then
        timeout "$secs" "$@"
    else
        # Perl-based fallback for macOS
        perl -e '
            use POSIX ":sys_wait_h";
            my $timeout = shift @ARGV;
            my $pid = fork();
            if ($pid == 0) { exec @ARGV; die "exec failed: $!"; }
            eval {
                local $SIG{ALRM} = sub { kill "TERM", $pid; die "timeout\n"; };
                alarm $timeout;
                waitpid($pid, 0);
                alarm 0;
            };
            if ($@ eq "timeout\n") { waitpid($pid, WNOHANG); exit 124; }
            exit ($? >> 8);
        ' "$secs" "$@"
    fi
}

# --- Core Functions ---

run_claude() {
    local prompt="$1"
    local secs="${2:-120}"
    local max_turns="${3:-3}"
    local extra_args="${4:-}"
    local output_file
    output_file=$(mktemp)

    _run_with_timeout "$secs" claude -p "$prompt" \
        --plugin-dir "$BEAT_DIR" \
        --max-turns "$max_turns" \
        --output-format stream-json \
        --verbose \
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

assert_skill_NOT_invoked() {
    local log_file="$1"
    local skill_name="$2"
    local test_name="${3:-Skill $skill_name NOT invoked}"

    if grep -q '"name":"Skill"' "$log_file" && grep -qE "\"skill\":\"([^\"]*:)?${skill_name}\"" "$log_file"; then
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected Skill tool NOT to be invoked with: $skill_name"
        echo "  But it was found in log"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    else
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
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

assert_tool_used() {
    local log_file="$1"
    local tool_regex="$2"
    local test_name="${3:-Tool $tool_regex used}"

    if grep -qE "\"type\":\"tool_use\",\"id\":\"[^\"]*\",\"name\":\"(${tool_regex})\"" "$log_file"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected a tool_use whose name matches: $tool_regex"
        echo "  Tools used in log:"
        grep -oE '"type":"tool_use","id":"[^"]*","name":"[^"]*"' "$log_file" 2>/dev/null | grep -oE '"name":"[^"]*"' | sort | uniq -c | sed 's/^/    /' || echo "    (none)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# All working trees of a project: the project itself plus any git worktree a
# skill created under it (using-git-worktrees puts them in .claude/worktrees/).
# Result-based assertions look in every tree, because apply/design do their
# work on a worktree branch, not in the fixture's main checkout.
_project_trees() {
    local project_dir="$1"
    echo "$project_dir"
    git -C "$project_dir" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print $2}' | grep -v "^$project_dir\$" || true
}

_find_in_trees() {
    local project_dir="$1"
    local pattern="$2"
    local tree
    while IFS= read -r tree; do
        find "$tree" -type f -path "$tree/$pattern" -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null
    done < <(_project_trees "$project_dir") | head -5
}

# Glob-style path assertions against a project directory. The pattern is matched
# with `find -path`, so `*` also crosses directory boundaries
# (`beat/features/*.orig` matches `beat/features/auth/login.feature.orig`).
assert_path_matches() {
    local project_dir="$1"
    local pattern="$2"
    local test_name="${3:-Path exists: $pattern}"
    local matches
    matches=$(_find_in_trees "$project_dir" "$pattern")

    if [[ -n "$matches" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        echo "$matches" | sed "s|^$project_dir/|    |"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  No file matches: $pattern"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_path_absent() {
    local project_dir="$1"
    local pattern="$2"
    local test_name="${3:-Path absent: $pattern}"
    local matches
    matches=$(_find_in_trees "$project_dir" "$pattern")

    if [[ -z "$matches" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected no file to match: $pattern"
        echo "$matches" | sed "s|^$project_dir/|    |"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# Passes when the file differs from the given commit in any working tree of the
# project, whether the change was committed since or is still uncommitted.
assert_file_changed_since() {
    local project_dir="$1"
    local base_sha="$2"
    local file_path="$3"
    local test_name="${4:-File changed: $file_path}"
    local tree changed=""
    while IFS= read -r tree; do
        if ! git -C "$tree" diff --quiet "$base_sha" -- "$file_path" 2>/dev/null; then
            changed="$tree"; break
        fi
    done < <(_project_trees "$project_dir")

    if [[ -n "$changed" ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        echo "    changed in: ${changed#$project_dir/}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  File unchanged since $base_sha in any working tree: $file_path"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# Matches against the final `result` event of a stream-json log, i.e. the
# assistant's last message to the user.
assert_output_matches() {
    local log_file="$1"
    local regex="$2"
    local test_name="${3:-Output matches: $regex}"

    if grep '"type":"result"' "$log_file" | grep -qiE "$regex"; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Final result did not match: $regex"
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
    git config commit.gpgsign false
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
