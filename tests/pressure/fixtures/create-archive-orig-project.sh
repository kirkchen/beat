#!/bin/bash
# Create a test project with .orig backups ready for archive
# Usage: ./create-archive-orig-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
mkdir -p beat/changes/add-two-factor/features
mkdir -p beat/features/auth
mkdir -p e2e/tests

# .orig backup still present (archive should clean this up)
cat > beat/features/auth/login.feature.orig << 'EOF'
Feature: User Login
  As a user
  I want to log in

  @e2e @happy-path
  # @covered-by: e2e/tests/login.spec.ts
  Scenario: User logs in with valid credentials
    Given the user is on the login page
    When the user enters valid credentials
    Then the user sees the dashboard
EOF

# Modified version in changes/
cat > beat/changes/add-two-factor/features/login.feature << 'EOF'
Feature: User Login
  As a user
  I want to log in

  @e2e @happy-path
  # @covered-by: e2e/tests/login.spec.ts
  Scenario: User logs in with valid credentials
    Given the user is on the login page
    When the user enters valid credentials
    And completes two-factor authentication
    Then the user sees the dashboard
EOF

cat > beat/changes/add-two-factor/status.yaml << 'EOF'
name: add-two-factor
created: 2026-04-07
phase: verify
pipeline:
  proposal: { status: done }
  gherkin: { status: done, modified: ["beat/features/auth/login.feature"] }
  design: { status: skipped }
  tasks: { status: skipped }
EOF

cat > beat/changes/add-two-factor/proposal.md << 'EOF'
# Add Two-Factor Authentication
## Why
Security enhancement.
## What Changes
Add 2FA to login.
## Impact
Minimal.
EOF

cat > e2e/tests/login.spec.ts << 'EOF'
// @feature: login.feature
test('User logs in with valid credentials', async () => {
  await loginPage.completeTwoFactor('123456');
  await expect(dashboard).toBeVisible();
});
EOF

cat > beat/config.yaml << 'EOF'
language: en
testing:
  behavior: vitest
  e2e: playwright
EOF

echo '{ "name": "test-project", "type": "module" }' > package.json

git add -A && git commit -q -m "init: test project for archive-orig pressure test"
echo "$PROJECT_DIR"
