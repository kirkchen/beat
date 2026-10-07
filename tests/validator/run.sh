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
  'decision nodes need a question' \
  'pipeline.tasks is done but tasks.md is missing' \
  'orphan backup' \
  'unknown field "unknown_top"' \
  'preset_upgrade.files must be a number' \
  'lint: unknown field "colour"'; do
  if echo "$out" | grep -qF -- "$expect"; then echo "PASS expects: $expect"; else echo "FAIL missing: $expect"; fail=1; fi
done

echo "== --change scope"
if node "$VALIDATOR" good --change slack-thread-dedupe >/dev/null 2>&1; then echo "PASS --change good"; else echo "FAIL --change good"; fail=1; fi
if node "$VALIDATOR" bad --change badverify >/dev/null 2>&1; then echo "FAIL --change bad should fail"; fail=1; else echo "PASS --change bad fails"; fi
echo "== modes"
if node "$VALIDATOR" good --pre-archive slack-thread-dedupe >/dev/null 2>&1; then echo "FAIL pre-archive should reject issues-found"; fail=1; else echo "PASS pre-archive rejects issues-found"; fi
if node "$VALIDATOR" --handoff good/handoff.md >/dev/null 2>&1; then echo "PASS handoff good"; else echo "FAIL handoff good"; fail=1; fi
out=$(node "$VALIDATOR" --handoff bad/handoff.md 2>&1); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'missing "branch"' && echo "$out" | grep -q 'exactly one command' && echo "$out" | grep -q 'commit must be'; then echo "PASS handoff bad"; else echo "FAIL handoff bad"; echo "$out"; fail=1; fi
echo "== lint-features"
if node ../../scripts/lint-features.mjs --project good >/dev/null 2>&1; then echo "PASS lint good"; else echo "FAIL lint good"; fail=1; fi
out=$(node ../../scripts/lint-features.mjs --project bad --require-covered-by 2>&1); rc=$?
if [ $rc -eq 0 ]; then echo "FAIL lint bad (expected non-zero)"; fail=1; fi
for expect in 'error\[1\]' 'error\[2\]' 'warning\[3\]' 'error\[5\]' 'warning\[6\]' 'error\[11\]' 'warning\[12\]'; do
  if echo "$out" | grep -qE -- "$expect"; then echo "PASS lint expects: $expect"; else echo "FAIL lint missing: $expect"; fail=1; fi
done
echo "== stale-paths (temp git repo)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/beat-stale.XXXXXX")
cp -R good/. "$tmp/"
( cd "$tmp" && git init -q && git -c user.email=t@t -c user.name=t add -A >/dev/null && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init )
mkdir -p "$tmp/beat/changes/archive" && mv "$tmp/beat/changes/slack-thread-dedupe" "$tmp/beat/changes/archive/2026-06-12-slack-thread-dedupe"
echo "see beat/changes/slack-thread-dedupe-v2/x only" > "$tmp/note.md"
if node "$VALIDATOR" "$tmp" --stale-paths slack-thread-dedupe >/dev/null 2>&1; then echo "PASS stale-paths ignores sibling change names"; else echo "FAIL stale-paths flagged a sibling change name"; fail=1; fi
echo "see beat/changes/slack-thread-dedupe/design.md" >> "$tmp/note.md"
out=$(node "$VALIDATOR" "$tmp" --stale-paths slack-thread-dedupe 2>&1)
if echo "$out" | grep -q "note.md: still references"; then echo "PASS stale-paths finds untracked reference"; else echo "FAIL stale-paths missed untracked reference"; echo "$out"; fail=1; fi
exit $fail
