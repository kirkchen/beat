#!/usr/bin/env node
// Validate Beat's YAML-shaped artifacts against their schemas.
//
// Why this exists:
//   status.yaml, route status.yaml and verify.md front matter are written by
//   agents following prose instructions, and prose drifts: field names get
//   invented, flow style becomes block style, routes point at changes that
//   don't exist. Testing that with `claude -p` is slow and non-deterministic;
//   a script is neither. CI and skills can run it after every write.
//
// Usage:
//   node validate-beat.mjs [<project-root>] [--all]       validate active changes, routes, config and
//                                                         .orig residue (--all includes beat/changes/archive/)
//   node validate-beat.mjs --change <name>                validate one change (status.yaml, verify.md, its route)
//                                                         plus config and .orig residue — what a skill runs mid-pipeline
//   node validate-beat.mjs --file <path>                  validate one status.yaml / route status.yaml / verify.md
//   node validate-beat.mjs --pre-archive <change>         the change may be archived: verification passed,
//                                                         sha is an ancestor of HEAD, tasks all checked (incremental is a warning)
//   node validate-beat.mjs --stale-paths <change>         list files still referencing beat/changes/<change>
//                                                         (run after the archive move; exit 1 when any remain)
//   node validate-beat.mjs --handoff <file|->              check a "## Beat Handoff" block (file or stdin)
//
// Exit 1 on any error. Warnings never fail the run. Checks that need git are
// skipped with a warning when the project is not a git checkout.
//
// The parser below handles the YAML subset the schemas allow (block maps,
// inline flow maps, inline arrays, block sequences, scalars, comments) and
// nothing more. If a file needs more YAML than that, it is already outside
// the schema.

import { readFile, readdir, stat } from 'node:fs/promises';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const readFileSyncUtf8 = p => readFileSync(p, 'utf8');

// Locate a change by name: beat/changes/<name>/, or an archived directory whose
// status.yaml records that name. Archive directories are YYYY-MM-DD-<name>, but
// a name that already starts with a date may be archived without a second
// prefix, so match on the recorded name rather than the directory suffix.
export function findChange(projectRoot, name) {
  const active = join(projectRoot, 'beat', 'changes', name);
  if (existsSync(join(active, 'status.yaml'))) return { dir: active, archived: false };
  const archiveDir = join(projectRoot, 'beat', 'changes', 'archive');
  if (!existsSync(archiveDir)) return null;
  for (const d of readdirSync(archiveDir)) {
    const st = join(archiveDir, d, 'status.yaml');
    if (!existsSync(st)) continue;
    if (d === name || d.endsWith(`-${name}`)) return { dir: join(archiveDir, d), archived: true };
    try { if (parseYaml(readFileSyncUtf8(st)).name === name) return { dir: join(archiveDir, d), archived: true }; } catch {}
  }
  return null;
}
import { join, relative, basename, dirname, resolve } from 'node:path';

// ---------- minimal YAML ----------

class YamlError extends Error {}

function parseScalar(raw) {
  const s = raw.trim();
  if (s === '' || s === '~' || s === 'null') return null;
  if (s === 'true') return true;
  if (s === 'false') return false;
  if (/^-?\d+$/.test(s)) return Number(s);
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) return s.slice(1, -1);
  return s;
}

// Split "a: b, c: [x, y], d: { e: f }" on top-level commas.
function splitTop(s, sep) {
  const out = []; let depth = 0, cur = '', quote = null;
  for (const ch of s) {
    if (quote) { cur += ch; if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") { quote = ch; cur += ch; continue; }
    if (ch === '{' || ch === '[') depth++;
    if (ch === '}' || ch === ']') depth--;
    if (ch === sep && depth === 0) { out.push(cur); cur = ''; continue; }
    cur += ch;
  }
  if (cur.trim() !== '') out.push(cur);
  return out;
}

function parseFlow(s) {
  const t = s.trim();
  if (t.startsWith('{')) {
    if (!t.endsWith('}')) throw new YamlError(`unterminated flow map: ${t}`);
    const obj = {};
    for (const part of splitTop(t.slice(1, -1), ',')) {
      const i = part.indexOf(':');
      if (i < 0) throw new YamlError(`flow map entry without ':': ${part.trim()}`);
      obj[part.slice(0, i).trim()] = parseFlow(part.slice(i + 1));
    }
    return obj;
  }
  if (t.startsWith('[')) {
    if (!t.endsWith(']')) throw new YamlError(`unterminated flow array: ${t}`);
    return splitTop(t.slice(1, -1), ',').map(parseFlow);
  }
  return parseScalar(t);
}

function stripComment(line) {
  let quote = null, out = '';
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quote) { out += ch; if (ch === quote) quote = null; continue; }
    if (ch === '"' || ch === "'") { quote = ch; out += ch; continue; }
    if (ch === '#' && (i === 0 || /\s/.test(line[i - 1]))) break;
    out += ch;
  }
  return out.replace(/\s+$/, '');
}

