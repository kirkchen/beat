# Proposal: 無人值守的 change flow，人只在 explore 與 merge 出現

日期：2026-11-04
狀態：draft v4。v3 經兩輪獨立 review（設計對抗、六情境模擬）修訂，差異集中在 §8；v2 經一輪 builder check 修訂（gate question 來源、stage-result 值的文法、Stage session 模型、archive 停點對應、babysit 已有機器行）；v3 加 §7 票的入口、狀態字彙、tracker 設定與規模
範圍：Beat、cadence、rhythm 三個 repo 的 skill 與 flow 設定；搭配 mattpocock/skills（HEAD 4ae2317）
前置：`beat-topology.md`（explore 出口、preset、fix-from-verify 迴圈）已落地，本文建立在它之上
來源：本文的事實來自三份 recon：rhythm 的 Task Flow 與 label 協定（ADR-0077、ADR-0087、`packages/domain/src/flows/`）、Beat 與 cadence 每個 skill 的機器可讀輸出與停點、Claude Code 對 user-invoked skill 在 headless 模式的行為（`code.claude.com/docs/en/skills.md`、`headless.md`）

## Why

現在從 issue 到 merge 的路上，人要出現四次：explore、看 `rhythm-plan` 產出的 draft PR、打 `rhythm-implement`、review PR。中間兩次大多數時候只是「看完然後打下一個 label」，但每次都要切 context、讀 design.md 與 tasks.md。

階段本身不是問題。分這麼多階段，是為了讓 Rhythm 的 Flow 加 evaluator 在每個邊界做判斷，降低人要判斷的地方。問題在 gate 是無條件的：#454 草稿裡 design 之後、plan 之後各一個 `input_required`，不管這個 change 有沒有東西要人決定。

第一性原理的版本：

1. **人在前面對齊「使用者會感受到的改變」，在後面決定 merge。** 中間交給流程。
2. **中間只在「重要決定」停。** 重要的判準跟 ADR 三條件同源（難以反轉、沒脈絡會意外、真實取捨），加上 repo 自己標的敏感區域（錢、權限、核心資料路徑）。
3. **停下來的時候，人讀的是一份 brief，不是 artifact。** 幾十秒內看懂要決定什麼、選項、各自後果、agent 傾向。
4. **每個 Stage 的出口是機器可讀的訊號，不是人眼。** 預設用 Rhythm 已有的 `run_output` judge（免 LLM），LLM evaluator 只留給訊號不夠的地方。

## 現況可以直接用的

| 已存在 | 在哪 | 本文怎麼用 |
|---|---|---|
| Flow / Stage / judge / gate / loop / budget / maxRuns | rhythm `packages/domain/src/flows/types.ts`、`advance.ts`、ADR-0077 | 整條 change flow 是一個 FlowDefinition |
| `run_output` judge：nonce 綁定的 `rhythm-stage-result[nonce]: k=v` 最後一行 | rhythm `flows/stage-result.ts`；Beat `references/handoff-report.md:27-35` 已會輸出 | 每個 Beat phase 的 judge |
| `input_required` gate → `flow_gate` outbox → Task UI（Slack 送達已有、收回覆沒有） | rhythm `packages/slack-bot/src/flow-gate-delivery.ts` | 「重要決定」的停點；本文把 surface 抽象化、issue 當第一個（§1） |
| PR_REVIEW_FLOW：`/pr-review` ↔ `/cadence:pr-babysit`，loop 3 | rhythm `flows/builtins.ts` | archive 之後接上，不重做 |
| `beat-supervise` 的 critic-actor loop 用 `cadence:pr-review mode=local` | rhythm `.claude/skills/beat-supervise/` | verify 階段的 code review evaluator，照用 |
| Beat `preset` / `preset_upgrade`、verify 的收斂規則（severity floor、iteration ramp、round cap、divergence） | Beat `references/status-schema.md`、`skills/verify/SKILL.md` Convergence | 已經是 evaluator，只差把結果放進 stage-result |
| user-invoked skill 可以用 prompt 開頭的 `/skill` 在 headless 跑，一個 prompt 一個 skill | Claude Code docs | Rhythm 的 Stage prompt 可以直接是 `/beat:design …` 或 `/retro`，一個 Stage 一個 skill |
| `/to-issue` 把 explore 結論寫成 issue body（已定案 / 先不做） | rhythm `.claude/skills/to-issue/` | explore 的出口；加兩個段落（§3.1） |

## What Changes

### 1. Flow：`beat-change`，一個 Dispatch Label

取代 #454 草稿的 gate 位置。`rhythm-plan` / `rhythm-implement` 合併成一個 `rhythm-change`；敏感與否由訊號決定，不靠兩個 label。

```
rhythm-change
  │
  ▼  BEAT_CHANGE_FLOW（一個 Task）                                                PR_REVIEW_FLOW（PR 事件另開的 Task）
design ──► plan ──► apply ──► verify ◄──► fix (loop ≤3) ──► archive+PR ──complete──► pr-review ◄──► fix ──► babysit ──► ready（人 merge）
   │          │        │         │                              status/in-review
   └──────────┴────────┴─────────┴── gate（issue 留言 + status/waiting）：decision / env / scope 回覆後接續同 phase；
                       │                                        plan 之後 sensitive=yes 回覆後跳 apply；verify diverging=yes 回覆後跳 fix
```

