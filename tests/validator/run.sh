#!/bin/bash
# Deterministic checks for scripts/validate-beat.mjs: the good fixture must pass,
# the bad fixture must fail with every expected error.
set -uo pipefail
cd "$(dirname "$0")"
VALIDATOR="../../scripts/validate-beat.mjs"
fail=0

echo "== good fixture"
if node "$VALIDATOR" good; then echo "PASS good"; else echo "FAIL good"; fail=1; fi

echo "== bad fixture"
out=$(node "$VALIDATOR" bad 2>&1); rc=$?
echo "$out"
if [ $rc -eq 0 ]; then echo "FAIL bad (expected non-zero exit)"; fail=1; fi
for expect in \
  'unknown field "artifact_preset"' \
  'unknown field "bundled_issues"' \
  'phase must be one of' \
  'pipeline: unknown field "verify"' \
  'pipeline.proposal: unknown field "notes"' \
  'status passed but critical is 2' \
  'route "nope" has no' \
  'incremental runs need base' \
  'severity must be one of' \
  'dimension must be one of' \
  'duplicate id F1' \
  'status must be open, fixed or wontfix' \
  'blocked_by cycle' \
  'references unknown node "zzz"' \
  'change "ghost" not found' \
  'decision nodes need a question'; do
  if echo "$out" | grep -qF -- "$expect"; then echo "PASS expects: $expect"; else echo "FAIL missing: $expect"; fail=1; fi
done
exit $fail
