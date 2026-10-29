#!/usr/bin/env node
// Lint Beat feature files against references/feature-writing.md and
// references/testing-conventions.md. Deterministic; no LLM.
//
// Rules (E = error, W = warning):
//   1 E  @covered-by references point to existing files
//   2 E  @behavior scenarios have @covered-by — only where tests are expected:
//        files under beat/features/, or a change whose phase is verify or later
//        (pass --require-covered-by to force, --no-require-covered-by to relax)
//   3 E  every scenario has a testing-layer tag (@e2e, @behavior, or config lint.layer_tags); W when it has more than one
//   4 W  "# language:" declaration matches config.yaml language (when set)
//   5 E  feature description carries a user story (As a / I want / So that, or the zh-TW form)
//   6 W  only known tags (core set + config lint.tags)
//   7 W  no section with a single scenario
//   8 W  @covered-by on @behavior points at a test artifact, unless "# @covered-by-structural: <why>"
//   9 W  beat/features/README.md index matches the feature tree (whole-project runs only)
//  10 W  @covered-by test file contains a matching "@scenario:" (or pytest-bdd @scenario(...)) for the scenario
//  11 E  no TBD / TODO / FIXME placeholders
//  12 W  implementation leaks in @behavior step text: function calls like fooBar(...) / foo_bar(...), bare decimals
//
// Usage:
//   node lint-features.mjs [--project <root>] [--require-covered-by | --no-require-covered-by] [file.feature ...]
// Exit 1 when any error was reported.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, relative, dirname, resolve, isAbsolute } from 'node:path';

const argv = process.argv.slice(2);
function flag(name) { const i = argv.indexOf(name); if (i >= 0) { argv.splice(i, 1); return true; } return false; }
function opt(name, def) { const i = argv.indexOf(name); if (i >= 0) { const v = argv[i + 1]; argv.splice(i, 2); return v; } return def; }

const requireCoveredBy = flag('--require-covered-by') ? true : flag('--no-require-covered-by') ? false : null;
const ROOT = resolve(opt('--project', process.cwd()));
const FEATURES_DIR = join(ROOT, 'beat', 'features');
const CHANGES_DIR = join(ROOT, 'beat', 'changes');

// ---------- config (minimal: language + lint.tags + lint.pending_tag) ----------
const config = { language: null, tags: [], layerTags: [], pendingTag: '@pending' };
try {
  const text = readFileSync(join(ROOT, 'beat', 'config.yaml'), 'utf8');
  const lang = text.match(/^language:\s*(\S+)/m); if (lang) config.language = lang[1];
  const lintBlock = text.match(/^lint:\n((?:[ \t]+.*\n?)*)/m);
  if (lintBlock) {
    const tags = lintBlock[1].match(/^\s+tags:\s*\[([^\]]*)\]/m);
    if (tags) config.tags = tags[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
    const tagLines = lintBlock[1].match(/^\s+tags:\s*\n((?:\s+-\s+.*\n?)*)/m);
    if (tagLines) config.tags.push(...[...tagLines[1].matchAll(/-\s+(\S+)/g)].map(m => m[1]));
    const pending = lintBlock[1].match(/^\s+pending_tag:\s*(\S+)/m); if (pending) config.pendingTag = pending[1];
    const layers = lintBlock[1].match(/^\s+layer_tags:\s*\[([^\]]*)\]/m);
    if (layers) config.layerTags = layers[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
  }
} catch {}

const CORE_TAGS = ['@e2e', '@behavior', '@happy-path', '@error-handling', '@edge-case', '@distilled', '@wip'];
const VALID_TAGS = new Set([...CORE_TAGS, config.pendingTag, ...config.tags, ...config.layerTags]);
const LAYER_TAGS = new Set(['@e2e', '@behavior', ...config.layerTags]);
const TEST_REF_PATTERN = /(\.test\.|\.spec\.|\.steps\.|_test\.|(^|\/)tests?\/|\/e2e\/|\/__tests__\/|\/features\/steps\/)/;

const SCENARIO_RE = /^(Scenario(?: Outline)?:|場景:|場景大綱:|シナリオ:|Szenario:)\s*(.*)$/;
const FEATURE_RE = /^(Feature:|功能:|フィーチャ:|Funktionalität:)/;
const STEP_RE = /^(Given |When |Then |And |But |\* |假設|當 |那麼|而且|並且|但是)/;
const SECTION_RE = /^#\s*---\s*(.+?)\s*---/;