每個 Stage 的 judge 都是 `run_output`。stage-result 的值一律是不含空白的 token（`stage-result.ts:28` 以空白切割；`matchOutcome` 只做等值與 enum 比對，沒有前綴與否定），所以 `blocked-on` 收斂成三個值，decision id 另一個 key。規則依序 first-match：

| 順序 | stage-result | 下一步 |
|---|---|---|
| 1 | `diverging=yes`（只有 verify） | `gate:input_required` |
| 2 | `blocked-on=decision` | `gate:input_required`；`decision=D<n>` 指向 brief |
| 3 | `blocked-on=env`（e2e 環境、工具失敗、archive 的衝突） | `gate:input_required` |
| 4 | plan 之後 `sensitive=yes` | 一次 `gate:input_required` |
| 5 | verify `critical>0` | `fix` Stage（`/beat:apply <name> fix-from-verify`），loop maxIterations 3 |
| 6 | `blocked-on=none` | 下一個 Stage |
| — | `rhythm-stage-result` 缺或格式錯 | 既有的 `judge_unreadable` gate |

diverging 排在 critical 前面，否則會先進 fix loop、永遠到不了 gate。

**Gate 的 question 從哪來。** 現在 `run_output` 進 gate 不帶 question（`advance.ts:315-320` 呼叫 `gate(s, then.gate)`，`OutcomeThen` 只有 `{ gate: 'input_required' }`），只有 evaluator 路徑帶 `v.question`。本文要求一個小的 domain 改動：`OutcomeThen` 加 `{ gate: 'input_required', question: 'last_message' }`，Orchestrator 把該 Run 最後一則 agent 訊息當 question（Rhythm 已經用同樣方式從最後一則訊息抽 PR URL）。Beat 的 unattended 規則配合：有 brief 時，brief 全文印在 handoff block 正前方，所以最後一則訊息就是「brief + handoff」。不走 evaluator judge，維持免 LLM。

**Session 與 worktree。** 一個 issue 一個 Task，Task 的 PVC 跨 Run 共用（ADR-0004），所以 worktree 與 branch 跨 Stage 不變；每個 Stage `session: 'new'`（#603 已落地），Stage 之間只靠 `beat/changes/<name>/` 與 git 銜接。這正是 status.yaml 的設計目的，也等於 Matt 的「每張 ticket 乾淨 context」。apply 的 subagent-driven 在 ACP worker 內跑過（beat-supervise 現狀），headless 不是新問題。

**Gate 介面可以多個，issue 是第一個。** Gate 是 Rhythm 的概念：一個 question 出去、一個 reply 回來。任何能送 question、收 reply 的管道都是一個 gate surface；現在真正能用的只有 Task UI（`flow_gate` outbox 有 Slack 送達，但收回覆沒有，而且目前的部署沒接 Slack）。三條規則：

- **System of record 是 issue。** 不管從哪個 surface 回覆，結論都寫回 issue（留言，與「已定案」段），因為規格在那裡，之後查得到為什麼。
- **先回的算數。** 多個 surface 同時收到同一個 question，第一個 reply 關掉 gate，其他 surface 看到「已由 X 回覆」。
- **GitHub issue 是第一個要做的 surface**，因為你的流程在那：(a) 進 gate 時寫回 issue 一則留言（內容是 question），掛狀態 label `rhythm-waiting`（`rhythm-blocked` 的語意是「出狀況」，不混用）；(b) webhook 加訂 `issue_comment`，sender 是 Approver 且 issue 上有 `rhythm-waiting` 就視為 gate reply，留言全文當 `userMessage`。(b) 是 #453 的一半（Installation 事件變成 gate reply）。Slack 作為第二個 surface 後做：送達已有，補收回覆與寫回 issue。

**Gate 回覆**走既有的 gate reply（Continuation Run，`prompt_kind='manual'`）。回覆文字已經以 `userMessage` 進 `enterStage`（`advance.ts:345`），本文的 `{{gate_reply}}` 就是它，不是第二個注入點；Stage 重跑同一個 phase。

Flow 加 `maxRuns` 與 `budgetUsd`（#519 的教訓）。

### 2. Beat：無人值守規則與三個訊號

**2.1 Unattended 規則（跨所有 phase）。** 當環境有 Rhythm 的 nonce（既有的 `rhythm-stage-result` 觸發條件），每個會 AskUserQuestion 的點改成：

- 有預設答案（preset 已設、review 角色用建議、capability 有明顯對應、glossary 新詞照建議寫）→ 採預設，追加一行到 `beat/changes/<name>/decisions/assumed.md`（append-only，跨 Stage 持久；不動 status.yaml schema）。
- 沒有預設、而且符合 ADR 三條件或碰到敏感路徑 → 寫一份 decision brief（§2.3），handoff `blocked-on: decision`、stage-result `decision=D<n>`。
- 其他（e2e 環境擋住、工具失敗、archive 無法自動解的衝突）→ handoff `blocked-on: <一句話>`，stage-result `blocked-on=env`。