export function parseYaml(text) {
  const lines = text.split('\n').map((raw, i) => ({ text: stripComment(raw), raw, n: i + 1 }))
    .filter(l => l.raw.trim() !== '' && l.text.trim() !== '---');
  let pos = 0;
  const indentOf = l => l.text.match(/^ */)[0].length;

  function block(indent) {
    const first = lines[pos];
    if (!first) return null;
    if (first.text.trim().startsWith('- ')) return seq(indent);
    return map(indent);
  }
  function seq(indent) {
    const arr = [];
    while (pos < lines.length && (lines[pos].text.trim() === '' || (indentOf(lines[pos]) === indent && lines[pos].text.trim().startsWith('- ')))) {
      if (lines[pos].text.trim() === '') { pos++; continue; }
      const body = lines[pos].text.trim().slice(2);
      pos++;
      arr.push(body.startsWith('{') || body.startsWith('[') ? parseFlow(body) : parseScalar(body));
    }
    return arr;
  }
  function map(indent) {
    const obj = {};
    while (pos < lines.length) {
      const l = lines[pos];
      if (l.text.trim() === '') { pos++; continue; }
      const ind = indentOf(l);
      if (ind < indent) break;
      if (ind > indent) throw new YamlError(`line ${l.n}: unexpected indent`);
      const m = l.text.trim().match(/^([^:\s][^:]*?):(?:\s+(.*))?$/);
      if (!m) throw new YamlError(`line ${l.n}: expected "key: value", got "${l.text.trim()}"`);
      const key = m[1]; const rest = m[2];
      pos++;
      if (rest !== undefined && /^[|>][-+]?$/.test(rest.trim())) {
        // block scalar: every following line indented deeper than the key belongs to it
        const parts = [];
        const rawIndent = l => l.raw.match(/^ */)[0].length;
        while (pos < lines.length && rawIndent(lines[pos]) > indent) { parts.push(lines[pos].raw.slice(indent + 2)); pos++; }
        obj[key] = rest.trim().startsWith('>') ? parts.join(' ') : parts.join('\n');
      } else if (rest === undefined || rest === '') {
        const next = lines[pos];
        obj[key] = next && indentOf(next) > indent ? block(indentOf(next)) : null;
      } else if (rest.startsWith('{') || rest.startsWith('[')) {
        obj[key] = parseFlow(rest);
      } else {
        obj[key] = parseScalar(rest);
      }
    }
    return obj;
  }
  const out = block(lines[0] ? indentOf(lines[0]) : 0) ?? {};
  if (pos < lines.length) throw new YamlError(`line ${lines[pos].n}: could not parse`);
  return out;
}

export function frontMatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---(?:\n|$)/);
  return m ? m[1] : null;
}

// ---------- schemas ----------

const PHASES = ['new', 'proposal', 'gherkin', 'design', 'tasks', 'implement', 'verify', 'sync', 'archive'];
const STATUSES = ['pending', 'done', 'skipped'];
const PRESETS = ['full', 'standard', 'minimal', 'technical', 'custom'];
const SEVERITIES = ['CRITICAL', 'WARNING', 'SUGGESTION'];
const DIMENSIONS = ['1A', '1B', '1C', '2', '3', '4', '5A', '5B', '5C'];
const NODE_TYPES = ['research', 'prototype', 'decision', 'change'];
const KEBAB = /^[a-z0-9]+(?:[-.][a-z0-9]+)*$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

function checkKeys(obj, allowed, where, errors) {
  for (const k of Object.keys(obj ?? {})) if (!allowed.includes(k)) errors.push(`${where}: unknown field "${k}"`);
}

