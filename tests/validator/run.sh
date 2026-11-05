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
  'speculative findings are capped at SUGGESTION' \
  'severity must be one of' \
  'dimension must be one of' \
  'duplicate id F1' \
  'status must be open, fixed or wontfix' \
  'blocked_by cycle' \
  'references unknown node "zzz"' \
  'change "ghost" not found' \
  'decision nodes need a question' \
  'issue must be a string' \
  'issue must be a non-empty string' \
  'both claim issue #13' \
  'pipeline.tasks is done but tasks.md is missing' \
  'orphan backup' \
  'unknown field "unknown_top"' \
  'preset_upgrade.files must be a number' \
  'lint: unknown field "colour"' \
  'sensitive: unknown field "colour"' \
  'sensitive.situations must be a list of strings'; do
  if echo "$out" | grep -qF -- "$expect"; then echo "PASS expects: $expect"; else echo "FAIL missing: $expect"; fail=1; fi
done

echo "== relative project root and date-prefixed archived change"
out=$(cd good && node "../$VALIDATOR" . 2>&1); rc=$?
if [ $rc -eq 0 ] && ! echo "$out" | grep -q "not found under"; then echo "PASS relative root, archived dated change found"; else echo "FAIL relative root / archived dated change"; echo "$out"; fail=1; fi
echo "== --change scope"
if node "$VALIDATOR" good --change slack-thread-dedupe >/dev/null 2>&1; then echo "PASS --change good"; else echo "FAIL --change good"; fail=1; fi
if node "$VALIDATOR" bad --change badverify >/dev/null 2>&1; then echo "FAIL --change bad should fail"; fail=1; else echo "PASS --change bad fails"; fi
echo "== modes"
if node "$VALIDATOR" good --pre-archive slack-thread-dedupe >/dev/null 2>&1; then echo "FAIL pre-archive should reject issues-found"; fail=1; else echo "PASS pre-archive rejects issues-found"; fi
if node "$VALIDATOR" --handoff good/handoff.md >/dev/null 2>&1; then echo "PASS handoff good"; else echo "FAIL handoff good"; fail=1; fi
if node "$VALIDATOR" --handoff good/handoff-decision.md >/dev/null 2>&1; then echo "PASS handoff decision good"; else echo "FAIL handoff decision good"; node "$VALIDATOR" --handoff good/handoff-decision.md; fail=1; fi
out=$(node "$VALIDATOR" --handoff bad/handoff-stage.md 2>&1); rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q 'nonce is empty' && echo "$out" | grep -q 'must be the last non-empty line' && echo "$out" | grep -q 'blocked-on=decision needs' && echo "$out" | grep -q 'sensitive must be one of' && echo "$out" | grep -q 'critical must be an integer' && echo "$out" | grep -q 'block says blocked-on none'; then echo "PASS handoff stage bad"; else echo "FAIL handoff stage bad"; echo "$out"; fail=1; fi
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

echo "== layout (temp git repo)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/beat-layout.XXXXXX")
cp -R good/. "$tmp/"
gitc() { ( cd "$tmp" && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@" ); }
( cd "$tmp" && git init -q ) && gitc add -A >/dev/null && gitc commit -qm init
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q "docs/agents/issue-tracker.md: missing" && echo "$out" | grep -q "CODING_STANDARDS.md: missing" && echo "$out" | grep -q "Agent docs"; then echo "PASS layout names the missing required files"; else echo "FAIL layout did not name the missing required files"; echo "$out"; fail=1; fi
mkdir -p "$tmp/beat" && touch "$tmp/beat/CONTEXT.md"
gitc add -A >/dev/null && gitc commit -qm "legacy glossary"
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q "beat/CONTEXT.md exists"; then echo "PASS layout flags an existing beat/CONTEXT.md"; else echo "FAIL layout missed beat/CONTEXT.md"; echo "$out"; fail=1; fi
gitc rm -q beat/CONTEXT.md && gitc commit -qm "drop legacy glossary"
mkdir -p "$tmp/docs/agents"
echo "# Issue tracker" > "$tmp/docs/agents/issue-tracker.md"
echo "# Coding standards" > "$tmp/CODING_STANDARDS.md"
printf '# Project\n\n## Agent docs\n\n- Glossary: `GLOSSARY.md`\n' > "$tmp/CLAUDE.md"
echo "notes" > "$tmp/note.md"
gitc add -A >/dev/null && gitc commit -qm "agent docs"
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "layout ok"; then echo "PASS layout ok with the required agent docs"; else echo "FAIL layout rejected a complete layout"; echo "$out"; fail=1; fi
echo "glossary lives in beat/CONTEXT.md" >> "$tmp/note.md"
gitc add -A >/dev/null && gitc commit -qm "legacy ref"
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q "note.md: still references"; then echo "PASS layout flags a tracked legacy reference"; else echo "FAIL layout missed a tracked legacy reference"; echo "$out"; fail=1; fi
mkdir -p "$tmp/beat/changes/archive/x"
echo "glossary lives in beat/CONTEXT.md" > "$tmp/beat/changes/archive/x/note.md"
echo "notes" > "$tmp/note.md"
gitc add -A >/dev/null && gitc commit -qm "move to record"
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 0 ]; then echo "PASS layout ignores legacy references in records"; else echo "FAIL layout flagged a record"; echo "$out"; fail=1; fi
mkdir -p "$tmp/skills/x/references"
printf -- '---\nname: x\n---\n' > "$tmp/skills/x/SKILL.md"
echo "glossary lives in beat/CONTEXT.md" > "$tmp/skills/x/references/note.md"
gitc add -A >/dev/null && gitc commit -qm "vendored skill"
out=$(node "$VALIDATOR" "$tmp" --layout 2>&1); rc=$?
if [ $rc -eq 0 ]; then echo "PASS layout skips vendored skill folders"; else echo "FAIL layout flagged a vendored skill folder"; echo "$out"; fail=1; fi
exit $fail