// ---------- discovery ----------
function findFeatureFiles(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...findFeatureFiles(full));
    else if (entry.endsWith('.feature')) out.push(full);
  }
  return out;
}
function activeChanges() {
  if (!existsSync(CHANGES_DIR)) return [];
  return readdirSync(CHANGES_DIR).filter(e => e !== 'archive' && existsSync(join(CHANGES_DIR, e, 'status.yaml')));
}
const PHASE_ORDER = ['new', 'proposal', 'gherkin', 'design', 'tasks', 'implement', 'verify', 'sync', 'archive'];
function changePhase(name) {
  try { return (readFileSync(join(CHANGES_DIR, name, 'status.yaml'), 'utf8').match(/^phase:\s*(\S+)/m) || [])[1] ?? 'new'; } catch { return 'new'; }
}
function testsExpected(file) {
  if (requireCoveredBy !== null) return requireCoveredBy;
  const rel = relative(ROOT, file);
  if (rel.startsWith(join('beat', 'features'))) return true;
  const m = rel.match(/^beat\/changes\/([^/]+)\//);
  if (!m || m[1] === 'archive') return false;
  return PHASE_ORDER.indexOf(changePhase(m[1])) >= PHASE_ORDER.indexOf('verify');
}

// ---------- reporting ----------
const errors = [], warnings = [];
const err = (file, line, rule, msg) => errors.push({ file: relative(ROOT, file), line, rule, msg });
const warn = (file, line, rule, msg) => warnings.push({ file: relative(ROOT, file), line, rule, msg });

// ---------- rule 10 helper ----------
function testFileMentionsScenario(testPath, scenarioName) {
  let text; try { text = readFileSync(testPath, 'utf8'); } catch { return null; }
  if (text.includes(`@scenario: ${scenarioName}`)) return true;
  if (/@scenario\s*\(/.test(text) && text.includes(scenarioName)) return true; // pytest-bdd
  if (/\.steps\.|features\/steps\//.test(testPath)) return true; // BDD step definitions bind by step text
  return false;
}

// ---------- lint one file ----------
function lintFile(file) {
  const content = readFileSync(file, 'utf8');
  const lines = content.split('\n');
  const expectTests = testsExpected(file);

  // rule 4
  const langDecl = (lines[0]?.match(/^#\s*language:\s*(\S+)/) || [])[1];
  if (config.language && langDecl && langDecl.split('-')[0] !== config.language.split('-')[0]) {
    warn(file, 1, 4, `"# language: ${langDecl}" does not match config language ${config.language}`);
  }

  // rule 5
  const hasEn = /As an?\s/i.test(content) && /I want/i.test(content) && /So that/i.test(content);
  const hasZh = content.includes('作為') && content.includes('我想要') && content.includes('這樣');
  if (!hasEn && !hasZh) err(file, 1, 5, 'Feature description missing user story (As a / I want / So that)');

  // rule 11
  lines.forEach((l, i) => { if (/\b(TBD|TODO|FIXME)\b/.test(l)) err(file, i + 1, 11, `Placeholder left in feature: "${l.trim()}"`); });

  let pendingTags = [], pendingCoveredBy = null, pendingStructural = null, featureTags = [];
  let tagLine = 0, section = null, sectionCount = 0, sectionLine = 0;
  const sections = [];
  let inScenario = false, scenarioIsE2e = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim(); const n = i + 1;

    const sec = line.match(SECTION_RE);
    if (sec) { if (section !== null) sections.push({ name: section, count: sectionCount, line: sectionLine }); section = sec[1]; sectionCount = 0; sectionLine = n; continue; }

    if (FEATURE_RE.test(line)) { featureTags = pendingTags; pendingTags = []; continue; }

    if (line.startsWith('@')) {
      const tags = line.split(/\s+/).filter(t => t.startsWith('@'));
      pendingTags.push(...tags); tagLine = n;
      for (const t of tags) if (!VALID_TAGS.has(t)) warn(file, n, 6, `Unknown tag "${t}" (add it to config.yaml lint.tags if intentional)`);
      continue;
    }
    const cb = line.match(/^#\s*@covered-by:\s*(.+)/);
    if (cb) { pendingCoveredBy = { ref: cb[1].trim(), line: n }; continue; }
    const st = line.match(/^#\s*@covered-by-structural:\s*(\S.*)/);
    if (st) { pendingStructural = st[1]; continue; }

    const sc = line.match(SCENARIO_RE);
    if (sc) {
      const name = sc[2].trim();
      sectionCount++; inScenario = true;
      const allTags = [...featureTags, ...pendingTags];
      const layers = allTags.filter(t => LAYER_TAGS.has(t));
      if (layers.length === 0) err(file, n, 3, `Scenario missing testing layer tag (@e2e or @behavior): "${name}"`);
      if (layers.length > 1) warn(file, n, 3, `Scenario has more than one testing layer tag: "${name}"`);
      scenarioIsE2e = layers.includes('@e2e');
      const isBehavior = layers.includes('@behavior');
      const isPending = allTags.includes(config.pendingTag) || allTags.includes('@wip');

      if (pendingCoveredBy && tagLine && pendingCoveredBy.line < tagLine) {
        warn(file, pendingCoveredBy.line, 2, `@covered-by should sit between the tag line and the Scenario line`);
      }
      if (isBehavior && !pendingCoveredBy && expectTests && !isPending) {
        err(file, n, 2, `@behavior scenario missing @covered-by: "${name}"`);
      }
      if (pendingCoveredBy) {
        const refs = pendingCoveredBy.ref.split(',').map(r => r.trim()).filter(Boolean);
        const missing = refs.filter(r => !existsSync(join(ROOT, r)));
        if (missing.length) err(file, pendingCoveredBy.line, 1, `@covered-by references missing file: ${missing.join(', ')}`);
        if (isBehavior && !pendingStructural) {
          const nonTest = refs.filter(r => !TEST_REF_PATTERN.test(r));
          if (nonTest.length) warn(file, pendingCoveredBy.line, 8, `@covered-by points at a non-test artifact (add "# @covered-by-structural: <why>" if intentional): ${nonTest.join(', ')}`);
        }
        for (const r of refs) {
          if (!existsSync(join(ROOT, r))) continue;
          const ok = testFileMentionsScenario(join(ROOT, r), name);
          if (ok === false) warn(file, pendingCoveredBy.line, 10, `${r} has no "@scenario: ${name}" annotation`);
        }
      }
      pendingTags = []; pendingCoveredBy = null; pendingStructural = null; tagLine = 0;
      continue;
    }

    // rule 12: implementation leaks in step text (behavior scenarios only; e2e steps bind to code)
    if (inScenario && !scenarioIsE2e && STEP_RE.test(line)) {
      const leaks = [];
      const plain = line.replace(/"[^"]*"|“[^”]*”|`[^`]*`/g, ' ');
      if (/\b[a-z]+[A-Z][A-Za-z0-9]*\s*\(/.test(plain) || /\b[a-z]+_[a-z0-9_]+\s*\(/.test(plain)) leaks.push('function call');
      if (/(^|\s)\d+\.\d+(?=\s|$)/.test(plain)) leaks.push('bare decimal');
      if (leaks.length) warn(file, n, 12, `Possible implementation detail in step (${leaks.join(', ')}): "${line}"`);
    }
  }
  if (section !== null) sections.push({ name: section, count: sectionCount, line: sectionLine });
  for (const s of sections) if (s.count === 1) warn(file, s.line, 7, `Section "${s.name}" has only one scenario — merge it into a neighbour`);
}

// ---------- run ----------
const cliFiles = argv.filter(a => a.endsWith('.feature')).map(f => isAbsolute(f) ? f : join(process.cwd(), f));
const files = cliFiles.length ? cliFiles
  : [...findFeatureFiles(FEATURES_DIR), ...activeChanges().flatMap(c => findFeatureFiles(join(CHANGES_DIR, c, 'features')))];

for (const f of files) lintFile(f);

if (!cliFiles.length) {
  const readme = join(FEATURES_DIR, 'README.md');
  if (existsSync(readme)) {
    const text = readFileSync(readme, 'utf8');
    for (const f of findFeatureFiles(FEATURES_DIR)) {
      const rel = relative(FEATURES_DIR, f);
      if (!text.includes(`(${rel})`) && !text.includes(`(./${rel})`)) warn(readme, 0, 9, `Feature not indexed in README: ${rel}`);
    }
    for (const m of text.matchAll(/\]\(\.?\/?([^)]+\.feature)\)/g)) {
      if (!existsSync(join(FEATURES_DIR, m[1]))) warn(readme, 0, 9, `README links missing feature file: ${m[1]}`);
    }
  }
}

for (const e of errors) console.error(`error[${e.rule}]: ${e.file}:${e.line} ${e.msg}`);
for (const w of warnings) console.warn(`warning[${w.rule}]: ${w.file}:${w.line} ${w.msg}`);
console.log(`${files.length} feature file(s), ${errors.length} error(s), ${warnings.length} warning(s)`);
process.exit(errors.length ? 1 : 0);
