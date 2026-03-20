#!/bin/bash
# Create a test project with a Beat change ready for continue (proposal pending)
# Usage: ./create-continue-project.sh <project-dir>
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
created: 2026-03-20
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
  behavior: vitest
EOF

echo '{ "name": "test-project", "type": "module", "devDependencies": { "vitest": "latest" } }' > package.json

git add -A && git commit -q -m "init: test project for continue pressure test"
echo "$PROJECT_DIR"
