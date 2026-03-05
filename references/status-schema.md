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
  gherkin: { status: <status> }  # required
  design: { status: <status> }   # required
  tasks: { status: <status> }    # required
```

## Allowed Values

### `phase` (tracks overall change lifecycle)

| Value | Set by | Meaning |
|-------|--------|---------|
| `new` | `/beat:new` | Just created, no artifacts yet |
| `proposal` | `/beat:continue` | Proposal artifact created |
| `gherkin` | `/beat:continue` | Gherkin features created |
| `design` | `/beat:continue` | Design artifact created |
| `tasks` | `/beat:continue` | Tasks artifact created |
| `implement` | `/beat:continue`, `/beat:ff` | All artifacts done, ready for coding |
| `verify` | `/beat:apply` | Implementation complete, ready for verification |
| `sync` | `/beat:sync` | Features synced to specs/ |
| `archive` | `/beat:archive` | Archived (terminal state) |

**Phase advances forward only.** It reflects the LATEST completed step.

When an artifact is skipped, phase advances to the next non-skipped artifact, or to `implement` if all remaining are skipped.

### `status` (per-artifact in pipeline)

| Value | Meaning |
|-------|---------|
| `pending` | Not yet created |
| `done` | Created successfully |
| `skipped` | User chose to skip this optional artifact |

**`gherkin` can NEVER be `skipped`** — it is the only mandatory artifact.

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

1. **Always use inline YAML flow style** for pipeline entries: `{ status: done }`, not multi-line
2. **Never add extra fields** to pipeline entries — only `status`
3. **Never add extra entries** to pipeline — only the four listed
4. **Phase must match reality** — set to the latest completed artifact name, or `implement`/`verify`/`sync`/`archive` for later stages
5. **Read before write** — always read the current status.yaml before updating to preserve existing fields (like `source`)
