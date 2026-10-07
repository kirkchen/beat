# Proposal: Beat 拓樸重構，從一條管子到兩層迴圈

日期：2026-10-07
狀態：draft v2，經三輪 subagent 審查（設計對抗、Rhythm 執行面、skill 可實作性）後修訂
來源：對 Beat skill 本體、superpowers 6.4.1、mattpocock/skills（HEAD 6fd9479）、cadence、rhythm 與 jkopay-agents 兩個 repo 的 Beat artifact、以及 Rhythm 兩個部署（homelab、jkopay）資料庫的分析。數字除非另註，皆來自 homelab 的 Rhythm 資料庫（2026-05 到 10 月，5528 runs / 1452 tasks，其中 170 個 task 用到 Beat）。

## Why

Beat 現在是一條線性的管子：

```
explore → design → plan → apply → verify → archive
```

每個 change 不論大小都走同一條，階段之間沒有分流、沒有回頭的路。資料顯示的症狀都是「大小不一的東西硬塞同一條管子」：

1. 太大的沒有拆的地方。rhythm 有 change 跑到 117 個 commit、跨 54 天；`jira-pull-ingress` 的 design.md 改到 revision 25。170 個 Beat task 裡走完 design 到 archive 的只有 59 個。
2. 太小的沒有人走快速道。`2026-05-17-run-events-nul-sanitize` 一支 `stripNul` 純函數，寫了 proposal 77 行、design 256 行、tasks 472 行、verify 127 行；隔天的 follow-up change 又 930 行。它的 status.yaml 記錄的 preset 是 full。design 其實有 Minimal / Technical preset，但選擇交給 agent 自由心證，沒有判定依據也沒有升級機制。兩個 repo 每個 change 的 artifact 合計中位數 1250 到 1530 行。
3. 探索完沒有出口。58 個 task 只跑了 explore 就停。很多是要先看到東西或查到資料才能決定，但 explore 的結尾明寫「No required ending」（`skills/explore/SKILL.md:141-147`），只能繼續對話或直接進 design。
4. 修正迴圈靠人抄。verify 跑過的 78 個 task 有 16 個跑超過一次（最多 7 次），每次 $17、context 中位數 610k token。verify 的 findings 已經寫在 verify.md，但 apply 沒有讀它的入口，要靠人把 P2 抄進下一次 apply 的 prompt。
5. 教訓沒有回灌。rhythm 的 `beat/config.yaml` 塞了一堆 rules（archive 後修 ADR 路徑、design.md 不可整份覆蓋、CONTEXT.md 新名詞放分組），每條都是某次 change 踩到之後人工補的。
6. schema 已經在漂。rhythm 的 status.yaml 用 `artifacts:` / `verify:` / `bundled_issues` / `artifact_preset`，不是 `references/status-schema.md` 的 `pipeline:` / `verification:`。任何新欄位加上去之前，要先承認 schema 會被 agent 靜默改寫。

Beat task 中位數有 12 次人工訊息（非 Beat task 中位數 1）。審查後發現這個數字要拆三類：沒掛 supervisor 的 task 需要人手動推階段、Rhythm 的 run report 截斷讓 supervisor 要求重貼測試輸出（`packages/web/src/lib/tasks/run-report.ts:12-20`）、以及真正的 Beat 流程缺口（verify findings 要人抄、push 時機沒寫在 skill 裡）。前兩類是 Rhythm 的採用與產品問題，不在這份 proposal 範圍。

對照 mattpocock/skills，它的流程是 cycle 而不是 pipeline。explore（grilling）可以分流到 research（AFK）、prototype（HITL）、或 wayfinder（工作大到一個 session 裝不下時先畫地圖）；implement 每張 ticket 在乾淨 context 跑完就回來；結尾的 retro 改的是 agent 的環境，不是程式碼。差別在流程的形狀，不在 skill。

superpowers 在這次重構中不動：brainstorming、writing-plans、TDD、subagent-driven-development、using-git-worktrees、finishing-a-development-branch 照現在的方式 invoke。

