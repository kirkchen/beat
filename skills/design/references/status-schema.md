# status.yaml Schema

Single source of truth for the `beat/changes/<name>/status.yaml` format.

**Every skill that reads or writes status.yaml MUST follow this schema exactly.**

## Full Schema

```yaml
name: <kebab-case-name>          # required, string
created: YYYY-MM-DD              # required, ISO date
phase: <phase>                   # required, one of the phase values below
source: distill                  # optional, only present when created by /beat:distill
pipeline:
  proposal: { status: <status> } # required
  gherkin: { status: <status> }  # required; optional: modified
  design: { status: <status> }   # required
  tasks: { status: <status> }    # required
```

## Allowed Values

### `phase` (tracks overall change lifecycle)

| Value | Set by | Meaning |
|-------|--------|---------|
| `new` | `/beat:design` | Just created, no artifacts yet |
| `proposal` | `/beat:design` | Proposal artifact created |
| `gherkin` | `/beat:design` | Gherkin features created |
| `design` | `/beat:design` | Design artifact created |
| `tasks` | `/beat:plan` | Tasks artifact created (after review) |
| `implement` | `/beat:plan` | All artifacts done, ready for coding |
| `verify` | `/beat:apply` | Implementation complete, ready for verification |
| `sync` | `/beat:archive` | Features synced to beat/features/ |
| `archive` | `/beat:archive` | Archived (terminal state) |

**Phase advances forward only.** It reflects the LATEST completed step.

`/beat:design` sets phase to the latest completed spec artifact (`proposal`, `gherkin`, or `design`). When a spec artifact is skipped, phase advances to the next non-skipped spec artifact.

`/beat:plan` sets phase to `tasks` after task breakdown, then `implement` when ready for coding.

### `status` (per-artifact in pipeline)

| Value | Meaning |
|-------|---------|
| `pending` | Not yet created |
| `done` | Created successfully |
| `skipped` | User chose to skip this optional artifact |

**`gherkin` is mandatory by default** but can be `skipped` for purely technical changes (e.g., setting up tooling, upgrading dependencies, refactoring without behavior change). When skipped, `proposal` becomes the primary driver for plan, apply, and verify.

### `modified` (optional, gherkin only)

Array of paths to existing feature files in `beat/features/` that were modified by this change. Only present when the change modifies (not just adds) existing scenarios.

When a change modifies an existing feature file:
1. The original is renamed to `.feature.orig` in `beat/features/` (hidden from BDD runners)
2. The modified version is placed in `beat/changes/<name>/features/`
3. The original path (without `.orig`) is recorded in `modified`

Used by:
- **plan**: writes the list when creating `.orig` backups
- **verify**: triggers semantic verification for modified scenarios (diff `.orig` vs current)
- **archive**: knows which `.orig` files to clean up after sync

```yaml
# Example: change modifies an existing feature file
gherkin: { status: done, modified: ["beat/features/auth/login.feature"] }
```

## Examples

### Fresh change
```yaml
name: add-user-auth
created: 2026-03-05
phase: new
pipeline:
  proposal: { status: pending }
  gherkin: { status: pending }
  design: { status: pending }
  tasks: { status: pending }
```

### After proposal created
```yaml
name: add-user-auth
created: 2026-03-05
phase: proposal
pipeline:
  proposal: { status: done }
  gherkin: { status: pending }
  design: { status: pending }
  tasks: { status: pending }
```

### Minimal path (proposal + design skipped)
```yaml
name: fix-login-bug
created: 2026-03-05
phase: implement
pipeline:
  proposal: { status: skipped }
  gherkin: { status: done }
  design: { status: skipped }
  tasks: { status: skipped }
```

### Technical change (gherkin skipped)
```yaml
name: setup-vitest
created: 2026-03-05
phase: implement
pipeline:
  proposal: { status: done }
  gherkin: { status: skipped }
  design: { status: skipped }
  tasks: { status: done }
```

### Change that modifies existing features
```yaml
name: add-two-factor
created: 2026-04-07
phase: implement
pipeline:
  proposal: { status: done }
  gherkin: { status: done, modified: ["beat/features/auth/login.feature"] }
  design: { status: skipped }
  tasks: { status: done }
```

### Distilled from existing code (after artifacts generated)
```yaml
name: distill-auth-module
created: 2026-03-05
phase: design
source: distill
pipeline:
  proposal: { status: done }
  gherkin: { status: done }
  design: { status: done }
  tasks: { status: pending }
```

## Rules

1. **Always use inline YAML flow style** for pipeline entries: `{ status: done }`, not multi-line. Exception: when `modified` is present, use `{ status: done, modified: [...] }`
2. **Never add extra fields** to pipeline entries — only `status` (and `modified` for gherkin)
3. **Never add extra entries** to pipeline — only the four listed
4. **Phase must match reality** — set to the latest completed artifact name, or `implement`/`verify`/`sync`/`archive` for later stages
5. **Read before write** — always read the current status.yaml before updating to preserve existing fields (like `source`)