export function validateStatus(doc, { file, projectRoot }) {
  const errors = [], warnings = [];
  const where = file;
  checkKeys(doc, ['name', 'created', 'phase', 'preset', 'preset_upgrade', 'route', 'source', 'verification', 'pipeline'], where, errors);
  if (typeof doc.name !== 'string' || !KEBAB.test(doc.name)) errors.push(`${where}: name must be kebab-case`);
  if (typeof doc.created !== 'string' || !DATE.test(doc.created)) errors.push(`${where}: created must be YYYY-MM-DD`);
  if (!PHASES.includes(doc.phase)) errors.push(`${where}: phase must be one of ${PHASES.join(', ')}`);
  if (doc.preset !== undefined && !PRESETS.includes(doc.preset)) errors.push(`${where}: preset must be one of ${PRESETS.join(', ')}`);
  if (doc.source !== undefined && doc.source !== 'distill') errors.push(`${where}: source may only be "distill"`);
  if (doc.preset_upgrade !== undefined) {
    const u = doc.preset_upgrade;
    if (typeof u !== 'object' || u === null) errors.push(`${where}: preset_upgrade must be an inline flow map`);
    else {
      checkKeys(u, ['from', 'by', 'date', 'reason'], `${where} preset_upgrade`, errors);
      if (!PRESETS.includes(u.from)) errors.push(`${where}: preset_upgrade.from must be a preset`);
      if (!DATE.test(String(u.date))) errors.push(`${where}: preset_upgrade.date must be YYYY-MM-DD`);
      if (!u.reason) errors.push(`${where}: preset_upgrade.reason is required`);
    }
  }
  const changeDir = file && projectRoot ? dirname(join(projectRoot, file)) : null;
  const archived = /(^|\/)archive\//.test(String(file ?? ''));
  if (!archived && doc.preset === undefined && doc.phase !== 'new') warnings.push(`${where}: preset missing — later phases run at standard strength until /beat:design (or a hand edit) sets it`);
  if (doc.route !== undefined) {
    const m = String(doc.route).match(/^([a-z0-9-]+)\/([a-z0-9-]+)$/);
    if (!m) errors.push(`${where}: route must be "<route-name>/<node-id>"`);
    else if (projectRoot) {
      const routeFile = join(projectRoot, 'beat', 'routes', m[1], 'status.yaml');
      if (!existsSync(routeFile)) errors.push(`${where}: route "${m[1]}" has no beat/routes/${m[1]}/status.yaml`);
      else {
        try {
          const r = parseYaml(readFileSyncUtf8(routeFile));
          const node = r.nodes?.[m[2]];
          if (!node) errors.push(`${where}: route "${m[1]}" has no node "${m[2]}"`);
          else if (node.change !== doc.name) errors.push(`${where}: route node ${doc.route} points at change "${node.change ?? ''}", not "${doc.name}"`);
        } catch (e) { warnings.push(`${where}: could not read route status.yaml (${e.message})`); }
      }
    }
  }
  if (doc.verification !== undefined) {
    const v = doc.verification;
    if (typeof v !== 'object' || v === null) errors.push(`${where}: verification must be an inline flow map`);
    else {
      checkKeys(v, ['status', 'critical', 'warning', 'date', 'sha', 'mode', 'round'], `${where} verification`, errors);
      if (v.round !== undefined && (typeof v.round !== 'number' || v.round < 1)) errors.push(`${where}: verification.round must be a positive number`);
      if (!['passed', 'issues-found'].includes(v.status)) errors.push(`${where}: verification.status must be passed or issues-found`);
      if (typeof v.critical !== 'number') errors.push(`${where}: verification.critical must be a number`);
      if (!DATE.test(String(v.date))) errors.push(`${where}: verification.date must be YYYY-MM-DD`);
      if (v.mode !== undefined && !['full', 'incremental'].includes(v.mode)) errors.push(`${where}: verification.mode must be full or incremental`);
      if (v.sha === undefined) warnings.push(`${where}: verification.sha missing — incremental verify will fall back to full`);
      if (v.status === 'passed' && v.critical !== 0) errors.push(`${where}: verification.status passed but critical is ${v.critical}`);
    }
  }
  const p = doc.pipeline;
  if (typeof p !== 'object' || p === null) errors.push(`${where}: pipeline is required`);
  else {
    const expected = ['proposal', 'gherkin', 'design', 'tasks'];
    checkKeys(p, expected, `${where} pipeline`, errors);
    for (const k of expected) {
      const e = p[k];
      if (typeof e !== 'object' || e === null) { errors.push(`${where}: pipeline.${k} must be an inline flow map`); continue; }
      checkKeys(e, k === 'gherkin' ? ['status', 'modified'] : ['status'], `${where} pipeline.${k}`, errors);
      if (!STATUSES.includes(e.status)) errors.push(`${where}: pipeline.${k}.status must be one of ${STATUSES.join(', ')}`);
      if (k === 'gherkin' && e.modified !== undefined && !Array.isArray(e.modified)) errors.push(`${where}: pipeline.gherkin.modified must be an array`);
    }
    // artifact files vs pipeline status, phase vs pipeline
    if (changeDir && existsSync(changeDir)) {
      const has = f => existsSync(join(changeDir, f));
      const featureFiles = existsSync(join(changeDir, 'features')) ? readdirSync(join(changeDir, 'features')).filter(f => f.endsWith('.feature')) : [];
      const artifact = { proposal: has('proposal.md'), gherkin: featureFiles.length > 0, design: has('design.md'), tasks: has('tasks.md') };
      for (const k of expected) {
        const st = p[k]?.status;
        if (st === 'done' && !artifact[k]) errors.push(`${where}: pipeline.${k} is done but ${k === 'gherkin' ? 'features/*.feature' : k + '.md'} is missing`);
        if (st === 'skipped' && artifact[k]) warnings.push(`${where}: pipeline.${k} is skipped but ${k === 'gherkin' ? 'features/*.feature' : k + '.md'} exists`);
      }
      const phaseIdx = PHASES.indexOf(doc.phase);
      const needDone = { proposal: 1, gherkin: 2, design: 3, tasks: 4 };
      for (const k of expected) {
        if (phaseIdx > needDone[k] && p[k]?.status === 'pending') errors.push(`${where}: phase is ${doc.phase} but pipeline.${k} is still pending`);
      }
      if (phaseIdx >= PHASES.indexOf('verify') && artifact.tasks) {
        const open = (readFileSyncUtf8(join(changeDir, 'tasks.md')).match(/^\s*- \[ \]/gm) || []).length;
        if (open > 0) errors.push(`${where}: phase is ${doc.phase} but tasks.md has ${open} unchecked task(s)`);
      }
      // gherkin.modified consistency
      for (const m of (p.gherkin?.modified ?? [])) {
        if (projectRoot && !existsSync(join(projectRoot, `${m}.orig`))) errors.push(`${where}: gherkin.modified lists ${m} but ${m}.orig does not exist`);
        if (!featureFiles.includes(basename(m))) errors.push(`${where}: gherkin.modified lists ${m} but features/${basename(m)} is not in the change`);
      }
      // verify.md cross-check
      if (has('verify.md')) {
        try {
          const fm = frontMatter(readFileSyncUtf8(join(changeDir, 'verify.md')));
          const v = fm ? parseYaml(fm) : null;
          if (v) {
            if (v.change !== doc.name) errors.push(`${where}: verify.md is for change "${v.change}", not "${doc.name}"`);
            if (doc.verification) {
              if (doc.verification.sha !== undefined && String(v.sha) !== String(doc.verification.sha)) errors.push(`${where}: verification.sha ${doc.verification.sha} differs from verify.md sha ${v.sha}`);
              const open = (v.findings ?? []).filter(f => f && f.status === 'open');
              const crit = open.filter(f => f.severity === 'CRITICAL').length;
              const warnN = open.filter(f => f.severity === 'WARNING').length;
              if (doc.verification.critical !== crit) errors.push(`${where}: verification.critical is ${doc.verification.critical} but verify.md has ${crit} open CRITICAL finding(s)`);
              if (doc.verification.warning !== undefined && doc.verification.warning !== warnN) errors.push(`${where}: verification.warning is ${doc.verification.warning} but verify.md has ${warnN} open WARNING finding(s)`);
            }
          }
        } catch (e) { warnings.push(`${where}: could not cross-check verify.md (${e.message})`); }
      } else if (doc.verification && !archived) {
        warnings.push(`${where}: verification recorded but verify.md is missing`);
      }
      // sha ancestry
      if (doc.verification?.sha && projectRoot && !archived) {
        const anc = isAncestor(projectRoot, String(doc.verification.sha));
        if (anc === false) warnings.push(`${where}: verification.sha ${doc.verification.sha} is not an ancestor of HEAD — next verify must be full`);
      }
    }
  }
  return { errors, warnings };
}