## What Changes

### 1. explore 結束時宣告出口

explore 的「No required ending」改成「結束時宣告一個出口與依據，使用者可覆寫」。不新增 AskUserQuestion，做法比照 brainstorming 的口頭分類：agent 宣告、給預設、人不出聲就照做。

| 出口 | 可觀察的判定依據 | 動作 |
|---|---|---|
| `small` | 列得出受影響的檔案或目錄且在同一個 module、沒有未決決策、不需要新名詞 | 建 change，`preset: minimal` 或 `technical` |
| `standard` | 一個 change 裝得下，但有決策要在 design 定 | 建 change，`preset: standard` 或 `full` |
| `too-big` | 受影響的 module 超過一個、或有多個互相依賴的決策、或估計要多個 PR | 建 route（§4） |
| `blocked` | 現在定不了，差一樣東西 | 建一個 blocked 節點，`kind: research`（AFK）/ `prototype`（HITL，見 §5）/ `decision`（HITL）；解掉後回 explore |

跟 brainstorming 三路徑的對應寫成一張表，避免 agent 分類兩次：Spike → `blocked`、Bounded → `small`、Architectural → `standard` 或 `too-big`。判定依據一律是「列得出什麼」，不要求 agent 估 scenario 數（explore 時還沒寫 gherkin，估出來會系統性偏小）。

### 2. preset 升級成 size，並加機械升級條件

不新增 `size` 欄位，把 rhythm 已經在用的 `artifact_preset` 正式納入 schema，由它決定各階段強度：

| 階段 | minimal / technical | standard / full |
|---|---|---|
| design | 不問 preset，直接產 | 現在的流程 |
| plan | 只留 test coverage 一個角色，不問角色確認 | 現在的 multi-role review |
| verify | 一個獨立 subagent（仍是 fresh context，保留 anti-bias 前提） | 現在的兩個並行 subagent |

防濫用靠機械條件，不靠 Rationalization Table：apply 階段若 diff 碰到第二個 module、或檔案數 / 行數超過 config 設定的門檻，強制把 preset 升級成 standard、寫進 status.yaml、並補跑 standard 的 verify。verify 的 HARD-GATE 與 Red Flags 要同步改寫，否則 small 路徑會與「平行派兩個」的 gate 打架。

### 3. verify findings 結構化，apply 直接吃（cycle 2）

verify.md 改為 YAML front matter + 人讀區塊：

```yaml
sha: <HEAD at verify time>
mode: full | incremental
findings:
  - { id: F1, severity: CRITICAL, dimension: 1B, scenario: "<name>", file: "src/a.ts:42", fix: "一句話方向", status: open }
```

status.yaml 只存 `verification.sha` 與各嚴重度計數，明細留在 verify.md（status-schema 規定 pipeline 用單行 flow，陣列塞不進去）。

apply 加一個入口：args 含 `fix-from-verify`，或使用者說「修 verify 的 findings」時，讀 verify.md 中 `status: open` 的 findings 當 task list，修完標 `fixed` 並提示重跑 verify。

增量 verify：`mode: incremental` 只對照 `sha..HEAD` 的 diff 與被碰到的 scenario，另加一次便宜的全量機械檢查（tests、lint、scenario 與 test 的對應表）。兩條硬規則：sha 不在 history（rebase 後）就退回 full；archive 前的最後一輪必須是 full。

apply 不 push，push 只在 archive 之後。這在 Rhythm 已由 beat-supervise 管（`rhythm/.claude/skills/beat-supervise/SKILL.md:166-177`），寫進 skill 是為了 Codex 與沒有 supervisor 的場景。

### 4. route 層：第一版只給人看

一個 route 放在 `beat/routes/<name>/`：

- `route.md`：沿用 wayfinder 的五段（Destination / Notes / Decisions so far / Not yet specified / Out of scope）。
- `status.yaml`：只存節點與邊，不存狀態。

```yaml
name: <kebab>
created: YYYY-MM-DD
nodes:
  <node-id>: { type: research|prototype|decision|change, blocked_by: [<node-id>], change: <change-name>, result: <path> }
```

