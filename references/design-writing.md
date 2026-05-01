# Design Writing Conventions

Reference for writing `design.md` as living documentation. Used by `design` and `distill` skills when creating designs.

## Two Readers

Design serves two readers:
- **Design phase reviewer** — needs to evaluate technical correctness + alternatives considered
- **Future implementer / maintainer** — needs to understand why decisions were made when revisiting

Both benefit from explicit separation between Approach (overview / strategy), Key Decisions (the load-bearing bits), and Components (concrete artifacts).

## Sections

### Minimum (all designs)

1. **Approach** — 1-3 paragraphs, high-level: what's the strategy?
2. **Key Decisions** — load-bearing decisions, each with failure mode + mitigation
3. **Components** — concrete files / modules / interfaces affected

### Recommended additions (scale to complexity)

| Section | When to include | What to write |
|---------|----------------|---------------|
| Approach diagram | Multi-component / non-trivial control flow | ASCII flow showing data movement and decision points |
| Decisions Index | When `## Key Decisions` has 4+ entries | Mini-table at section top: `\| # \| Title \|`、reader 不用 scroll 解碼 |
| Alternatives Considered | Multiple plausible designs explored | Table: chosen / rejected / reverted with reasoning |
| Safety & Correctness | Decisions with subtle failure modes | 3-5 load-bearing decisions, each with failure mode + mitigation |
| Risk Registry | Cross-cutting risks | Table: risk / description / mitigation |
| Acceptance Criteria | Production rollout / observability concerns | Logging schema, metrics, thresholds |

Don't write all of these — pick what the change requires. A typo fix design doesn't need Acceptance Criteria.

## Approach section — pattern

The Approach section sets the high-level strategy. Use ASCII diagrams when control flow or data movement is non-obvious:

```
舊路徑：silent failure
  ├── for in range(max_steps):
  └── return text=""
        ↓
  state=completed + parts=[]   ← failure swallowed

新路徑：LLM-decides
  ├── normal phase
  ├── boundary handling
  └── extension dispatch
        ↓
  state=completed (LLM wrap-up) | failed (fallback)
```

Approach should be **reader-self-contained** — someone landing on Approach without reading proposal should understand the strategy.

## Key Decisions section — pattern

### Numbering decisions

Numbering decisions (`D1`, `D2`, etc.) is fine as internal shorthand. When ≥ 4 entries, add a **Decisions Index mini-table** at the top so readers can decode references without scrolling:

```markdown
## Key Decisions

> Index — full discussion below

| # | Decision |
|---|----------|
| D1 | <short title> |
| D2 | <short title> |
| D3 | <short title> |

### D1: <title>
<full discussion>
```

### Decision content — pattern

Each load-bearing decision should answer:

1. **What we chose** — concise statement
2. **Failure mode** — what happens if we got it wrong? Silent or loud?
3. **Mitigation** — how we ensure correctness (test / regression / cross-check / grep call sites)

```markdown
### D1: 用 dataclass field 不用 exception 傳訊號

選擇 dataclass field、不 raise exception。

**Failure mode**: 用 exception 表達 boundary 會跟既有 try/except Exception 把 tool error 統一吃成 {"error": ...} 的 catch 路徑撞、需要型別判斷分流。

**Mitigation**:
- happy / boundary / fallback 都走同一個 ToolLoopResult 結構、差別在欄位
- Unit test 釘住三條路徑欄位值正確
```

### How many decisions?

Rule of thumb:
- **3-5** load-bearing decisions for typical features
- **5-10** for framework-level changes
- **> 10** is a smell — decisions getting too granular, or "decision" being used to document everything

If you're tempted to write 13 Key Decisions, pause and ask: **"Are all of these load-bearing? Or am I documenting all my thinking under one heading?"** Move non-load-bearing items to Components or Implementation Notes.

## Components section — pattern

```markdown
## Components

### `path/to/file.py`

<concrete change: signature, schema, contract>
```

Include:
- File / module name as section heading (grep-friendly)
- Concrete change: schema diff, signature, contract
- **NOT**: prose explanation that belongs in Approach or Key Decisions

If you find yourself writing paragraphs in Components, it usually belongs in Approach or as a Key Decision.

## Cross-doc reference rule

When MR descriptions, commit messages, or external comms cite design.md:
- Don't write `D1` / `D6` without inline plain-noun translation: write `D6 (Extension hard cap)` not just `D6`
- See `skills/design/SKILL.md` Guardrails for the full rule

## External reader test

Before committing design.md, run this self-check:

> Read your own design.md as if you've never seen this conversation. After 5 minutes, can you state:
> - Problem (1 sentence)
> - Approach (1 sentence)
> - 2-3 most important decisions

If no, the document needs Goal section in proposal.md (not design.md), or the Approach diagram is missing.

## Review Checklist

1. [ ] Approach 段 self-contained (reader 不需先讀 proposal 就能理解 strategy)
2. [ ] Approach diagram 存在 (multi-component / non-trivial control flow)
3. [ ] Key Decisions 有 Decisions Index (4+ entries)
4. [ ] 每個 decision 有 Failure mode + Mitigation
5. [ ] Decisions 數量 ≤ 10、超過反映 "everything is a decision" smell
6. [ ] Alternatives Considered 段存在 (有 reject / revert 的選項)
7. [ ] Components 段是 concrete change、不是 prose 重複 Approach
8. [ ] External reader test 通過