function git(projectRoot, args) {
  try { return execFileSync('git', args, { cwd: projectRoot, stdio: ['ignore', 'pipe', 'ignore'] }).toString(); } catch { return null; }
}
function isAncestor(projectRoot, sha) {
  if (git(projectRoot, ['rev-parse', '--is-inside-work-tree']) === null) return null;
  try { execFileSync('git', ['merge-base', '--is-ancestor', sha, 'HEAD'], { cwd: projectRoot, stdio: 'ignore' }); return true; } catch { return false; }
}

export function validateConfig(doc, { file }) {
  const errors = [], warnings = [];
  checkKeys(doc, ['language', 'context', 'testing', 'prototype', 'preset_upgrade', 'lint', 'rules'], file, errors);
  if (doc.context !== undefined && String(doc.context).length > 50 * 1024) errors.push(`${file}: context exceeds 50KB`);
  else if (doc.context !== undefined && String(doc.context).length > 2 * 1024) warnings.push(`${file}: context exceeds the 2KB soft limit`);
  if (doc.testing) checkKeys(doc.testing, ['required', 'behavior', 'e2e', 'framework'], `${file} testing`, errors);
  if (doc.prototype) checkKeys(doc.prototype, ['surface', 'command'], `${file} prototype`, errors);
  if (doc.preset_upgrade) {
    checkKeys(doc.preset_upgrade, ['files', 'lines', 'modules'], `${file} preset_upgrade`, errors);
    for (const k of ['files', 'lines', 'modules']) if (doc.preset_upgrade[k] !== undefined && typeof doc.preset_upgrade[k] !== 'number') errors.push(`${file}: preset_upgrade.${k} must be a number`);
  }
  if (doc.lint) checkKeys(doc.lint, ['tags', 'layer_tags', 'pending_tag'], `${file} lint`, errors);
  if (doc.rules) for (const k of Object.keys(doc.rules)) if (!['proposal', 'gherkin', 'design', 'tasks', 'adr'].includes(k)) warnings.push(`${file}: rules.${k} is not a known artifact and will be ignored`);
  return { errors, warnings };
}

