#!/bin/bash
# Create a test project with an implemented change ready for verify
# (phase verify, gherkin done, code + behavior test present, no verification record yet)
# Usage: ./create-verify-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
mkdir -p beat/changes/test-change/features src

cat > beat/changes/test-change/status.yaml << 'EOF2'
name: test-change
created: 2026-03-17
phase: verify
pipeline:
  proposal: { status: done }
  gherkin: { status: done }
  design: { status: skipped }
  tasks: { status: skipped }
EOF2

cat > beat/changes/test-change/proposal.md << 'EOF2'
# Test Change -- Proposal
## Why
Add a greeting utility for testing.
## What Changes
Create a greet function that returns personalized messages.
## Impact
Minimal — new isolated module.
EOF2

cat > beat/changes/test-change/features/greeting.feature << 'EOF2'
Feature: Greeting
  As a user
  I want personalized greetings

  @behavior @happy-path
  # @covered-by: src/greet.test.js
  Scenario: Greet by name
    Given a user named "Alice"
    When I request a greeting
    Then the response should contain "Alice"
EOF2

cat > src/greet.js << 'EOF2'
export function greet(name) {
  return `Hello, ${name}!`;
}
EOF2

cat > src/greet.test.js << 'EOF2'
// @feature: greeting.feature
// @scenario: Greet by name
import { describe, it, expect } from 'vitest';
import { greet } from './greet.js';

describe('greet', () => {
  it('contains the name', () => {
    expect(greet('Alice')).toContain('Alice');
  });
});
EOF2

cat > beat/config.yaml << 'EOF2'
language: en
testing:
  behavior: vitest
EOF2

echo '{ "name": "test-project", "type": "module", "scripts": { "test": "vitest run" }, "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for verify pressure test"
echo "$PROJECT_DIR"
