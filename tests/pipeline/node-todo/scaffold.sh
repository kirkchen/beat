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