archive 的停點逐一對應：

| archive 現在會問 | unattended |
|---|---|
| artifact 不完整、tasks 沒勾完 | flow 不會走到這（apply 與 verify 在前） |
| `verification` 缺或 `issues-found` | 同上；`passed` 本來就只是一行資訊 |
| capability 對應 | 有明顯對應採預設並記 assumed，否則 `env` |
| glossary 新詞 | 照建議寫，記 assumed |
| design.md 合併衝突 | `env` |
| ADR 最後一哩 sweep | offer-only，跳過 |
| route 全部完成要不要 archive route | 採預設 archive，記 assumed |

`beat-supervise` 現在「替人回答 AskUserQuestion」的那一段保留：帶 nonce 的 flow Stage 裡 Beat 不會問，這段不觸發；Rhythm UI 手動建的 supervised Task（`SUPERVISED_FLOW`，prompt 不帶 nonce）Beat 照常發問，仍靠它回答。

**2.2 Issue body 是鎖定的決策來源。** design 讀 issue 的「已定案（不要重新討論）」當 locked decisions，不重開；design 自己產生的 Key Decision 若不在已定案內且過 ADR 三條件 → decision brief。這是現在 `tpl-github-rhythm-plan` prompt 裡的規則，搬進 `/beat:design` 本體，讓本機跑也一致。

**2.3 Decision brief 格式**（新 `references/decision-brief.md`，檔案在 `beat/changes/<name>/decisions/D<n>.md`）：

```
# D1: <一句話的問題>
來源：design Key Decision 3 / apply Task 4 / verify F7
影響：<改了會動到什麼，一兩句>
選項：
  A. <選項> — 後果：<一句>
  B. <選項> — 後果：<一句>
傾向：A，因為 <一句>
擋住：<沒有答案就不能做的事>
```

上限十行。Gate 的 question 就是這份檔案的內容，issue 留言一眼看得完。人在 issue 上留言回覆後，agent 把結論寫回 issue 的 `## 已定案` 段與 design.md，過 ADR 三條件的寫 ADR。

**2.4 Stage-result 新增 key**，寫進 `references/handoff-report.md`，`validate-beat.mjs --handoff` 驗證。現在的可選機器行只有 `phase sha critical warning next`（`blocked-on` 只在 handoff block 的 prose 行），本文加四個 key，值不含空白：

```
rhythm-stage-result[<nonce>]: phase=<p> sha=<sha> blocked-on=<none|decision|env> decision=<D<n>|none> sensitive=<yes|no> critical=<n> warning=<n> diverging=<yes|no> next=<cmd>
```

- `sensitive`：來源是 `beat/config.yaml` 新欄位 `sensitive:`，兩個子欄位。`situations:` 是一行一條的情境描述（例：「改到費用計算或任何會變成帳單數字的邏輯」「改到誰可以派工或代表別人執行的判定」「改到對外契約：label 語意、webhook payload、stage-result 格式」），design 在寫 Key Decisions 時逐條對照、apply 在 diff 完再對照一次，判斷方式與 ADR 三條件同一個機制（agent 語意判斷，rationalization table 擋「這應該不算」），只是條件來自 repo。`paths:` 是可選的 glob 清單，碰到就一定 yes、不經判斷，留給「不管改什麼都要看」的少數檔案。以情境為主、路徑為輔，因為錯誤代價不對稱：漏判還有 PR 這關，誤判只多讀一份十行 brief，所以判準寬鬆即可。plan 之後 flow 只看 design 的值 gate 一次；apply 才發現碰到的（plan 沒預測到）不再 gate，寫進 PR 的「決定與影響」讓人在 merge 前看。架構層的敏感由 ADR 三條件經 `blocked-on=decision` 表達，不另設欄位。`situations` 也是 retro 的落點：該停沒停的 change，retro 的輸出就是加一行。
- `diverging`：verify 的 divergence 規則已經有定義（`skills/verify/SKILL.md:237`），現在由 dispatcher 以 prose 判定；改成同時寫這個欄位，並進 verify 最後一行的契約與 validator。
- `decision`：change 內遞增、不重用，重跑同一 phase 不會撞號。
- explore 不在 flow 裡（它是人做的），`exit` 不進 stage-result。

Rhythm 端沿用 PR_REVIEW_FLOW 的做法（`builtins.ts` 的 `REVIEW_TAIL` / `BABYSIT_TAIL`）：Stage prompt 尾端重述這一行的格式，Beat 的 handoff 規則與 TAIL 說的是同一件事，validator 驗 Beat 這邊。

**2.5 archive Stage 開 PR，PR body 有「決定與影響」段。** archive 之後 Beat 現在交給 `superpowers:finishing-a-development-branch`；在 unattended 模式下改成直接 push 並開 ready PR（不是 draft），body 由 mattpocock 的 `pr` skill（model-invoked，可直接叫）整形，加一段固定標題：

