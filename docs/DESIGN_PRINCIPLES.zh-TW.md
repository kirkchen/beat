[English](DESIGN_PRINCIPLES.md) | 繁體中文

# Beat 設計原則

這份文件解釋 Beat *為什麼*這樣運作。每個章節說明一個原則、我們捨棄了什麼替代方案、以及這個取捨的代價。當你要評估跨多個 skill 的變更或整體方向時，請參考此文件。

## 讀者

這份文件面向 Beat 的貢獻者和進階使用者，幫助理解設計決策的脈絡。如果你剛開始用 Beat，請先看 [README](../README.zh-TW.md)。

---

## 行為優先於實作

Gherkin scenario 描述**系統做什麼**，不描述怎麼做。

```gherkin
# 好 — 重構後依然穩定
Scenario: 月結帳單自動調整短月天數

# 壞 — 改了函式名稱就壞掉
Scenario: calculateNextTransactionDate 將日期鉗位到月底
```

**我們捨棄了什麼：** 在 Gherkin 中放內部實作細節 — method signature、資料庫欄位名稱、內部設定常數。這些會讓規格耦合到實作，每次重構都會壞掉。

**什麼應該出現在 scenario 中：** 可觀察的行為細節 — HTTP status code、response 欄位名稱、商業規則的閾值（「失敗 5 次後鎖定」）、使用者可見的訊息。這些就是行為本身，不是實作細節的洩漏。Scenario 應該具體描述*系統做什麼*（見 [feature 撰寫慣例](../references/feature-writing.md)）。

**取捨：** Scenario 不解釋內部*怎麼*運作。開發者仍然需要看程式碼或 `design.md` 才能了解細節。我們接受這個代價，因為能撐過重構的規格，比鉅細靡遺記錄每個實作細節的規格更有價值。

## Gherkin 是思考工具

寫 Gherkin 的價值在於**強迫你在寫 code 前釐清行為**。`.feature` 檔是好的思考過程的副產物，不是目的。

**我們捨棄了什麼：** 對每個變更都強制要求 Gherkin。純技術性變更（依賴升級、工具鏈、無行為改變的重構）從 Gherkin 得不到好處。強制要求只會把思考變成填表。

**取捨：** 使用者必須自行判斷「這個變更有行為嗎？」這個判斷有時會出錯。我們接受這個代價，因為替代方案 — 什麼都要寫 Gherkin — 會訓練人寫出品質低劣的 scenario，只為了滿足流程。

## 檔案系統即狀態

所有狀態都在檔案中：`status.yaml`、artifact 文件、目錄結構。沒有資料庫、沒有外部服務。

**我們捨棄了什麼：** 帶自有資料庫的 CLI 工具、Web 儀表板、與專案管理工具（Jira、Linear 等）的整合。

**取捨：** 沒有跨專案的集中視圖。沒有即時協作。沒有自動通知。我們接受這個代價，因為基於檔案的狀態可以用 `cat` 檢視、用 `git diff` 除錯、用 `git log` 追蹤版本，而且不需要任何基礎設施。

## 只進不退的 Pipeline

Phase 只能向前推進：`new → proposal → gherkin → design → tasks → implement → verify → sync → archive`。不能倒退。

**我們捨棄了什麼：** 雙向 phase 轉換（「回到 design 修一下規格」）。這會造成狀態歧義 — 實作現在過時了嗎？任務還有效嗎？驗證的是哪一版規格？

**取捨：** 如果在實作過程中發現規格有問題，你直接修改 artifact 然後繼續向前，而不是「回去」。一開始會覺得不自然。我們接受這個代價，因為只進不退消除了一整類狀態混亂，而且不管你在哪個 phase，修改 artifact 的動作都一樣。

## 可選就是真的可選

Proposal、design、tasks 是真正可選的 — 不是「可選但你應該每次都做」。

| 變更 | Artifact |
|------|----------|
| 修一個錯誤訊息的 typo | `design → gherkin → apply → archive` |
| 新增密碼重設 | `design → proposal → gherkin → apply → verify → archive` |
| 支付處理系統 | `design → proposal → gherkin → design.md → plan → tasks → apply → verify → archive` |

**我們捨棄了什麼：** 對所有變更套用同一種 ceremony 等級。很多 BDD 工具不管變更大小都要走完整流程，這會訓練使用者為了小變更生出空洞的 artifact。

**取捨：** 使用者必須自己選 ceremony 等級。選錯會發生 — 有人在需要 `plan` 的變更上跳過了它，或是為一行修改寫了 proposal。我們接受這個代價，因為可調整的 ceremony 長期會培養更好的判斷力，而固定的 ceremony 只會培養怨氣。

## 框架無關

Beat 適用任何語言、任何測試框架、任何技術棧。Skill 描述*做什麼*（「為這個 scenario 寫一個測試」），依靠 `config.yaml` 或自動偵測決定*怎麼做*。

註解慣例（`@covered-by`、`@feature`、`@scenario`）使用純文字註解。不依賴框架、不需要建置步驟、不做 AST 解析。

**我們捨棄了什麼：** 與特定框架深度整合（只支援 Cucumber step definition 作為綁定、Jest 專用 matcher 等）。這會讓 Beat 在一個技術棧上很強大，但在其他棧上完全沒用。

