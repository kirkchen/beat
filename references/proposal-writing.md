# Proposal Writing Conventions

Reference for writing `proposal.md` as living documentation. Used by `design` and `distill` skills when creating proposals.

## Two Readers

Proposals serve two readers simultaneously:
- **Reviewer / approver** — needs Goal-first onboarding to evaluate "merge 後成功是什麼" within 30 seconds
- **Future maintainer** — needs Why context preserved to understand the motivation when revisiting in 6 months

Both benefit from explicit separation between Goal (success definition) and Why (problem framing).

## Sections

### Minimum (all proposals)

1. **Goal** — 1 sentence + 3-5 outcomes. Outcome voice, not problem voice.
2. **Why** — 2-3 paragraphs. What gets worse if we don't do this.
3. **What Changes** — concrete in / out / explicitly-out scope.
4. **Impact** — affected systems, behavior changes, what stays unchanged.

### Goal vs Why — they answer different questions

| Section | Question | Voice | Reader cognitive function |
|---------|----------|-------|---------------------------|
| Goal | "What does the system get when this merges?" | Outcome / future-state | "Is this the right success criterion to align on?" |
| Why | "What gets worse if we don't do this?" | Pain / current-state | "Should we even do this?" |

These often get fused into a single Why section. The result: neither is clear. Goal becomes a wishlist; Why becomes a vague justification.

## Goal section — pattern

```markdown
## Goal

<1 sentence: merge 後系統得到什麼能力 / 痛點消除什麼，「結果」語氣，不是改動清單>

具體 outcomes：
- <outcome 1 — user / operator / developer 角度的可觀察行為>
- <outcome 2>
- <outcome 3>
```

**Good** (outcome voice, observable behavior):
> Merge 後 ops agent 撞 max_steps 時不再 silent failure、撞牆事件對下游變顯式可觀測訊號。
>
> 具體 outcomes：
> - LLM 撞 max_steps 時、回 `state=failed` 而非 silent `state=completed + parts=[]`
> - SRE 端透過 `tool_loop_boundary` log 觀察 boundary trigger rate
> - 跨 agent 自動繼承、無需個別配置

**Bad** (mixes Why into Goal):
> 因為 ops agent 撞 max_steps 會 silent failure、所以我們要修這個 bug、避免下游 caller 拿到誤導訊息。

Problems: no outcome voice、stealing Why content。

## Why section — pattern

```markdown
## Why

<2-3 paragraphs: 現況痛點、「不做會繼續壞下去什麼」>

<Optional: unattractive options 或持續不處理的二次傷害>
```

**Good** (current-state pain narrative):
> 函調流程實測 13~16 步、已在 max_steps=15 邊緣。任何 prompt 寫壞 / tool 永遠回模糊結果 / 流程肥的場景都會踩同一個 boundary 盲點。framework 沒留下可觀察的失敗 marker、排查只能翻 log。
>
> 不修的二次傷害：
> - log retention 有限、事後追查永遠慢
> - 未來新流程都會踩同一坑

**Bad** (turns into outcome list):
> 我們要修 silent failure、加 max_steps_reached flag、配上 framework safety net 走 _fail_task 路徑。

Problems: change list instead of pain narrative、stealing Goal / What Changes content。

## What Changes — pattern

Three parallel lists:

```markdown
## What Changes

### In scope
- <每項具體要做的、~4-8 項>

### Out of scope
- <明示不碰的、降低 reviewer 心智負擔>

### Explicitly out of scope
- <主動拒絕做的、附理由>
```

**Distinction**: "Out of scope" = 自然不碰（reviewer 一看就懂）；"Explicitly out of scope" = 主動考慮後拒絕（更有 review value、避免 reviewer 重複問為什麼不做 X）。

## Impact — pattern

```markdown
## Impact

### 行為變更（user-visible）
| 情境 | 修前 | 修後 |
|---|---|---|

### 受影響系統
- <system / agent / module>: <什麼變化>

### 不變
- <明示哪些 invariant 仍然成立>

### 風險
| 風險 | 描述 | Mitigation |
|---|---|---|
```

**「不變」段反而最重要** — reviewer 看到這段會放心；缺了會懷疑「是不是有東西沒列」。

## Scaling — small change vs large change

Not every proposal needs all sections at full depth:

| Change scale | Goal | Why | What Changes | Impact |
|--------------|------|-----|--------------|--------|
| Typo / config tweak | 1 sentence | 1 sentence | 1 line | omit |
| Bug fix | 1 sentence + 2 outcomes | 1 paragraph | concrete in/out | 行為變更 + 不變 |
| Feature | 1 sentence + 3-5 outcomes | 2-3 paragraphs | full 三列 | full 4 sub-sections |
| Framework / architecture | 1 sentence + 5 outcomes | full 痛點 + 二次傷害 | full + Closes/Related | full + 風險表 |

Pre-empt the「我這 change 小、要不要寫 proposal」question by scaling sections, not by skipping the proposal.

## Review Checklist

1. [ ] Goal 段 1 sentence 用 outcome 語氣 (不是 problem 語氣)
2. [ ] Goal outcomes 是 user / operator / developer 角度的可觀察行為 (不是改動清單)
3. [ ] Why 段不混入 outcome 敘述
4. [ ] Why 段有「不做的二次傷害」or unattractive options
5. [ ] What Changes 三列分明 (動 / 不動 / 主動拒絕做)
6. [ ] Impact 有「不變」段、明示 invariant
7. [ ] 沒參與設計討論的 reader 讀 Goal 段能複述「merge 後成功是什麼」
8. [ ] Section depth 跟 change 規模對齊 (小 change 不堆 sections)

## Cross-doc reference

When MR descriptions, commit messages, or external comms cite the proposal:
- Quote Goal sentence directly (not paraphrase)
- See `skills/design/SKILL.md` Cross-doc reference rule for codename translation
