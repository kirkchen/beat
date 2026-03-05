#!/bin/bash
# Scaffold a Node.js project with EXISTING features and e2e tests,
# ready for a modify-feature pipeline test.
# Usage: ./scaffold.sh <output-dir>
set -euo pipefail

OUTPUT_DIR="$1"
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false
# Package
cat > package.json << 'EOF'
{
  "name": "beat-test-login",
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
mkdir -p src test beat/features/auth beat/changes

# Beat config
cat > beat/config.yaml << 'EOF'
language: en
context: |
  Node.js project with Vitest for testing.
  User authentication module.
testing:
  behavior: vitest
EOF

# Existing feature file (already archived/living doc)
cat > beat/features/auth/login.feature << 'EOF'
Feature: User Login
  As a user
  I want to log in to the application
  So that I can access my account

  @behavior @happy-path
  # @covered-by: test/login.test.ts
  Scenario: User logs in with valid credentials
    Given a registered user with email "user@example.com"
    When the user logs in with correct password
    Then the login succeeds
    And a session token is returned

  @behavior @error-handling
  # @covered-by: test/login.test.ts
  Scenario: User logs in with wrong password
    Given a registered user with email "user@example.com"
    When the user logs in with incorrect password
    Then the login fails
    And an error message is returned
EOF

# Existing source code
cat > src/auth.ts << 'EOF'
interface User {
  email: string;
  passwordHash: string;
}

interface LoginResult {
  success: boolean;
  token?: string;
  error?: string;
}

const users: Map<string, User> = new Map();

export function registerUser(email: string, password: string): void {
  users.set(email, { email, passwordHash: password });
}

export function login(email: string, password: string): LoginResult {
  const user = users.get(email);
  if (!user) {
    return { success: false, error: "User not found" };
  }
  if (user.passwordHash !== password) {
    return { success: false, error: "Invalid password" };
  }
  return { success: true, token: `token-${Date.now()}` };
}
EOF

# Existing test file
cat > test/login.test.ts << 'EOF'
import { describe, it, expect, beforeEach } from 'vitest';
import { registerUser, login } from '../src/auth.js';

// @feature: login.feature

describe('User Login', () => {
  beforeEach(() => {
    registerUser('user@example.com', 'correct-password');
  });

  // @scenario: User logs in with valid credentials
  it('should succeed with correct password', () => {
    const result = login('user@example.com', 'correct-password');
    expect(result.success).toBe(true);
    expect(result.token).toBeDefined();
  });

  // @scenario: User logs in with wrong password
  it('should fail with incorrect password', () => {
    const result = login('user@example.com', 'wrong-password');
    expect(result.success).toBe(false);
    expect(result.error).toBe('Invalid password');
  });
});
EOF

# Install dependencies
npm install --silent 2>/dev/null || true

# Verify tests pass before modification
cd "$OUTPUT_DIR"
npx vitest run --reporter=verbose 2>/dev/null || true

# Initial commit
git add -A && git commit -q -m "init: login project with existing features and tests"
echo "$OUTPUT_DIR"