節點狀態從對應 change 的 `phase` 或 `result` 檔案是否存在推導，frontier 也是推導值，不落檔。這樣 route 不會成為第二份會漂移的狀態機，archive 也不需要回寫 route。

Rhythm 零改動：Task Flow 明列 DAG 為非目標（`rhythm/beat/features/api/task-flow/proposal.md:113`），所以一個 change 仍是一個 Task，要平行就由人或 rhythm-dispatch 讀 frontier 開多個 Task。若未來要讓 Rhythm 自動派單，route 的 status.yaml 必須只在 main 由單一寫入者改，worktree 內的 change 只回報不回寫。

### 5. prototype 與 research 節點

prototype 拿來回答設計問題，放在 gherkin 之前。節點內容：要回答的問題、要比的方案、判定標準、載體（`config.yaml` 的 `prototype.surface`，rhythm 是 storybook；沒設定就 fallback 到 mattpocock `prototype` skill 的作法）。

story 與實作分開處理：

- story 檔案可以直接進 main，當正式 story 保留。節點要標清楚哪些 story 是已核准的體驗、哪些只是比較用的方案；比較用的在人選定後刪掉。
- prototype 階段為了讓 story 跑起來寫的實作程式碼留在 `prototype/<name>` branch，不進 main。apply 時從 gherkin 與 story 用 TDD 重寫。這條要寫成 HARD-GATE，因為程式碼已存在時 agent 會把 TDD 的 red 步驟 rationalize 掉；prototype 本身走 brainstorming 的 Spike 路徑並標 throwaway。
- design 寫 gherkin 前先讀已核准的 story：每個 story 狀態要嘛變 scenario、要嘛明寫 out of scope。

在 Rhythm 裡，prototype 的「人看 storybook 選方案」走 gate（`input_required` → `gateReply`）加 Task Detail 操作；Slack 回覆不保證被接受。

research 是 AFK 節點：輸入是問題與要查的來源，輸出是 repo 內的 markdown 檔（路徑記在節點的 `result`），不經 run report 傳遞（會被截斷）。可以交給 mattpocock `research` skill 或派給 Rhythm 一個 run。

### 6. 每個階段結尾的 handoff 報告

`references/handoff-report.md` 定義固定格式，各 skill 結尾只留一行引用：

```
## Beat Handoff
change: <name>  phase: <phase>  preset: <preset>
commit: <short-sha>  tasks: 7/9
checks: lint=0 test=0 (指令: ...)
open-findings: critical=0 warning=2
next: /beat:verify <name>
blocked-on: none | <一句話>
```

只放能由指令得出的事實，並貼指令的原始輸出；「我認為通過」這類判斷不進報告。它取代的是 supervisor 的 `git status` 類機械查驗，不是人工抽查判斷。若環境注入了 nonce（Rhythm 的 `rhythm-stage-result[{{nonce}}]: k=v` 契約，`flows/stage-result.ts:8-29`），最後一行補那個 token；沒有 nonce 照常運作。

### 7. retro 獨立，不綁 archive

archive 已有 22 處確認點，retro 不放進去。第一版在 archive 結尾用一行提示 handoff 給 mattpocock `/retro`（附 Beat 脈絡：這個 change 的 verify.md 與 status.yaml）。等 findings 格式穩定後，再評估內建 `/beat:retro`（只掃 verify findings，同一 dimension 重複出現兩次以上就建議一條 `config.yaml` rule，輸出建議不自動寫）。

## Impact

**前置（必須先做）**

- 修 status-schema 與實際使用的漂移：把 `artifact_preset` 正式納入，決定 `artifacts:` / `verify:` 這些 rhythm 已在用的欄位是收編還是拒絕，並寫一支 `scripts/validate-status.mjs`（比照 `sync-references.mjs --check`）。
- skill 瘦身（刪與 Steps 重複的 dot 圖、共用段落抽 reference）。archive 已 357 行，加完 route 相關會逼近 400。

