#!/bin/bash
# Create a test project with existing code ready for distill (no beat/changes yet)
# Usage: ./create-distill-project.sh <project-dir>
set -euo pipefail

PROJECT_DIR="$1"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config commit.gpgsign false

mkdir -p src beat/features

cat > src/auth.js << 'AUTHEOF'
export function login(username, password) {
  if (!username || !password) {
    throw new Error('Username and password are required');
  }
  if (password.length < 8) {
    throw new Error('Password must be at least 8 characters');
  }
  return { token: `token-${username}`, expiresIn: 3600 };
}

export function validateToken(token) {
  if (!token || !token.startsWith('token-')) {
    return { valid: false, reason: 'Invalid token format' };
  }
  return { valid: true, username: token.replace('token-', '') };
}
AUTHEOF

cat > beat/config.yaml << 'EOF'
language: en
testing:
  behavior: vitest
EOF

echo '{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for distill pressure test"
echo "$PROJECT_DIR"
