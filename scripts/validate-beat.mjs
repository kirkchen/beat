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
//   node scripts/validate-beat.mjs [<project-root>]   validate beat/ under the root (default: cwd)
//   node scripts/validate-beat.mjs --file <path>      validate one file (type inferred from its path)
//
// Exit 1 on any error. Warnings never fail the run.
//
// The parser below handles the YAML subset the schemas allow (block maps,
// inline flow maps, inline arrays, block sequences, scalars, comments) and
// nothing more. If a file needs more YAML than that, it is already outside
// the schema.

import { readFile, readdir, stat } from 'node:fs/promises';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
const readFileSyncUtf8 = p => readFileSync(p, 'utf8');
import { join, relative, basename, dirname } from 'node:path';

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
  const lines = text.split('\n').map(stripComment).map((l, i) => ({ text: l, n: i + 1 }))
    .filter(l => l.text.trim() !== '' && l.text.trim() !== '---');
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
    while (pos < lines.length && indentOf(lines[pos]) === indent && lines[pos].text.trim().startsWith('- ')) {
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
      const ind = indentOf(l);
      if (ind < indent) break;
      if (ind > indent) throw new YamlError(`line ${l.n}: unexpected indent`);
      const m = l.text.trim().match(/^([^:\s][^:]*?):(?:\s+(.*))?$/);
      if (!m) throw new YamlError(`line ${l.n}: expected "key: value", got "${l.text.trim()}"`);
      const key = m[1]; const rest = m[2];
      pos++;
      if (rest === undefined || rest === '') {
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
  if (doc.route !== undefined) {
    const m = String(doc.route).match(/^([a-z0-9-]+)\/([a-z0-9-]+)$/);
    if (!m) errors.push(`${where}: route must be "<route-name>/<node-id>"`);
    else if (projectRoot) {
      const routeFile = join(projectRoot, 'beat', 'routes', m[1], 'status.yaml');
      if (!existsSync(routeFile)) errors.push(`${where}: route "${m[1]}" has no beat/routes/${m[1]}/status.yaml`);
    }
  }
  if (doc.verification !== undefined) {
    const v = doc.verification;
    if (typeof v !== 'object' || v === null) errors.push(`${where}: verification must be an inline flow map`);
    else {
      checkKeys(v, ['status', 'critical', 'warning', 'date', 'sha', 'mode'], `${where} verification`, errors);
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
  }
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
        const active = join(projectRoot, 'beat', 'changes', n.change, 'status.yaml');
        const archiveDir = join(projectRoot, 'beat', 'changes', 'archive');
        const archived = existsSync(archiveDir)
          && readdirSync(archiveDir).some(d => d.endsWith(`-${n.change}`) && existsSync(join(archiveDir, d, 'status.yaml')));
        if (!existsSync(active) && !archived) errors.push(`${w}: change "${n.change}" not found under beat/changes/`);
        else if (existsSync(active)) {
          try {
            const s = parseYaml(readFileSyncUtf8(active));
            if (s.route !== `${doc.name}/${id}`) errors.push(`${w}: beat/changes/${n.change}/status.yaml route is "${s.route ?? ''}", expected "${doc.name}/${id}"`);
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
  checkKeys(doc, ['change', 'date', 'sha', 'mode', 'base', 'findings'], where, errors);
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
    checkKeys(f, ['id', 'severity', 'dimension', 'scenario', 'file', 'fix', 'status'], w, errors);
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

async function walk(dir, out) {
  let entries;
  try { entries = await readdir(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    const full = join(dir, e.name);
    if (e.isDirectory()) await walk(full, out);
    else if (e.name === 'status.yaml' || e.name === 'verify.md') out.push(full);
  }
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const fileIdx = args.indexOf('--file');
  let files = [], projectRoot;
  if (fileIdx >= 0) {
    files = [args[fileIdx + 1]];
    projectRoot = process.cwd();
  } else {
    projectRoot = args[0] ?? process.cwd();
    const beatDir = join(projectRoot, 'beat');
    try { await stat(beatDir); } catch { console.error(`no beat/ directory under ${projectRoot}`); process.exit(1); }
    files = [...await walk(join(beatDir, 'changes'), []), ...await walk(join(beatDir, 'routes'), [])];
  }
  let errors = 0, warnings = 0;
  for (const f of files) {
    const r = await validateFile(f, projectRoot);
    for (const e of r.errors) { console.error(`error: ${e}`); errors++; }
    for (const w of r.warnings) { console.warn(`warning: ${w}`); warnings++; }
  }
  console.log(`${files.length} file(s) checked, ${errors} error(s), ${warnings} warning(s)`);
  process.exit(errors ? 1 : 0);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
