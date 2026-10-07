# Lint Tools

Two deterministic scripts back the checks that used to live only in prose. Run them where the skills say to; when one exits non-zero, fix what it lists and run it again before moving on.

## Where they are

Each skill that uses a script carries its own copy under `<skill-dir>/scripts/` (synced from the plugin root by `scripts/sync-references.mjs`, like `references/`). `<skill-dir>` is the directory this SKILL.md was loaded from — Claude Code prints it as "Base directory for this skill"; on Codex and after `npx skills add` it is the installed skill folder. The scripts need Node 18+ and no packages.

```bash
node <skill-dir>/scripts/validate-beat.mjs [args]
node <skill-dir>/scripts/lint-features.mjs [args]
```

If `node` is not available, say so in the handoff block's `checks` line and do the listed checks by hand.

## validate-beat.mjs

Checks `status.yaml` (schema, phase vs. artifacts, route link, verify.md cross-check, sha ancestry; a missing `preset` is a warning so changes created before presets existed keep working), route `status.yaml` (node types, `blocked_by` cycles, change links), `verify.md` front matter, `beat/config.yaml`, and `.feature.orig` residue.

| Call | When |
|------|------|
| `validate-beat.mjs --file beat/changes/<name>/status.yaml` | After any skill writes status.yaml |
| `validate-beat.mjs --file beat/changes/<name>/verify.md` | After verify writes verify.md |
| `validate-beat.mjs --change <name>` | Before verify dispatches subagents, and whenever a skill wants the whole picture of one change (status.yaml, verify.md, its route, config, `.orig` residue) without being blocked by other changes' drift |
| `validate-beat.mjs` (whole project, active changes only; `--all` includes archive) | In CI, or when cleaning up a project |
| `validate-beat.mjs --pre-archive <name>` | Archive step 3b — verification passed, mode full, sha is an ancestor of HEAD, tasks all checked |
| `validate-beat.mjs --stale-paths <name>` | Archive step 5b, after the move — lists files still pointing at `beat/changes/<name>`; rerun until it prints none |
| `validate-beat.mjs --handoff <file\|->` | Optional self-check of a handoff block (tests use it) |

## lint-features.mjs

Checks feature files against `references/feature-writing.md` and `references/testing-conventions.md`: `@covered-by` targets exist and carry a matching `@scenario:` annotation, exactly one layer tag per scenario, user story present, known tags, no single-scenario sections, no `TBD`/`TODO`, README index in sync, and (warning only) implementation details leaking into `@behavior` steps.

| Call | When |
|------|------|
| `lint-features.mjs beat/changes/<name>/features/*.feature` | Design and distill, before committing; apply, after each scenario's test and `@covered-by` are written |
| `lint-features.mjs` (whole project) | Before verify dispatches subagents; archive after sync; in CI |

`@covered-by` is only required where tests are expected: under `beat/features/`, or in a change whose phase is `verify` or later. `--require-covered-by` / `--no-require-covered-by` override that. Project-specific tags go in `beat/config.yaml`:

```yaml
lint:
  tags: [@k8s, @flaky]          # accepted in addition to the core set
  layer_tags: [@manual-smoke]   # count as a testing layer like @e2e / @behavior
  pending_tag: "@pending"       # exempts a @behavior scenario from needing @covered-by
```

## What stays with the agent

The scripts settle the mechanical questions so the subagents and the skill can spend their attention on the rest: whether a scenario is written at behavior level, whether the design is followed, whether a decision meets the ADR gate, whether a term belongs in the glossary. When lint output is handed to a verify subagent, it reports lint errors as findings verbatim and does not re-derive them.