```
## 決定與影響
- 已定案（來自 issue）：<列>
- 這次做的決定：<design Key Decisions + ADR 連結 + D<n> brief 的結論>
- assumed（採預設、沒問人）：<列>
- 沒處理的 verify WARNING：<列 id 與一句>
- preset 升級：<有的話一行>
```

這段是人在 merge 前唯一要讀的東西。`assumed` 與 `D<n>` 的結論從 `decisions/` 目錄讀，不依賴前一個 Stage 的 session。Stage 輸出 `subject=<PR url>` 給 #453 的 subject rebind；#453 沒落地前，PR 開出來的 `pull_request` 事件會觸發既有的 PR Review Trigger，PR_REVIEW_FLOW 以獨立 Task 接手（現狀可行，不用額外建 Task）。

**2.6 explore 不變，但 `/to-issue` 加兩段。** 借 mattpocock `to-spec` 的兩個段落：`## User stories`（design 寫 gherkin 的直接素材，也是「使用者會感受到的改變」的對齊物）、`## 測試 seam`（選最高的一層，對應 Beat 的 `@e2e` / `@behavior`）。explore 中如果需要 grilling，叫 model-invoked 的 `grilling` + `domain-modeling`，不再寫「offer to invoke `grill-with-docs`」（它是 user-invoked，模型叫不到）。

### 3. cadence：兩個小改

**3.1 pr-review 讀 repo 的 coding standards。** 現在四個 role prompt 不讀任何 standards 檔。借 mattpocock `code-review/SKILL.md:36` 的做法：先找「repo 裡所有描述怎麼寫 code 的檔」（`CODING_STANDARDS.md`、`CONTRIBUTING.md`、各 module README 的 conventions 段），交給 staff-engineer 與 sdet 角色 enforce。這是 retro（§4）產出的消費端；沒有它 retro 寫的規則沒人讀。

**3.2 pr-babysit 不用改。** rhythm `builtins.ts` 的 `BABYSIT_TAIL` 已經在 Stage prompt 尾端要求 `status=<ready-to-merge|needs-user-input|blocked>` 的機器行，PR_REVIEW_FLOW 照用。

### 4. mattpocock/skills 的位置

| Matt 的 skill | 放哪 | 怎麼叫 |
|---|---|---|
| `grilling`、`domain-modeling` | explore 內部 | model-invoked，Beat explore 直接叫 |
| `research`、`prototype` | explore 的 blocked exit | 已接 |
| `pr` | archive Stage 的 PR body | model-invoked，直接叫 |
| `/retro` | merge 之後一個 Stage（§5） | user-invoked，Stage prompt 以 `/retro` 開頭 |
| `writing-for-agents` | 改 skill 時 | 已在用 |
| `to-spec`、`to-tickets`、`implement`、`implement-spec`、`code-review`、`triage`、`wayfinder`、`handoff` | 不用 | Beat / cadence / routes / status.yaml 各自覆蓋 |

原則不變：Beat 呼叫、取回結果，不交出狀態。

### 5. Retro Stage（第二階段，可後做）

PR merged 事件 wake 一個 Stage，prompt `/retro`，指向該 Task 的 session log；輸出是一份 PR（lint rule、hook、`beat/config.yaml` rules、README conventions），走 `maintenance-routine` 一樣的「沒東西就不開 PR」規則。這是 Matt 流程閉環的那一段，Beat 與 cadence 現在都沒有。

### 6. Rhythm 要動的

| 項目 | 依賴 | 大小 |
|---|---|---|
| `OutcomeThen` 加 `question: 'last_message'`，Orchestrator 進 gate 時帶該 Run 最後一則 agent 訊息 | 無 | `flows/types.ts`、`advance.ts`、`orchestrate-flow.ts` 各幾行 |
| `BEAT_CHANGE_FLOW` builtin（§1 的 Stage、judge 規則、loop、budget、各 Stage 的 TAIL） | 上一項；取代 #454 草稿 | 一個 builtin |
| Gate surface 抽象：question 出、reply 進、結論寫回 issue、先回的算數 | 無 | orchestration 一層介面 |
| 第一個 surface，GitHub issue：gate 時留言 + 掛 `rhythm-waiting`；訂 `issue_comment`，Approver 留言即 reply | #453 的一半 | write-back 加一個時機、webhook 路由 + policy 檢查 |
| 第二個 surface，Slack：補收回覆與寫回 issue | 上兩項；後做 | slack-bot |
| `rhythm-change` 單一 Dispatch Label 的 Trigger / Template（prod DB） | 無 | SQL |
| subject rebind issue → PR（#453） | 既有 issue | 讓 pr-review loop 留在同一個 Task；沒有也能跑 |
| Supervised flow 加 maxRuns / budget（#519） | 既有 issue | 小 |

## 模擬：三張 issue 走一遍

人出現的次數與讀的東西，是這份 proposal 的驗收標準。

### A. 小 UI 改動：Task 列表顯示 archived 徽章