**新增**

- `references/route-schema.md`、`references/handoff-report.md`、`references/verify-findings.md`。
- `scripts/validate-beat.mjs`：驗 status.yaml 新欄位、route status.yaml（無環、`blocked_by` 引用存在、change 目錄存在）、verify.md findings 欄位、handoff 報告 key 齊全。這些行為用 `claude -p` 測不穩，改成確定性 script。

**修改**

- `references/status-schema.md`：`artifact_preset`、`route`（`<route>/<node>`）、`verification.sha`、`verification.counts`。
- `references/config-schema.md`：`prototype.surface`、`prototype.command`、`size_upgrade`（檔案數 / 行數 / module 門檻）。
- `skills/explore`：取代 Ending Exploration 一節（約 +25 行），加 brainstorming 路徑對照表。
- `skills/design`、`skills/plan`、`skills/verify`：依 preset 分流（合計約 +21 行），verify 的 HARD-GATE 與 Red Flags 改寫。
- `skills/apply`：fix-from-verify 入口、不 push、升級條件（約 +30 行）。
- `skills/verify` 與 `verification-subagent-prompt.md`：findings 輸出格式、incremental 模式（約 +25 行）。
- `skills/archive`：archive 前強制 full verify、retro 提示（約 +10 行）。
- 所有 skill：結尾一行引用 handoff 報告。
- `hooks/session-start`、`references/codex-agents-snippet.md`：說明 route 與出口。
- `tests/`：LLM 測試只保留三個可穩定斷言的行為（small 不派 multi-role、apply 不 push、explore 有宣告出口）；其餘靠 validator script。

**不動**

- superpowers 的 invoke 方式；gherkin 作為 single source of truth；三層 living docs；cadence。
- Rhythm 程式碼。

**依賴**

- mattpocock `research`、`prototype`、`retro` 列為 optional，與 `grill-with-docs` 同等級，沒裝就 fallback。

## 交付順序（每步可獨立驗證與 revert）

1. schema 修漂 + validator script + 三份新 reference。驗證：script 對範例 yaml 通過與失敗。
2. handoff 報告 + apply 不 push。驗證：validator + 一個 pressure 案例。
3. verify findings 結構化 + apply fix-from-verify（先只做 full）。驗證：findings schema、fixture 跑 apply 修復。這一步直接對應症狀 4，也是最能驗證「迴圈能省多少人工訊息」的一步；指標沿用資料庫的「每個 task 人工訊息數」與「verify 重跑次數」，動手前先把人工訊息拆成前述三類取基線。
4. 增量 verify（風險最高，獨立一個 PR）。
5. preset 分流 + 升級條件。驗證：small 的 pressure 與既有 verify gate 測試仍綠。
6. explore 出口 + route 層。驗證：skill-triggering、skill-content、validator。
7. prototype 節點與 retro handoff。

## 範圍外，另開 change

- tasks.md 瘦身（writing-plans 把整段測試與實作程式碼貼進 tasks.md，中位數 800 到 1000 行）。
- Beat 與 superpowers 的縫（brainstorming 寫 `docs/superpowers/specs/`、writing-plans 結尾問執行方式、SDD 自帶 finishing）。
- archive 之後與 cadence pr-review 的銜接（PR body 自動帶 Beat artifact 路徑）。
- Rhythm 側：run report 截斷、push 被 reject 的回報、supervised flow 的採用率。
- Beat repo 自己的 dogfooding（`/beat/` 目前在 `.gitignore`）。

## 待決

1. verify 維度 4（code quality）與 cadence pr-review 四角色幾乎同一套 checklist，同一份 diff 最多被 verify、self-review、pr-review 審三次。保留當 defense in depth，還是 verify 只留 spec 對照與 drift？
2. status-schema 修漂時，rhythm 已在用的 `artifacts:` / `verify:` / `bundled_issues` 是收編進 schema，還是寫 migration 把 rhythm 改回來？
3. `size_upgrade` 的門檻預設值（檔案數、行數、module 數）要訂多少？