export function validateHandoff(text, { file }) {
  const errors = [], warnings = [];
  const m = text.match(/## Beat Handoff\n([\s\S]*?)(?:\n\s*\n|$)/);
  if (!m) return { errors: [`${file}: no "## Beat Handoff" block`], warnings };
  const keys = {};
  for (const line of m[1].split('\n')) for (const kv of line.matchAll(/(^|\s)([a-z-]+):\s*(\S[^\n]*?)(?=\s{2,}[a-z-]+:|$)/g)) keys[kv[2]] = kv[3].trim();
  for (const k of ['change', 'phase', 'commit', 'branch', 'dirty', 'next', 'blocked-on']) if (!(k in keys)) errors.push(`${file}: handoff block missing "${k}"`);
  if (keys.dirty && !['yes', 'no'].includes(keys.dirty)) errors.push(`${file}: dirty must be yes or no`);
  if (keys.next && (keys.next.includes('\n') || /\bor\b/.test(keys.next))) errors.push(`${file}: next must be exactly one command`);
  if (keys.commit && !/^[0-9a-f]{7,40}$/.test(keys.commit)) errors.push(`${file}: commit must be a git sha`);
  for (const k of ['critical', 'warning']) if (keys.findings && !new RegExp(`${k}=\\d+`).test(keys.findings)) errors.push(`${file}: findings must carry ${k}=<n>`);
  return { errors, warnings };
}

export function checkOrigResidue(projectRoot) {
  const errors = [], warnings = [];
  const featDir = join(projectRoot, 'beat', 'features');
  const origs = [];
  const walkSync = d => { for (const e of readdirSync(d)) { const f = join(d, e); if (statSync(f).isDirectory()) walkSync(f); else if (e.endsWith('.feature.orig')) origs.push(f); } };
  if (existsSync(featDir)) walkSync(featDir);
  if (!origs.length) return { errors, warnings };
  const claimed = new Map();
  const changesDir = join(projectRoot, 'beat', 'changes');
  for (const c of existsSync(changesDir) ? readdirSync(changesDir) : []) {
    if (c === 'archive') continue;
    const st = join(changesDir, c, 'status.yaml');
    if (!existsSync(st)) continue;
    try { for (const m of (parseYaml(readFileSyncUtf8(st)).pipeline?.gherkin?.modified ?? [])) claimed.set(m, [...(claimed.get(m) ?? []), c]); } catch {}
  }
  for (const o of origs) {
    const rel = relative(projectRoot, o).replace(/\.orig$/, '');
    const owners = claimed.get(rel) ?? [];
    if (owners.length === 0) errors.push(`${rel}.orig: orphan backup — no active change lists it in gherkin.modified (archive should have removed it)`);
    if (owners.length > 1) errors.push(`${rel}.orig: modified by more than one active change (${owners.join(', ')})`);
  }
  return { errors, warnings };
}

export function stalePaths(projectRoot, change) {
  const pattern = `beat/changes/${change}(/|[^A-Za-z0-9_-]|$)`;
  const found = findChange(projectRoot, change);
  const exclude = found?.archived ? relative(projectRoot, join(found.dir, 'status.yaml')) : `beat/changes/archive/*${change}/status.yaml`;
  const out = git(projectRoot, ['grep', '-lE', '--untracked', pattern, '--', '.', `:!${exclude}`]);
  if (out === null) return { errors: [], warnings: ['not a git checkout — cannot grep for stale paths'] };
  const files = out.split('\n').filter(Boolean);
  return { errors: files.map(f => `${f}: still references beat/changes/${change}`), warnings: [] };
}

export function preArchive(projectRoot, change) {
  const errors = [], warnings = [];
  const st = join(projectRoot, 'beat', 'changes', change, 'status.yaml');
  if (!existsSync(st)) return { errors: [`beat/changes/${change}/status.yaml not found`], warnings };
  const doc = parseYaml(readFileSyncUtf8(st));
  const v = doc.verification;
  if (!v) errors.push(`${change}: never verified`);
  else {
    if (v.status !== 'passed') errors.push(`${change}: last verify found ${v.critical} critical issue(s)`);
    if (v.mode === 'incremental') warnings.push(`${change}: last verify was incremental (round ${v.round ?? '?'}) — untouched artifacts were not re-read; a full re-run is optional`);
    if (v.warning) warnings.push(`${change}: ${v.warning} open WARNING finding(s) ride along into archive`);
    if (v.sha) { const a = isAncestor(projectRoot, String(v.sha)); if (a === false) errors.push(`${change}: verification.sha ${v.sha} is not an ancestor of HEAD`); if (a === null) warnings.push('not a git checkout — sha ancestry not checked'); }
  }
  const tasks = join(projectRoot, 'beat', 'changes', change, 'tasks.md');
  if (existsSync(tasks)) { const open = (readFileSyncUtf8(tasks).match(/^\s*- \[ \]/gm) || []).length; if (open) errors.push(`${change}: tasks.md has ${open} unchecked task(s)`); }
  return { errors, warnings };
}

export function validateRoute(doc, { file, projectRoot }) {
  const errors = [], warnings = [];
  const where = file;
  checkKeys(doc, ['name', 'created', 'nodes'], where, errors);
  if (typeof doc.name !== 'string' || !KEBAB.test(doc.name)) errors.push(`${where}: name must be kebab-case`);
  if (file && doc.name && basename(dirname(file)) !== doc.name && basename(dirname(file)) !== '') {
    const dir = basename(dirname(file));
    if (dir !== doc.name && !/^\d{4}-\d{2}-\d{2}-/.test(dir)) errors.push(`${where}: name "${doc.name}" does not match directory "${dir}"`);
  }
  if (typeof doc.created !== 'string' || !DATE.test(doc.created)) errors.push(`${where}: created must be YYYY-MM-DD`);
  const nodes = doc.nodes;
  if (typeof nodes !== 'object' || nodes === null) { errors.push(`${where}: nodes is required`); return { errors, warnings }; }
  const ids = Object.keys(nodes);
  for (const id of ids) {
    const n = nodes[id] ?? {};
    const w = `${where} nodes.${id}`;
    if (!KEBAB.test(id)) errors.push(`${w}: node id must be kebab-case`);
    checkKeys(n, ['type', 'title', 'blocked_by', 'change', 'result', 'question'], w, errors);
    if (!NODE_TYPES.includes(n.type)) errors.push(`${w}: type must be one of ${NODE_TYPES.join(', ')}`);
    if (!n.title) errors.push(`${w}: title is required`);
    const bb = n.blocked_by ?? [];
    if (!Array.isArray(bb)) errors.push(`${w}: blocked_by must be an array`);
    else for (const b of bb) if (!ids.includes(b)) errors.push(`${w}: blocked_by references unknown node "${b}"`);
    if (n.type === 'change') {
      if (n.result !== undefined || n.question !== undefined) errors.push(`${w}: change nodes have no result/question`);
      if (n.change !== undefined && projectRoot) {
        const found = findChange(projectRoot, String(n.change));
        if (!found) errors.push(`${w}: change "${n.change}" not found under beat/changes/ or beat/changes/archive/`);
        else {
          try {
            const s = parseYaml(readFileSyncUtf8(join(found.dir, 'status.yaml')));
            if (s.route !== `${doc.name}/${id}`) errors.push(`${w}: ${relative(projectRoot, join(found.dir, 'status.yaml'))} route is "${s.route ?? ''}", expected "${doc.name}/${id}"`);
          } catch (e) { warnings.push(`${w}: could not read change status.yaml (${e.message})`); }
        }
      }
    } else {
      if (n.change !== undefined) errors.push(`${w}: only change nodes may have "change"`);
      if (!n.question) errors.push(`${w}: ${n.type} nodes need a question`);
      if (n.result === undefined) warnings.push(`${w}: no result path yet — node cannot become done`);
    }
  }
  // cycle check
  const state = {};
  const visit = (id, stack) => {
    if (state[id] === 'done') return;
    if (state[id] === 'visiting') { errors.push(`${where}: blocked_by cycle through ${[...stack, id].join(' -> ')}`); return; }
    state[id] = 'visiting';
    for (const b of (nodes[id]?.blocked_by ?? [])) if (ids.includes(b)) visit(b, [...stack, id]);
    state[id] = 'done';
  };
  for (const id of ids) visit(id, []);
  return { errors, warnings };
}

export function validateVerify(doc, { file }) {
  const errors = [], warnings = [];
  const where = file;
  checkKeys(doc, ['change', 'date', 'sha', 'mode', 'round', 'base', 'findings'], where, errors);
  if (doc.round !== undefined && (typeof doc.round !== 'number' || doc.round < 1)) errors.push(`${where}: round must be a positive number`);
  if (!doc.change) errors.push(`${where}: change is required`);
  if (!DATE.test(String(doc.date))) errors.push(`${where}: date must be YYYY-MM-DD`);
  if (!doc.sha) errors.push(`${where}: sha is required`);
  if (!['full', 'incremental'].includes(doc.mode)) errors.push(`${where}: mode must be full or incremental`);
  if (doc.mode === 'incremental' && !doc.base) errors.push(`${where}: incremental runs need base`);
  if (!Array.isArray(doc.findings)) { errors.push(`${where}: findings must be an array (may be empty)`); return { errors, warnings }; }
  const seen = new Set();
  doc.findings.forEach((f, i) => {
    const w = `${where} findings[${i}]`;
    if (typeof f !== 'object' || f === null) { errors.push(`${w}: must be an inline flow map`); return; }
    checkKeys(f, ['id', 'severity', 'dimension', 'scenario', 'file', 'fix', 'status', 'reach'], w, errors);
    if (f.reach !== undefined && !['reachable', 'speculative'].includes(f.reach)) errors.push(`${w}: reach must be reachable or speculative`);
    if (f.reach === 'speculative' && f.severity !== 'SUGGESTION') errors.push(`${w}: speculative findings are capped at SUGGESTION`);
    if (!/^F\d+$/.test(String(f.id))) errors.push(`${w}: id must look like F1`);
    if (seen.has(f.id)) errors.push(`${w}: duplicate id ${f.id}`);
    seen.add(f.id);
    if (!SEVERITIES.includes(f.severity)) errors.push(`${w}: severity must be one of ${SEVERITIES.join(', ')}`);
    if (!DIMENSIONS.includes(String(f.dimension))) errors.push(`${w}: dimension must be one of ${DIMENSIONS.join(', ')}`);
    if (f.file === undefined || f.file === null || f.file === '') errors.push(`${w}: file is required`);
    if (!f.fix) errors.push(`${w}: fix is required`);
    if (!['open', 'fixed', 'wontfix'].includes(f.status)) errors.push(`${w}: status must be open, fixed or wontfix`);
  });
  return { errors, warnings };
}

// ---------- driver ----------

function kindOf(path) {
  const p = path.replace(/\\/g, '/');
  if (/\/beat\/routes\/[^/]+\/status\.yaml$/.test(p) || /\/beat\/routes\/archive\/[^/]+\/status\.yaml$/.test(p)) return 'route';
  if (/\/status\.yaml$/.test(p)) return 'status';
  if (/\/verify\.md$/.test(p)) return 'verify';
  return null;
}

async function validateFile(path, projectRoot) {
  const kind = kindOf(path);
  if (!kind) return { errors: [`${path}: not a status.yaml, route status.yaml or verify.md`], warnings: [] };
  const text = await readFile(path, 'utf8');
  const rel = projectRoot ? relative(projectRoot, path) : path;
  let doc;
  try {
    if (kind === 'verify') {
      const fm = frontMatter(text);
      if (fm === null) return { errors: [`${rel}: verify.md has no YAML front matter`], warnings: [] };
      doc = parseYaml(fm);
    } else doc = parseYaml(text);
  } catch (e) {
    return { errors: [`${rel}: ${e.message}`], warnings: [] };
  }
  const ctx = { file: rel, projectRoot };
  if (kind === 'status') return validateStatus(doc, ctx);
  if (kind === 'route') return validateRoute(doc, ctx);
  return validateVerify(doc, ctx);
}

async function walk(dir, out, includeArchive) {
  let entries;
  try { entries = await readdir(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) { if (e.name === 'archive' && !includeArchive) continue; await walk(full, out, includeArchive); }
    else if (e.name === 'status.yaml' || e.name === 'verify.md') out.push(full);
  }
  return out;
}

function report(results) {
  let errors = 0, warnings = 0;
  for (const r of results) {
    for (const e of r.errors) { console.error(`error: ${e}`); errors++; }
    for (const w of r.warnings) { console.warn(`warning: ${w}`); warnings++; }
  }
  return { errors, warnings };
}

async function main() {
  const args = process.argv.slice(2);
  const takeOpt = name => { const i = args.indexOf(name); if (i < 0) return null; const v = args[i + 1]; args.splice(i, 2); return v; };
  const all = (() => { const i = args.indexOf('--all'); if (i >= 0) { args.splice(i, 1); return true; } return false; })();
  const file = takeOpt('--file'), pre = takeOpt('--pre-archive'), stale = takeOpt('--stale-paths'), handoff = takeOpt('--handoff'), change = takeOpt('--change');
  const projectRoot = resolve(args[0] ?? process.cwd());

  if (handoff) {
    const text = handoff === '-' ? readFileSync(0, 'utf8') : readFileSync(handoff, 'utf8');
    const { errors } = report([validateHandoff(text, { file: handoff })]);
    console.log(errors ? `handoff block: ${errors} error(s)` : 'handoff block ok');
    process.exit(errors ? 1 : 0);
  }
  if (pre) { const { errors } = report([preArchive(projectRoot, pre)]); console.log(errors ? `${pre}: not ready to archive` : `${pre}: ready to archive`); process.exit(errors ? 1 : 0); }
  if (stale) { const { errors } = report([stalePaths(projectRoot, stale)]); console.log(errors ? `${errors} file(s) still reference beat/changes/${stale}` : `no stale references to beat/changes/${stale}`); process.exit(errors ? 1 : 0); }

  let files = [];
  const results = [];
  if (file) files = [file];
  else {
    const beatDir = join(projectRoot, 'beat');
    try { await stat(beatDir); } catch { console.error(`no beat/ directory under ${projectRoot}`); process.exit(1); }
    if (change) {
      const dir = join(beatDir, 'changes', change);
      if (!existsSync(join(dir, 'status.yaml'))) { console.error(`beat/changes/${change}/status.yaml not found`); process.exit(1); }
      files = ['status.yaml', 'verify.md'].map(f => join(dir, f)).filter(existsSync);
      try { const r = parseYaml(readFileSyncUtf8(join(dir, 'status.yaml'))).route; if (r) { const rf = join(beatDir, 'routes', String(r).split('/')[0], 'status.yaml'); if (existsSync(rf)) files.push(rf); } } catch {}
    } else {
      files = [...await walk(join(beatDir, 'changes'), [], all), ...await walk(join(beatDir, 'routes'), [], all)];
    }
    const cfg = join(beatDir, 'config.yaml');
    if (existsSync(cfg)) {
      try { results.push(validateConfig(parseYaml(readFileSyncUtf8(cfg)), { file: 'beat/config.yaml' })); }
      catch (e) { results.push({ errors: [`beat/config.yaml: ${e.message}`], warnings: [] }); }
    }
    results.push(checkOrigResidue(projectRoot));
  }
  for (const f of files) results.push(await validateFile(f, projectRoot));
  const { errors, warnings } = report(results);
  console.log(`${files.length} file(s) checked, ${errors} error(s), ${warnings} warning(s)`);
  process.exit(errors ? 1 : 0);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