| 步驟 | 發生什麼 | 人 |
|---|---|---|
| explore | 本機 `/beat:explore`，user story 一句話對齊，出口 `small` | 互動 |
| to-issue | body：已定案（徽章文案、位置）、user story、seam=`@behavior` | 看一眼、打 `rhythm-change` |
| design | preset minimal（explore 已設，不問），2 個 scenario，無 Key Decision，`sensitive=no` | — |
| plan | 只跑 test-coverage 角色，`blocked-on=none` | — |
| apply | 2 個檔案，preset_upgrade 沒超 | — |
| verify | `critical=0 warning=1 diverging=no` | — |
| archive+PR | PR body「決定與影響」5 行：無決定、1 個 WARNING 沒處理 | — |
| pr-review | PASSED_WITH_NOTES | — |
| babysit | `ready-to-merge` | merge |

人出現 2 次，中間 0 個 gate，merge 前讀的東西約 10 行加 diff。現狀是 4 次。

### B. 碰錢：budget gate 的 USD 四捨五入規則

| 步驟 | 發生什麼 | 人 |
|---|---|---|
| explore | 出口 `standard`；已定案寫了「向上取整到 cent、costUnknown 時不觸發」 | 互動 |
| to-issue | 打 `rhythm-change` | — |
| design | 對到 `sensitive.situations` 的「費用計算」那條（也在 `paths` 裡） → `sensitive=yes`；Key Decision 都在已定案內，`blocked-on=none` | — |
| plan | 多角色 review；結束後 flow 看到 `sensitive=yes` → **gate 一次**，plan brief 留言到 issue（design 3 個決策、5 個 task 各一行） | 在 issue 上讀 brief（約 10 行），留言「continue」 |
| apply | — | — |
| verify | `critical=1`（一個 scenario 沒測試）→ fix loop 1 輪 → `critical=0` | — |
| archive+PR | 「決定與影響」列出 sensitive 路徑與 3 個決策 | — |
| pr-review | P1：精度邊界 → fix loop 1 輪 → PASSED | — |
| babysit | `ready-to-merge` | merge |

人出現 3 次，1 個 gate。現狀同樣是 draft PR 那一關，但讀的是 brief 不是整份 design.md。

### C. 架構：evaluator 的 model 綁到 credential 而不是 backend（ADR 等級）

| 步驟 | 發生什麼 | 人 |
|---|---|---|
| explore | 出口 `standard`；已定案只寫了「要能 pin model」，沒定綁在哪一層 | 互動 |
| design | Key Decision「綁 credential 還是 backend」不在已定案、過 ADR 三條件 → 寫 `decisions/D1.md`，`blocked-on=decision decision=D1` → **gate**，brief 留言到 issue（有接的 surface 同時收到） | 在 issue 上讀 D1 brief（10 行：問題、A/B 後果、傾向 A），留言「A」 |
| design（重跑） | `{{gate_reply}}` 注入，寫回已定案、寫 ADR-00xx，`blocked-on=none` | — |
| plan → apply → verify → archive+PR → review → babysit | 同 B，沒對到任何 sensitive 情境 | merge |

人出現 3 次，1 個 gate。如果 explore 時就把這個決定談掉寫進已定案，是 2 次 0 gate。這就是「需要人判斷的部分集中在 explore」的具體化：explore 談得越完整，中間越安靜。

### D. 失敗路徑

- worker 非正常結束（eviction、deadline）→ 既有 `run_failed` gate，人按 continue（#518）。
- verify 第 3 輪 `diverging=yes` → gate，question 是 divergence 說明與最後一次 fix commit；人決定回退或繼續。
- pr-review 出 Q（spec gap）→ `awaiting_decision` → 既有 PR_REVIEW_FLOW 的 gate。
- budget / maxRuns → 既有 gate。

## 7. 票的入口、狀態、tracker 設定、規模（v3 定案）

前面的章節假設 issue 已經存在而且寫好了。這一節定義票從哪裡來、狀態怎麼表示、多 tracker 怎麼設定、以及 spec 與 ticket 兩種規模怎麼對應。

### 7.1 入口只有 explore

triage 回答的問題是「這張票現在能不能交給 agent」，答案需要看懂它、該定的決定定了、大小切對，這三樣就是 explore + `/to-issue` 的產出。cadence 的 `triage-issue`（貼 type / priority、留 comment）與 `investigate-issue`（驗證 body 的 file:line、確認根因）不回答這個問題，前者是簿記、後者是 explore 開頭本來就做的事。兩個都退役，cadence 回到它原本的範圍「PR lifecycle」（`self-review`、`pr-review`、`pr-babysit`、`maintenance-routine`）。

任何票（自己開的、別人開的、bug、feature）走同一條：

```
/beat:explore #n ─┬─ small / standard ─► /to-issue 寫 body、標 status/ready ─► 人加 rhythm-change
                  ├─ blocked ─► research / prototype / decision node，不標
                  ├─ too-big ─► epic + sub-issues（§7.4），各 node 自己再 explore
                  └─ 不做 ─► close，留一句原因
```

explore 多一個出口動作「不做」：close 並留原因；現有四個出口沒有這個。bug 也走這條，explore 讀 code 確認真假與位置，apply 裡 superpowers 的 `systematic-debugging` 接手；mattpocock 的 `diagnosing-bugs` 是本機自己修難纏 bug 用的，與 Rhythm 流程平行。

