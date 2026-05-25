#!/usr/bin/env node
// Sync references/*.md from plugin root into each skill that uses them.
//
// Why this exists:
//   Claude Code Skills spec puts references inside skills/<name>/. The
//   `npx skills add` install path (used by Codex backends) only copies a
//   single skill folder, so plugin-root references/ never reaches the agent.
//   This script scans each skill for `references/<file>.md` mentions and
//   copies what it actually needs from the canonical root references/.
//
// Modes:
//   node scripts/sync-references.mjs           sync + prune
//   node scripts/sync-references.mjs --check   exit 1 if anything is out of sync
//
// Source of truth lives at /references. Do not hand-edit skills/<name>/references/.

import { readdir, readFile, writeFile, mkdir, rm, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE_DIR = join(ROOT, 'references');
const SKILLS_DIR = join(ROOT, 'skills');

const REFERENCE_PATTERN = /references\/([a-z0-9][a-z0-9-]*\.md)/g;

const args = process.argv.slice(2);
const checkMode = args.includes('--check');

async function listMarkdownFiles(dir) {
  const out = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'references') continue; // skip synced output
      out.push(...await listMarkdownFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      out.push(full);
    }
  }
  return out;
}

async function collectNeededRefs(skillDir) {
  const mdFiles = await listMarkdownFiles(skillDir);
  const needed = new Set();
  for (const f of mdFiles) {
    const content = await readFile(f, 'utf8');
    for (const match of content.matchAll(REFERENCE_PATTERN)) {
      needed.add(match[1]);
    }
  }
  return needed;
}

async function readExistingRefs(refDir) {
  try {
    const entries = await readdir(refDir, { withFileTypes: true });
    return new Set(entries.filter(e => e.isFile() && e.name.endsWith('.md')).map(e => e.name));
  } catch (err) {
    if (err.code === 'ENOENT') return new Set();
    throw err;
  }
}

async function syncSkill(skillName) {
  const skillDir = join(SKILLS_DIR, skillName);
  const refDir = join(skillDir, 'references');

  const needed = await collectNeededRefs(skillDir);
  const existing = await readExistingRefs(refDir);

  const changes = { created: [], updated: [], deleted: [], missing: [] };

  for (const refFile of needed) {
    const sourcePath = join(SOURCE_DIR, refFile);
    let sourceContent;
    try {
      sourceContent = await readFile(sourcePath, 'utf8');
    } catch (err) {
      if (err.code === 'ENOENT') {
        changes.missing.push(refFile);
        continue;
      }
      throw err;
    }

    const targetPath = join(refDir, refFile);
    let targetContent;
    try {
      targetContent = await readFile(targetPath, 'utf8');
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }

    if (targetContent === undefined) {
      if (!checkMode) {
        await mkdir(refDir, { recursive: true });
        await writeFile(targetPath, sourceContent);
      }
      changes.created.push(refFile);
    } else if (targetContent !== sourceContent) {
      if (!checkMode) await writeFile(targetPath, sourceContent);
      changes.updated.push(refFile);
    }
  }

  for (const existingFile of existing) {
    if (!needed.has(existingFile)) {
      if (!checkMode) await rm(join(refDir, existingFile));
      changes.deleted.push(existingFile);
    }
  }

  // Remove an empty references/ folder if everything got pruned
  if (!checkMode && existing.size > 0 && needed.size === 0) {
    try { await rm(refDir, { recursive: true }); } catch {}
  }

  return { skillName, needed: [...needed].sort(), changes };
}

async function main() {
  let skills;
  try {
    skills = (await readdir(SKILLS_DIR, { withFileTypes: true }))
      .filter(e => e.isDirectory())
      .map(e => e.name)
      .sort();
  } catch (err) {
    console.error(`Cannot read skills dir at ${SKILLS_DIR}: ${err.message}`);
    process.exit(2);
  }

  const results = [];
  for (const skill of skills) {
    results.push(await syncSkill(skill));
  }

  let totalChanges = 0;
  let hasMissing = false;
  for (const { skillName, needed, changes } of results) {
    const refCount = needed.length;
    const changeCount = changes.created.length + changes.updated.length + changes.deleted.length;
    totalChanges += changeCount;

    if (refCount === 0 && changeCount === 0 && changes.missing.length === 0) {
      console.log(`  ${skillName.padEnd(10)} no references`);
      continue;
    }

    console.log(`  ${skillName.padEnd(10)} ${refCount} refs` +
      (changes.created.length ? `  +${changes.created.length}` : '') +
      (changes.updated.length ? `  ~${changes.updated.length}` : '') +
      (changes.deleted.length ? `  -${changes.deleted.length}` : ''));

    for (const f of changes.created) console.log(`             ${checkMode ? 'missing' : 'created'}: ${f}`);
    for (const f of changes.updated) console.log(`             ${checkMode ? 'stale  ' : 'updated'}: ${f}`);
    for (const f of changes.deleted) console.log(`             ${checkMode ? 'extra  ' : 'deleted'}: ${f}`);
    for (const f of changes.missing) {
      console.log(`             WARN: ${f} referenced but missing in ${relative(ROOT, SOURCE_DIR)}/`);
      hasMissing = true;
    }
  }

  if (checkMode) {
    if (totalChanges > 0) {
      console.error(`\nreferences out of sync: ${totalChanges} change(s). Run: node scripts/sync-references.mjs`);
      process.exit(1);
    }
    if (hasMissing) process.exit(1);
    console.log('\nreferences in sync');
  } else {
    console.log(`\nsync complete: ${totalChanges} change(s)`);
    if (hasMissing) {
      console.error('one or more skills reference missing source files; see warnings above');
      process.exit(1);
    }
  }
}

main().catch(err => { console.error(err); process.exit(2); });
