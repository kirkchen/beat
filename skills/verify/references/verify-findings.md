# verify.md Format

`/beat:verify` writes its findings to `beat/changes/<name>/verify.md` so that `/beat:apply fix-from-verify` can read them back without a human copying them into a prompt. The file has a YAML front matter that skills parse, followed by the human-readable report.

## Front matter

```yaml
---
change: <name>
date: YYYY-MM-DD
sha: <git rev-parse --short HEAD at verify time>
mode: full | incremental
round: 1                                          # 1 on the first run, +1 per re-run; governs the iteration ramp
base: <sha the incremental diff started from>   # incremental only
findings:
  - { id: F1, severity: CRITICAL, dimension: 1B, scenario: "Monthly billing adjusts for short months", file: "src/billing/schedule.ts:42", fix: "Add a test for the February case and clamp to month end", status: open }
  - { id: F2, severity: WARNING, dimension: 1C, scenario: "", file: "src/billing/__tests__/schedule.test.ts", fix: "Assert on the returned date, not on toHaveBeenCalledWith", status: open }
---
```

| Field | Values |
|-------|--------|
| `id` | `F<n>`, stable across runs: a finding that is still open keeps its id; new findings continue the numbering |
| `severity` | `CRITICAL`, `WARNING`, `SUGGESTION` (same vocabulary as the verify report) |
| `dimension` | `1A`, `1B`, `1C`, `2`, `3`, `4`, `5A`, `5B`, `5C` |
| `scenario` | exact scenario name, or empty when the finding is not scenario-bound |
| `file` | `path:line` where the fix goes, or the file when no line applies |
| `fix` | one sentence of direction, not a patch |
| `status` | `open`, `fixed`, `wontfix` — verify writes `open`; apply writes `fixed`; a human writes `wontfix` with a reason appended to the line |

Every finding is one inline-flow line. The validator (`scripts/validate-beat.mjs`) rejects multi-line entries and unknown fields.

## Body

After the front matter, the combined report exactly as `/beat:verify` presents it (summary table, findings by severity, testing context, final assessment). The body is for people; skills read only the front matter.

## Who reads and writes

- **verify** writes the whole file on every run. On an incremental run it carries forward findings still `open` from the previous file, re-checks them, and marks any it can no longer reproduce as `fixed`.
- **apply** (`fix-from-verify`) reads findings with `status: open`, treats each as a task in severity order, and rewrites `status: fixed` on the ones it addressed. It never deletes findings.
- **archive** reads the counts via `status.yaml`; it does not parse this file.

## Incremental runs

An incremental run verifies `base..HEAD` plus every scenario and artifact section the diff touches, then runs the full automated checks (tests, lint, scenario-to-test map). It does not re-read untouched artifacts. If `base` is not an ancestor of `HEAD` (rebased, amended), verify falls back to `full`. A full re-run after fixes is the user's choice; archive does not require one.

## Convergence

The verify ⇄ apply loop ends on a severity floor, not on an empty list: zero open CRITICAL means converged, and the open WARNING / SUGGESTION ids ride along in the handoff block for the user to pick from. Three more rules bound the loop — prose findings are capped at SUGGESTION, round 2 records no new SUGGESTIONs and round 3+ no new WARNINGs (`round` in the front matter), and round 4 is never recommended. `skills/verify/SKILL.md` "Convergence" has the full table; `/beat:apply fix-from-verify` fixes CRITICAL by default and takes explicit ids for anything else.
