#!/bin/bash
# Create a test project with an existing feature + e2e test, ready for apply with modifications
# Usage: ./create-apply-modify-project.sh <project-dir>
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
mkdir -p src e2e/tests

# Existing feature file renamed to .orig (simulating plan already ran)
cat > beat/features/auth/login.feature.orig << 'EOF'
Feature: User Login
  As a user
  I want to log in
  So that I can access the dashboard

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
  So that I can access the dashboard

  @e2e @happy-path
  # @covered-by: e2e/tests/login.spec.ts
  Scenario: User logs in with valid credentials
    Given the user is on the login page
    When the user enters valid credentials
    And completes two-factor authentication
    Then the user sees the dashboard

  @e2e @error-handling
  Scenario: User enters incorrect 2FA code
    Given the user has entered valid credentials
    When the user enters an incorrect 2FA code
    Then the user sees a verification error
EOF

cat > beat/changes/add-two-factor/status.yaml << 'EOF'
name: add-two-factor
created: 2026-04-07
phase: implement
pipeline:
  proposal: { status: done }
  gherkin: { status: done, modified: ["beat/features/auth/login.feature"] }
  design: { status: skipped }
  tasks: { status: skipped }
EOF

cat > beat/changes/add-two-factor/proposal.md << 'EOF'
# Add Two-Factor Authentication -- Proposal
## Why
Enhance login security with 2FA.
## What Changes
Add 2FA step to login flow, handle incorrect codes.
## Impact
Modifies existing login feature, adds new error handling.
EOF

# Existing e2e test
cat > e2e/tests/login.spec.ts << 'EOF'
// @feature: login.feature
// @scenario: User logs in with valid credentials
test('User logs in with valid credentials', async () => {
  await loginPage.goto();
  await loginPage.fillCredentials('user', 'pass');
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

git add -A && git commit -q -m "init: test project for apply-modify pressure test"
echo "$PROJECT_DIR"
