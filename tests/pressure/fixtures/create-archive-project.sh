#!/bin/bash
# Create a test project with a Beat change ready for archive (verify phase, gherkin done)
# Usage: ./create-archive-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
mkdir -p beat/changes/test-change/features

cat > beat/changes/test-change/status.yaml << 'EOF'
name: test-change
created: 2026-03-17
phase: verify
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
EOF

cat > beat/config.yaml << 'EOF'
language: en
testing:
  behavior: vitest
EOF

echo '{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for archive pressure test"
echo "$PROJECT_DIR"