**取捨：** Beat 無法利用框架特有功能（Cucumber 的自動 step matching、pytest-bdd 的 decorator binding）。這些生態系的使用者會得到一個比他們框架原生更簡單的註解系統。我們接受這個代價，因為跨所有技術棧的可攜性，勝過在單一棧上的強大。

## 獨立驗證

`/beat:verify` 派出一個**全新的 subagent**，沒有對話歷史。它只看到 artifact 和程式碼。

**我們捨棄了什麼：** 讓實作的 agent 驗證自己的成果。寫 code 的 agent 有 context 偏差 — 它知道自己*打算*做什麼，所以傾向確認程式碼做到了它打算的事，而不是規格說的事。

**取捨：** 驗證比較慢（subagent 啟動、重新讀檔），有時會出現假陽性（subagent 誤讀了有歷史脈絡就很明顯的東西）。我們接受這個代價，因為自我驗證的假陰性（漏掉真正的缺漏）代價遠高於假陽性。

## 雙驅動模式

同一條 pipeline 服務兩種模式：

- **Gherkin 驅動**（預設）：Feature 檔驅動規劃、實作和驗證
- **Proposal 驅動**（跳過 gherkin 時）：Proposal 驅動規劃，風險點驅動測試

**我們捨棄了什麼：** 兩條獨立的 pipeline。這會讓維護面翻倍，並在兩種模式之間產生微妙的不一致。

**取捨：** Skill 必須檢查「這是 gherkin 驅動還是 proposal 驅動？」並據此分支，在好幾個 skill 中增加條件邏輯。我們接受這個代價，因為一條帶模式切換的 pipeline 比兩條平行 pipeline 更容易理解。

---

## 測試哲學

### 三層測試，一個原則

| 層級 | 用途 | 驅動來源 | Feature 綁定 |
|------|------|---------|-------------|
| E2E | 端到端使用者旅程 | `@e2e` scenario | Step definition 或註解 |
| 行為測試 | 商業邏輯和規則 | `@behavior` scenario | `@covered-by` / `@scenario` 註解 |
| 單元測試 | 技術面 edge case | 開發者判斷 | 無 |

原則：**每一層都用專案自己的工具**。Beat 不引入測試框架 — 它告訴 agent 要測什麼、怎麼連回規格。

### 為什麼用文字註解，不用框架綁定

大部分 BDD 工具使用框架層級的綁定（Cucumber step definition、pytest-bdd decorator）。Beat 用純文字註解：

```gherkin
# 在 .feature 中 — 指向測試
# @covered-by: src/billing/__tests__/date-calc.test.ts
```

```typescript
// 在測試中 — 指向 feature
// @feature: monthly-billing.feature
// @scenario: 月結帳單自動調整短月天數
```

理由：
1. **零成本** — 只是註解，沒有 runtime、沒有建置步驟
2. **任何語言** — 每種語言都有註解
3. **機器可檢查** — `/beat:verify` 可以 grep 這些
4. **人類可讀** — 不需要工具就能看到連結

### 粒度

Scenario 應該在**行為層級**：PM、QA、或新進團隊成員不需要看程式碼就能理解系統做什麼。如果只有作者能理解某個 scenario，代表它太細了。

內部函式的單元測試不需要 Gherkin scenario。它們是實作細節，不是規格。

---

## Pipeline 設計

### 為什麼是這個順序

```
設計階段：[proposal] → gherkin → [design.md]
規劃階段：tasks（帶多角色審查）
```

1. **Proposal** 回答「為什麼」 — 沒有動機，你會做錯東西
2. **Gherkin** 回答「做什麼」 — 具體的 scenario 迫使你精確，是散文做不到的
3. **Design** 回答「怎麼做」 — 已知行為後做技術決策會更好
4. **Tasks** 回答「按什麼順序」 — 實作步驟放最後，因為它們依賴前面所有的東西

反轉任何一對都會退化。在不知道行為的情況下寫 tasks，產出的是臆測性的計畫。在不知道 scenario 的情況下寫 design，產出的是過度設計的架構。

### 為什麼設計和規劃之間要暫停

設計是創造性的 — 定義問題、探索行為、做技術選擇。規劃是結構性的 — 分解任務、從多個角度審查、產出 checklist。

兩者之間的暫停是刻意的。它讓團隊有機會審查規格 artifact、挑戰假設、在**開始執行之前**對齊方向。

**我們捨棄了什麼：** 合併成單一的「設計兼規劃」階段。這對小變更可行，但把兩種不同的思考模式（創造性探索 vs. 結構性分解）壓在一起，對複雜變更會產出更差的結果。

---

## Beat 不是什麼

- **不是測試執行器** — Beat 產出規格並引導實作，但不會自己跑測試
- **不是專案管理工具** — 變更是輕量級的思考容器，不是工單
- **不對架構有意見** — Beat 不在乎你用微服務還是單體、REST 還是 GraphQL
- **不取代人類判斷** — Skill 引導 agent，開發者決定什麼適合

---

## 維護這份文件

在以下情況更新：
- 設計決策影響到多個 skill
- 實際使用揭露了一個隱含的原則，應該被明確記錄
- 發現某個原則是錯誤或過時的

變更應附上清楚的說明，解釋為什麼新增、修改或移除該原則。