### 7.2 狀態：一個 `status/*` 維度，互斥，沒有人工簿記

| 狀態 | 意思 | 誰設 | 誰移除 |
|---|---|---|---|
| （無 status label） | backlog，還沒 explore | — | — |
| `status/ready` | explore 完、body 是規格、可以丟給 Rhythm（Matt 的 `ready-for-agent`） | `/to-issue` | Rhythm 派工時 |
| `status/running` | Rhythm 在跑（取代 `rhythm-running`） | Rhythm | Rhythm |
| `status/waiting` | 停在 gate 等人回（§1 的 `rhythm-waiting`） | Rhythm | Rhythm 收到 reply |
| `status/blocked` | 出狀況或被 policy 擋（取代 `rhythm-blocked`） | Rhythm | 人移除即重派 |
| `status/in-review` | PR 開了、merge-ready | Rhythm 在 Run 結束帶 PR URL 時 | PR merge 自動 close issue |

`rhythm-change` 仍是命令 label 不是狀態：加上去、Rhythm 收掉、狀態換成 `status/running`。`status/ready` 與 `rhythm-change` 分開，是讓「可以做」與「現在做」不同步，board 上才有 todo 欄；之後要讓 Rhythm 自己從 ready 排隊取，再加 scheduler。`priority/*` 留給人手動排序，不在流程裡；`type/*` 由 `/to-issue` 標。沒有 `status/ready` 的 issue Rhythm 不派，留言「尚未 ready」並標 `status/blocked`，同現在 assignee 缺的處理。

Rhythm 端：狀態 label 從兩個擴成五個，定義在 Installation 層（`provider_config.labels`，現有 running / blocked 已可改名），**設新狀態時移除舊狀態**（GitHub 要自己 swap；GitLab scoped label `status::running` 原生互斥；Jira 是 transition，Jira 版已有 ready / running / blocked）。

GitHub Projects 的 board 直接用 `status/*` 分欄；`gh issue list --label status/ready` 就是 todo。

### 7.3 Repo 端的 tracker 設定：`docs/agents/issue-tracker.md`

跑在 repo 裡的 skill（`/to-issue`、之後的 `/retro`）要知道：tracker 是哪個、CLI（`gh` / `glab` / Jira）、派工 label 叫什麼、五個狀態的名稱、epic 與 blocking 在這個 tracker 怎麼表示。現在這些寫死在 rhythm 的 `/to-issue`（`gh`、`kirkchen`、`rhythm-plan`）。導入 mattpocock 的檔名與 template 形狀（`docs/agents/issue-tracker.md`，github / gitlab / local 三種 template），內容是我們的字彙。`triage-labels.md` 不需要（沒有 triage skill）。不要跑 `setup-matt-pocock-skills`，它會建 Matt 原名的五個 label。

`/to-issue` 從 rhythm 的 repo-local skill 搬進 Beat 成為 `/beat:to-issue`，讀這份檔；explore 的 handoff `next` 指向它。

### 7.4 規模：spec 與 ticket 的對應

| mattpocock | 這裡 | 誰產生 |
|---|---|---|
| ticket（一個 context window 的垂直切片） | Beat 的 task（`tasks.md` 一項，apply 時一個 subagent 一項） | `/beat:plan`，不上 tracker |
| spec（一個 feature、一張 issue） | 一個 change = 一張 issue = 一個 Task = 一個 PR | `/to-issue`，出口 small / standard |
| spec 大到多個 PR | 一條 route = 多個 change node | `/to-issue`，出口 too-big |

Matt 把 ticket 開成 issue是因為每張要 `/clear` 換 context、而且 `implement-spec` 從 tracker 讀 blocking edge 排 frontier；這兩件事 Beat 內部已解決（task 靠 `tasks.md` 與 status.yaml 銜接，frontier 在 route 的 `blocked_by`），ticket 這層不上 tracker。

too-big 的形狀：
- 一張 **epic issue** = route 的 map，body 由 `route.md` 生成（目的地、已定案、還沒定、先不做），不另寫一份。
- 每個 change node 一張 **sub-issue**（GitHub 原生 sub-issue；GitLab / Jira 對應 epic child），`blocked_by` 寫成 tracker 的原生 blocking 關係。node 自己 explore 完才標 `status/ready`，所以 board 上「ready 且沒被 block」就是 frontier。
- route `status.yaml` 每個 node 加 `issue:` 欄位記 `#n`，兩邊互指（schema 與 validator 要改）。node 狀態仍從 change 推導，tracker 的 `status/*` 是 Rhythm 寫的投影，不是第二個真相來源。

`beat/routes/` 管「決定了什麼、還沒決定什麼」（agent 讀），tracker 管「誰能做、誰在跑」（人看 board）。route 不能廢：要離線、要跨 tracker、「decisions so far」tracker 放不下。

### 7.5 mattpocock repo 端檔案的取捨

