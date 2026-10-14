#!/usr/bin/env node
// Sync references/*.md and scripts/*.mjs from plugin root into each skill that uses them.
//
// Why this exists:
//   Claude Code Skills spec puts references inside skills/<name>/. The
//   `npx skills add` install path (used by Codex backends) only copies a
//   single skill folder, so plugin-root references/ and scripts/ never reach
//   the agent. This script scans each skill for `references/<file>.md` and
//   `scripts/<file>.mjs` mentions and copies what it actually needs from the
//   canonical root directories. A skill then always finds its scripts at
//   `<skill-dir>/scripts/`, whichever way the plugin was installed.
//
// Modes:
//   node scripts/sync-references.mjs           sync + prune
//   node scripts/sync-references.mjs --check   exit 1 if anything is out of sync
//
// Source of truth lives at /references and /scripts. Do not hand-edit
// skills/<name>/references/ or skills/<name>/scripts/.

import { readdir, readFile, writeFile, mkdir, rm, chmod } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SKILLS_DIR = join(ROOT, 'skills');

// kind -> { source dir, mention pattern, file filter }
const KINDS = {
  references: {
    source: join(ROOT, 'references'),
    pattern: /references\/([a-z0-9][a-z0-9-]*\.md)/g,
    isFile: name => name.endsWith('.md'),
  },
  scripts: {
    source: join(ROOT, 'scripts'),
    pattern: /scripts\/([a-z0-9][a-z0-9-]*\.mjs)/g,
    isFile: name => name.endsWith('.mjs'),
  },
};

const args = process.argv.slice(2);
const checkMode = args.includes('--check');

async function listMarkdownFiles(dir) {
  const out = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name in KINDS) continue; // skip synced output
      out.push(...await listMarkdownFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      out.push(full);
    }
  }
  return out;
}

async function collectNeeded(skillDir, kind) {
  const mdFiles = await listMarkdownFiles(skillDir);
  const needed = new Set();
  for (const f of mdFiles) {
    const content = await readFile(f, 'utf8');
    for (const match of content.matchAll(KINDS[kind].pattern)) needed.add(match[1]);
  }
  return needed;
}

async function readExisting(dir, kind) {
  try {
    const entries = await readdir(dir, { withFileTypes: true });
    return new Set(entries.filter(e => e.isFile() && KINDS[kind].isFile(e.name)).map(e => e.name));
  } catch (err) {
    if (err.code === 'ENOENT') return new Set();
    throw err;
  }
}

async function syncKind(skillDir, kind) {
  const targetDir = join(skillDir, kind);
  const needed = await collectNeeded(skillDir, kind);
  const existing = await readExisting(targetDir, kind);
  const changes = { created: [], updated: [], deleted: [], missing: [] };

  for (const file of needed) {
    let sourceContent;
    try {
      sourceContent = await readFile(join(KINDS[kind].source, file), 'utf8');
    } catch (err) {
      if (err.code === 'ENOENT') { changes.missing.push(file); continue; }
      throw err;
    }
    const targetPath = join(targetDir, file);
    let targetContent;
    try { targetContent = await readFile(targetPath, 'utf8'); } catch (err) { if (err.code !== 'ENOENT') throw err; }

    if (targetContent === undefined) {
      if (!checkMode) {
        await mkdir(targetDir, { recursive: true });
        await writeFile(targetPath, sourceContent);
        if (kind === 'scripts') await chmod(targetPath, 0o755);
      }
      changes.created.push(file);
    } else if (targetContent !== sourceContent) {
      if (!checkMode) await writeFile(targetPath, sourceContent);
      changes.updated.push(file);
    }
  }

  for (const existingFile of existing) {
    if (!needed.has(existingFile)) {
      if (!checkMode) await rm(join(targetDir, existingFile));
      changes.deleted.push(existingFile);
    }
  }

  if (!checkMode && existing.size > 0 && needed.size === 0) {
    try { await rm(targetDir, { recursive: true }); } catch {}
  }

  return { needed: [...needed].sort(), changes };
}

async function main() {
  let skills;
  try {
    skills = (await readdir(SKILLS_DIR, { withFileTypes: true }))
      .filter(e => e.isDirectory()).map(e => e.name).sort();
  } catch (err) {
    console.error(`Cannot read skills dir at ${SKILLS_DIR}: ${err.message}`);
    process.exit(2);
  }

  let totalChanges = 0;
  let hasMissing = false;
  for (const skill of skills) {
    const skillDir = join(SKILLS_DIR, skill);
    const parts = [];
    for (const kind of Object.keys(KINDS)) {
      const { needed, changes } = await syncKind(skillDir, kind);
      const changeCount = changes.created.length + changes.updated.length + changes.deleted.length;
      totalChanges += changeCount;
      if (needed.length === 0 && changeCount === 0 && changes.missing.length === 0) continue;
      parts.push(`${needed.length} ${kind}` +
        (changes.created.length ? ` +${changes.created.length}` : '') +
        (changes.updated.length ? ` ~${changes.updated.length}` : '') +
        (changes.deleted.length ? ` -${changes.deleted.length}` : ''));
      for (const f of changes.created) parts.push(`\n             ${checkMode ? 'missing' : 'created'}: ${kind}/${f}`);
      for (const f of changes.updated) parts.push(`\n             ${checkMode ? 'stale  ' : 'updated'}: ${kind}/${f}`);
      for (const f of changes.deleted) parts.push(`\n             ${checkMode ? 'extra  ' : 'deleted'}: ${kind}/${f}`);
      for (const f of changes.missing) {
        parts.push(`\n             WARN: ${kind}/${f} referenced but missing in ${relative(ROOT, KINDS[kind].source)}/`);
        hasMissing = true;
      }
    }
    console.log(`  ${skill.padEnd(10)} ${parts.length ? parts.join('  ') : 'no references'}`);
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
