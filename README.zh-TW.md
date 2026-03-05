[English](README.md) | 繁體中文

# Beat

先想清楚，再寫程式。Beat 是一個 Claude Code 外掛，讓你在動手寫 code 之前先寫好 [Gherkin](https://cucumber.io/docs/gherkin/) scenario — 再從這些規格驅動 TDD 實作。

## 問題

```
你：「加一個使用者登入功能」
Claude：*寫了 400 行程式碼，漏掉速率限制，
        測試是事後補的，edge case 在 PR review 才浮出來*
```

## 用了 Beat 之後

```
你：/beat:design add-user-login

Beat 產出：
┌───────────────────────────────────────────────┐
│ Feature: 使用者登入                            │
│                                               │
│   Scenario: 用正確憑證成功登入                   │
│   Scenario: 密碼錯誤顯示錯誤訊息                 │
│   Scenario: 連續失敗 5 次後鎖定帳號              │
│   Scenario: 閒置 30 分鐘後 session 過期          │
│   Scenario: 從新裝置登入寄送通知信                │
└───────────────────────────────────────────────┘

你：/beat:apply

Beat 用 TDD 逐一實作每個 scenario：
  ✗ 寫測試：「連續失敗 5 次後鎖定帳號」  (紅燈)
  ✓ 實作鎖定邏輯                        (綠燈)
  ✓ 重構                               (整理)
  → 下一個 scenario...
```

每個 scenario 都有測試。每個測試都連回規格。沒有遺漏。

## 安裝

**從外掛市集：**

```shell
/install kirkchen/beat
```

**或本地安裝：**

```bash
claude --plugin-dir /path/to/beat
```

接著在你的專案中：

```bash
/beat:setup    # 偵測技術棧，建立 beat/config.yaml
```

## 快速開始 — 3 個指令

大部分的變更只需要這三步：

```bash
/beat:design fix-expired-session    # 描述行為變更 → 產生 Gherkin
/beat:apply                         # TDD：寫測試 → 實作 → 下個 scenario
/beat:archive                       # 同步 feature 到 living docs，收尾
```

複雜的變更可以在 archive 前加上 `/beat:verify` — 它會派一個獨立的 agent 驗證你的實作是否符合規格，抓出實作者自身 context 容易忽略的缺漏。

Beat 在你需要時可以擴展（見[完整 Pipeline](#完整-pipeline)），但簡單路徑就能應付日常修 bug 和小功能。

## 已有程式碼？從 Distill 開始

大部分 BDD 工具只能用在新程式碼。Beat 也能反向操作 — 從**既有程式碼**萃取 Gherkin：

```bash
/beat:distill src/billing/          # 讀取程式碼，產生 feature 檔
```

```gherkin
@distilled @behavior @happy-path
Scenario: 月結帳單自動調整短月天數
  Given 訂閱的帳單日設為 31 號
  When 二月帳單週期執行
  Then 扣款日調整為 28 號
```

現在你有了系統實際行為的 living documentation。下次修改帳單邏輯時，Beat 已知道有哪些行為存在、該寫哪些測試。

**這是既有專案的建議進入點。** 先 distill，再用完整 pipeline 處理後續變更。

## 完整 Pipeline

```
explore → design → plan → apply → verify → archive
```

| 指令 | 做什麼 | 什麼時候用 |
|------|--------|-----------|
| `/beat:explore` | 思考、釐清想法，不寫 code | 需求不明確、腦力激盪 |
| `/beat:design` | 建立變更 + 產生規格 | 開始任何變更 |
| `/beat:plan` | 任務拆解 + 多角色審查 | 複雜功能（5+ scenario） |
| `/beat:apply` | 逐 scenario TDD 實作 | 每次變更 |
| `/beat:verify` | 獨立驗證，比對規格 | 上線前驗證複雜變更 |
| `/beat:archive` | 同步 feature + 歸檔 | 每次變更完成後 |

**依變更大小選路徑：**

| 變更規模 | 指令 | 範例 |
|---------|------|------|
| Bug 修復 | `design → apply → archive` | 修正日期計算的 off-by-one |
| 功能開發 | `design → apply → verify → archive` | 新增密碼重設流程 |
| 大型功能 | `design → plan → apply → verify → archive` | 支付處理系統 |

每個變更都在 `beat/changes/<name>/` 中，用 `status.yaml` 追蹤進度。

## Beat 產出什麼

每個變更可包含這些 artifact（你選擇要哪些）：

| Artifact | 預設 | 用途 |
|----------|------|------|
| `features/*.feature` | **包含** | Gherkin scenario — 行為規格 |
| `proposal.md` | 可選 | 為什麼要做這個變更 |
| `design.md` | 可選 | 技術決策 |
| `tasks.md` | 可選 | 實作計畫 |

純技術性變更（重構、工具鏈、依賴升級）可以完全跳過 Gherkin，改由 `proposal.md` 驅動。

## 測試架構

Beat 透過輕量級文字註解連結 feature 檔和測試 — 不需要框架、不需要建置步驟、適用任何語言：

**在 `.feature` 檔中：**
```gherkin
@behavior @happy-path
# @covered-by: src/billing/__tests__/date-calc.test.ts
Scenario: 月結帳單自動調整短月天數
```

**在測試檔中：**
```typescript
// @feature: monthly-billing.feature
// @scenario: 月結帳單自動調整短月天數
describe('月結帳單', () => {
  it('自動調整短月天數', () => { ... })
})
```

`/beat:verify` 自動檢查這些連結 — 沒有 scenario 缺測試，也沒有測試缺 scenario。

三層測試，各自使用專案自己的框架：

| 層級 | Tag | 範例 |
|------|-----|------|
| **E2E** | `@e2e` | 完整使用者旅程，經過 UI |
| **行為測試** | `@behavior` | 商業邏輯，帶 `@covered-by` 追蹤 |
| **單元測試** | — | 技術細節，不綁 feature |

## 設定

`/beat:setup` 會自動偵測你的技術棧。所有設定都是可選的：

```yaml
# beat/config.yaml
language: zh-TW               # Artifact 語言（BCP 47）
context: |                     # 專案背景
  Express API, PostgreSQL, Vitest for testing
testing:
  behavior: vitest             # 用於 @behavior scenario
  e2e: playwright              # 用於 @e2e scenario
rules:
  gherkin:
    - "每個 feature 最多 5 個 scenario"
```

## 搭配 Superpowers（推薦）

Beat 可以獨立運作，但搭配 [superpowers](https://github.com/obra/superpowers) 能獲得結構化腦力激盪、git worktree 隔離和 TDD 紀律：

| 能力 | 有 superpowers | 沒有 |
|------|---------------|------|
| 腦力激盪 | 結構化思考後再寫規格 | 直接對話 |
| Worktree 隔離 | 在獨立的 git worktree 中工作 | 在目前分支上工作 |
| TDD 紀律 | 強制紅燈-綠燈-重構 | 標準實作流程 |
| 任務生成 | 帶審查的詳細計畫 | 簡單 checklist |
| 歸檔後 | 引導 PR/merge 流程 | 手動 |

## 設計原則

- **行為優先於實作** — scenario 描述系統做什麼，不描述怎麼做
- **檔案系統即狀態** — `status.yaml` + 目錄結構，沒有資料庫，完全可 git 追蹤
- **可選就是真的可選** — ceremony 隨複雜度調整，不是一體適用
- **框架無關** — 適用任何語言、任何測試框架
- **獨立驗證** — `/beat:verify` 用全新 agent 避免確認偏差

完整設計哲學見 [docs/DESIGN_PRINCIPLES.zh-TW.md](docs/DESIGN_PRINCIPLES.zh-TW.md)。

## 授權

MIT