| 檔案 | 決定 | 原因 |
|---|---|---|
| `GLOSSARY.md`（根目錄） | 導入，rhythm 放 symlink `GLOSSARY.md -> beat/CONTEXT.md`（0.6 改為直接搬到根目錄，見 docs/migrations/0.6-project-layout.md；symlink 方案作廢） | `domain-modeling`、`pr`、`tdd`、`diagnosing-bugs` 寫死讀根目錄，路徑不可設；格式與 Beat 的 `context-format.md` 幾乎相同。design 叫完 `domain-modeling` 要跑一次既有的「新詞插進所屬 group」位置檢查 |
| `docs/adr/` | 已對齊 | glossary 交 `domain-modeling`，ADR 仍由 Beat 照 `adr-format.md` 寫（Matt 的沒有 front matter，rhythm `lint:docs` 會擋） |
| `CODING_STANDARDS.md` | 導入，當索引 | 只放 navigation pointer 指向各 README 的 conventions 段；retro 寫這裡，cadence pr-review 已會找 |
| `docs/agents/issue-tracker.md` | 導入（§7.3） | 多 tracker 後 skill 需要 |
| `docs/agents/triage-labels.md`、`docs/agents/domain.md`、`.scratch/` | 不導入 | 沒有 skill 會讀，或已被取代 |

## 8. v4 修訂（兩輪 review 後）

兩輪獨立 review（設計對抗、六情境紙上模擬）找到 24 項，合併後的決定如下。每項標落點：B = Beat branch、#454 / #610 = Rhythm 既有 issue、§7 issue = 新開的 Rhythm issue。

### 8.1 動工前必修

1. **gate 回覆不再一律重跑同一個 Stage**（B、#454）。`OutcomeThen` 的 gate 加 `onReply: <stage>`：`decision` / `env` / `scope` 回覆後接續同一個 phase；plan 之後的 `sensitive` 回覆後跳 `apply`；verify 的 `diverging` 回覆後跳 `fix`，回覆內容是 fix 的第一個工作項。否則 sensitive 與 diverging 會無限 gate 到 `run_limit`。sensitive 的值寫進 `beat/changes/<name>/decisions/sensitive.md`，plan 在新 session 讀檔，不靠上一個 handoff。
2. **過 ADR 三條件、不在已定案的決定一律 brief**（B）。v2 的 `design/SKILL.md` 與 `unattended-mode.md` 有一處寫「unattended: 直接寫 ADR」，會讓 agent 自己選邊、0 個 gate。改成 brief、停，ADR 在回覆後寫。
3. **issue 寫回改以 flow state 為單位**（#610）。現在 Run 終態的 hook 在每個 gate 都留言「已完成」並移除 running；`run_failed` 還把派工 label 加回去並教人「移除 blocked 重派」，對 flow Task 是錯的動作。改成：gate → `status/waiting`、`run_failed` → `status/blocked`（不加回派工 label，留言「回 `/resume` 繼續」）、complete → `status/in-review`；hook 在 `waitingOn=user` 時跳過。
4. **`status/ready` 只在第一次派工檢查**（§7 issue）。派工時 ready 被移除，若之後重派也要求 ready，失敗一次就永遠重派不了。Task 已存在的重派不看 ready。
5. **Stage 模板與 change 名稱**（#454、B）。#454 列出每個 Stage 的模板 `/beat:<phase> {{subject}}` + TAIL。Beat 在 unattended 下以唯一 active 的 `beat/changes/*` 為本次 change，多於一個 → `env`。
6. **companion skill 的提問有對應**（B）。design 的 brainstorming 是 MUST、會問問題並要 approve；unattended 下一問 turn 就結束、沒有 stage-result。規則：從 issue body 回答，「已定案就是 approval」，跳過 approve 步驟；TDD 的 baseline 問題採預設。
7. **verify 規則寫成 matchOutcome 做得到的形式**（#454、B）。`critical>0` 寫不出來（只有等值與 enum）。順序改為 `diverging=yes → gate`、`blocked-on=decision → gate`、`blocked-on=env → gate`、`blocked-on=scope → gate`、`critical=0 ∧ blocked-on=none → archive`、`blocked-on=none → fix`。`next=` 的值含空白會被切掉，只放 `/beat:<phase>`。

### 8.2 影響「人讀十行」的

8. **gate question 只取 brief**（#454、B）。Orchestrator 擷取最後一則訊息裡第一個 brief 標題（`# D<n>:` 或 plan brief 的 `# P1:`）到 `## Beat Handoff` 之間的內容；`blocked-on=decision` 但缺這段 → `judge_unreadable`。Beat 端 brief 是 phase 的最後動作，印完不再呼叫工具。
9. **plan brief**（B）。sensitive gate 要有東西可讀：對到哪條情境、Key Decisions、tasks 各一行，≤10 行，回覆 `/answer continue`。decision-brief 的「不可單選項」規則對 plan brief 不適用，它是確認不是選擇。
10. **一個 phase 多個決定一次 gate**（B、#454）。`decision=D1,D2`，每個 brief 一個檔、全部印出；回覆格式 `D1: A`、`D2: B`，一行一題。explore 的文字補一句：有 issue 流程的 repo，`standard` 出口要把決定談完再開票，否則就要預期 gate。
11. **PR body 帶 `Closes #<n>`**（B）。否則 merge 後 issue 不關、`status/in-review` 永遠掛著。
12. **preset 跟著 issue 走**（B）。explore 不寫 status.yaml，preset 沒地方記；`/to-issue` 在 body 寫「出口：small（preset minimal）」，design 從 body 讀。
13. **session 模型照程式碼寫**（本文、B）。Stage 之間新 session；gate 回覆 resume 同一個 session，prompt 是模板 + 回覆。這比新 session 好（不會重問）。decision-brief 的「After the answer」改成「回覆在 prompt 裡」。
14. **PR 階段不在 BEAT_CHANGE_FLOW 裡**（本文、#454）。flow 在 archive 結束（complete → `status/in-review`），PR_REVIEW_FLOW 由 PR 事件另開 Task；否則兩個 Task 在同一條 branch 上互 push。§1 的圖已改。
15. **所有 gate reason 都上 issue surface**（#610）。不只 `input_required`：`loop_limit` / `budget` 的回覆視為 `resume`，`run_limit` 留言「到 Task UI 處理」。
16. **issue 留言當回覆的語意收窄**（#610）。只有開頭 `D<n>:`、`/answer`、`/resume` 的 Approver 留言算回覆；非 Approver 留言靜默忽略、不回「授權者尚未連結」。

### 8.3 文字漂移與缺票

17. #610 改用 `status/waiting`（v3 §7.2），並列 #606 為依賴（PR Review trigger 對 issue 留言也觸發，`issue_comment` 訂閱會撞）。
18. §7 全部沒有 issue：開一張 Rhythm issue 涵蓋 `status/*` 五態與 swap 語意、ready 只在首派檢查、派工時檢查 tracker 的 blocking、外部 issue 開立時自動留言。
19. 已定案只有一個寫入方（#610、B）：Rhythm 從 gate 回覆寫 issue（留言 + body 段），Beat 只寫 design.md。
20. route 與 sub-issue 的 linkage（B 第二個 change）：sub-issue body 帶 `Route: <r>/<node>`，design 據此設 `route:`；node 狀態 `blocked` → `env`；route 的 archive 搬到 `/beat:explore <route>`（平行 node 在各自 branch 看不到彼此的 archive）；route `status.yaml` 加 `issue:`。
21. `blocked-on=scope`（B、#454）：apply 才發現要拆第二個 PR 時的出口，brief 給兩個選項（縮小範圍、剩下開新 issue / 改走 route），回覆後由人重新 explore。
22. archive 重入規則與 HARD-GATE（B）：env 中斷後重跑從「已 archive、未開 PR」接續；HARD-GATE 的「MUST invoke finishing-a-development-branch」加 unattended 例外。worker 每個 run 都 auto-push，「archive 只 push 一次」刪掉。
23. explore 加「不做」出口：close 並留原因（B）。
24. review 後的 spec 漂移（cadence、本文「不做的」）：babysit 碰到 `beat/features` 或 gherkin 行為時 `needs-user-input`；其他漂移接受，PR 的「決定與影響」是 archive 當下的快照。

## 不做的

- 不做 LLM evaluator 當每個 Stage 的 judge。`run_output` 免費且可驗證；LLM 只在 verify 的 critic-actor loop（已有）。
- 不把 explore 放進 flow。explore 是 HITL，是整個設計裡人要花時間的地方。
- 不自動 merge。
- 不用 Matt 的 `to-tickets` 拆 ticket。Beat 的 tasks.md 在同一個 change 內接續做（subagent-driven 時每 task 一個新 subagent，已等價於 fresh context）；跨 PR 的拆分走 routes。
- 不把 Beat 的 CRITICAL / WARNING 與 cadence 的 P0–P3 統一字彙。兩邊各有 calibration 文件，統一的成本高於收益；flow 只讀各自的 stage-result。

## 我替你定的（builder check 後）

- Gate question 來源：Run 最後一則 agent 訊息，不加新的 judge 型別。
- stage-result 值不含空白；`blocked-on` 只有 `none|decision|env`，id 放 `decision=`。
- 規則順序 diverging → decision → env → sensitive → critical → next。
- apply 才發現的 sensitive 不再 gate，只進 PR 段落。
- `assumed` 與 brief 都落在 `beat/changes/<name>/decisions/`，不動 status.yaml schema。
- 每個 Stage 新 session，worktree 靠 Task PVC 跨 Stage。
- Retro Stage 不進第一階段的計畫。

## 留給 builder 的

- `sensitive.situations` 的預設值（空、或 Beat 給錢 / 權限 / 對外契約三條範例）。
- `{{gate_reply}}`（即 `userMessage`）的 untrusted 包裝方式（比照 `flows/untrusted.ts`）。
- gate 寫回 issue 的留言文案（比照 `write-back-copy.ts` 的風格）。

## 與 beat-topology.md 的關係

topology 解決「大小不一的東西硬塞一條管子」：出口、preset、fix 迴圈、routes。本文解決「管子中間的 gate 是無條件的」：把 gate 變成訊號驅動，把人要讀的東西壓成 brief。topology 的六個症狀裡第 5 個（教訓沒有回灌）由 §5 Retro Stage 接手。
