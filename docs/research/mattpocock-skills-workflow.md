# mattpocock/skills 開發流程研究

## 來源與版本

- Repo：https://github.com/mattpocock/skills（`git clone --depth 1`，只讀 repo 本身，未引用任何第三方文章）
- Commit SHA：`4ae2317ddb22b046e26455e4f9c9b3aaaf62212d`
- Commit 日期：2026-10-31（`software-factory: glossary skill for designing a factory (#1316)`）
- 閱讀日期：2026-11-04
- plugin 版本：1.3.2（`.claude-plugin/plugin.json:3`）
- 以下 `path:line` 皆相對於該 repo 根目錄。行號以該 SHA 的檔案為準。

## Skill 清單

repo 把 skill 分成五個 bucket：`engineering/`、`productivity/` 為 promoted（出貨在 plugin 內），`misc/`、`in-progress/`、`deprecated/` 不出貨（`AGENTS.md:3-9`）。`plugin.json` 的 `skills` 陣列列出 27 個 promoted skill（`.claude-plugin/plugin.json:21-49`）。

invocation 分兩種：user-invoked 只有人類打 `/name` 才能觸發，frontmatter 設 `disable-model-invocation: true`，description 給人看、不放觸發詞；model-invoked 則 model 或 user 都能觸發，description 帶觸發詞（`.agents/invocation.md:5-6`）。下表「觸發」欄：U = user-invoked，M = model-invoked。M 類的觸發詞取自 frontmatter description。

### engineering（promoted）

| Skill | 觸發 | 說明 | 出處 |
| --- | --- | --- | --- |
| ask-matt | U | 路由器，問「哪個 skill / flow 適合我的情境」 | `skills/engineering/ask-matt/SKILL.md:3-4` |
| grill-with-docs | U | 訪談式 grilling，同時建立 `GLOSSARY.md` 與 ADR | `skills/engineering/grill-with-docs/SKILL.md:3-4` |
| triage | U | 將 issue / 外部 PR 依 triage role 狀態機推進，寫 agent brief | `skills/engineering/triage/SKILL.md:3-4` |
| improve-codebase-architecture | U | 掃描 deepening 機會，輸出 HTML 報告，再 grill 選中的項目 | `skills/engineering/improve-codebase-architecture/SKILL.md:3` |
| setup-matt-pocock-skills | U | 每個 repo 跑一次，設定 issue tracker、triage labels、domain doc 版型 | `README.md:223`；`skills/engineering/setup-matt-pocock-skills/SKILL.md` |
| to-spec | U | 把當前對話整理成 spec 並發佈到 issue tracker，不再訪談 | `skills/engineering/to-spec/SKILL.md:3-4` |
| to-tickets | U | 把 plan / spec 拆成 tracer-bullet tickets，各自宣告 blocking edges | `skills/engineering/to-tickets/SKILL.md:3-4` |
| implement | U | 依 spec 或 ticket 實作 | `skills/engineering/implement/SKILL.md:3-4` |
| implement-spec | U | 整份 spec 在單一 integration branch 上，以 subagent 平行實作 | `skills/engineering/implement-spec/SKILL.md:3-4` |
| wayfinder | U | 把一個 session 裝不下的大工作畫成 decision tickets 的 map，逐張解決 | `skills/engineering/wayfinder/SKILL.md:3-4` |
| retro | U | session 回顧，建議改善 agent 的環境 | `skills/engineering/retro/SKILL.md:3-4` |
| prototype | M | 拋棄式 prototype 回答一個設計問題。觸發：sanity-check state model / logic、探索 UI 長相 | `skills/engineering/prototype/SKILL.md:3` |
| diagnosing-bugs | M | 難 bug / 效能退化的診斷迴圈。觸發：「diagnose」「debug this」、壞掉 / throwing / failing / slow | `skills/engineering/diagnosing-bugs/SKILL.md:3` |
| research | M | 針對 primary sources 調查問題，產出 Markdown。觸發：要查主題、收集 docs / API 事實、把閱讀工作外包給 background agent | `skills/engineering/research/SKILL.md:3` |
| tdd | M | red-green-refactor。觸發：test-first 建功能或修 bug、提到「red-green-refactor」、要 integration tests | `skills/engineering/tdd/SKILL.md:3` |
| domain-modeling | M | 建立並磨利 domain model。觸發：討論程式碼術語、寫或改 `GLOSSARY.md`、記錄或改 ADR | `skills/engineering/domain-modeling/SKILL.md:3` |
| codebase-design | M | deep module 的共用詞彙。觸發：設計 / 改善 module interface、找 deepening 機會、決定 seam 位置 | `skills/engineering/codebase-design/SKILL.md:3` |
| code-review | M | 以固定基準點雙軸 review（Standards + Spec），平行 sub-agent。觸發：review branch / PR、「review since X」 | `skills/engineering/code-review/SKILL.md:3` |
| pr | M | 撰寫 PR body 的形狀。觸發：「Use when writing a PR body」 | `skills/engineering/pr/SKILL.md:3` |
| wizard | M | 產生互動 bash wizard，帶人類走完只有人能做的步驟。觸發：佈建基礎設施、設定憑證 / CI secrets、操作第三方 dashboard、一次性 migration / cutover | `skills/engineering/wizard/SKILL.md:3` |

U / M 的分類依 `README.md:217-241` 的 User-invoked / Model-invoked 清單。

### productivity（promoted）

| Skill | 觸發 | 說明 | 出處 |
| --- | --- | --- | --- |
| grill-me | U | 無 repo 情境的 grilling，stateless | `skills/productivity/grill-me/SKILL.md:3-4`；`skills/engineering/ask-matt/SKILL.md:85` |
| handoff | U | 將對話壓成 handoff 文件給另一個 agent | `skills/productivity/handoff/SKILL.md:3-5` |
| teach | U | 跨 session 教使用者新概念，以當前目錄為教學 workspace | `skills/productivity/teach/SKILL.md:3` |
| to-questionnaire | U | 把自己答不了的決策轉成問卷給能回答的人 | `skills/productivity/to-questionnaire/SKILL.md:3` |
| wait-what | U | 訊息沒傳達到時，以 `GLOSSARY.md` 詞彙重講一次 | `skills/productivity/wait-what/SKILL.md:3` |
| grilling | M | 訪談原語。觸發：stress-test 想法、任何 'grill' 觸發詞 | `skills/productivity/grilling/SKILL.md:3` |
| writing-for-agents | M | 寫給 agent 讀的文件。觸發：建立或編輯 skill、改 AGENTS.md / CLAUDE.md | `skills/productivity/writing-for-agents/SKILL.md:3` |

### 不出貨的 bucket

- `in-progress/`（beta，不在 plugin 與 top-level README，可用 `npx skills@latest add mattpocock/skills --skill=<name>` 單獨安裝）：loop-me、writing-beats、writing-fragments、writing-shape、claude-handoff、setup-ts-deep-modules、software-factory（`skills/in-progress/README.md:1-16`）。另有 chief-of-staff 目錄存在，但未列在該 README。
- `misc/`（凍結、不維護）：git-guardrails-claude-code、migrate-to-shoehorn、scaffold-exercises、setup-pre-commit（`skills/misc/README.md:1-8`；`SCOPE.md:17`）。
- `deprecated/`：目前為空，被淘汰的 skill 直接刪除（`skills/deprecated/README.md:3`）。

## Workflow 圖與 hand-off

### 作者對流程的總述

`ask-matt` 是官方路由，定義了「一條 main flow 加兩個 on-ramp」：

> "A **flow** is a path through the skills. Most paths run along one **main flow**, and two **on-ramps** merge onto it. Everything else is standalone, or a vocabulary layer that runs underneath."
> （`skills/engineering/ask-matt/SKILL.md:13`）

註：該段說「兩個 on-ramps」，但 "On-ramps" 一節實際列了三項（triage、diagnosing-bugs、wayfinder，`ask-matt/SKILL.md:44-54`），repo 內文字不一致。

### Main flow：idea → ship（`ask-matt/SKILL.md:15-34`）

1. `/grill-with-docs`：「sharpens the idea by interview. Start here whenever you are **working in a working directory**」（`:19`）。
2. 分支：問題需要可執行的答案（state、business logic、要看的 UI）時繞道 prototype，用 `/handoff` 雙向橋接（`:20-23`）。
3. 分支：是否為多 session 的建置（`:24-30`）。
   - 是：`/to-spec` → `/to-tickets` → `/implement`（每張 ticket 之間 `/clear`）或 `/implement-spec`（整份 spec 一次跑）。
   - 否：「`/implement` right here, in the same context window」（`:29`）。
4. 建置過程由 `/tdd` 驅動，收尾 `/code-review`：「Either way, the code gets built by driving **`/tdd`** (one red-green slice at a time) and closes out with **`/code-review`**」（`:30`）。
5. 開 PR 時 `/pr` 規範 body（model-invoked，agent 寫 PR 時自己取用）（`:32`）。
6. `/retro` 收尾：「closes the loop. After a build, and especially one that went sideways, it looks back over the session and suggests changes to the agent's **environment**, not the code」（`:34`）。

### On-ramp 與其他流向

- Bugs / requests 堆積：`/triage`，產出 agent-ready issue，「which **`/implement`** later picks up」（`:46`）。`/to-tickets` 產出的 ticket 已是 agent-ready，「don't triage them」（`:48`）。
- 東西壞了：`/diagnosing-bugs`，修完在同 session 跑 `/retro`；若真正發現是缺少可鎖住 bug 的 seam，交給 `/improve-codebase-architecture`（`:50`）。
- 巨大模糊的工作：`/wayfinder`（`:52`）。收斂後的 hand-off 原文：「When the map clears, **it hands off, it doesn't build**: merge onto the main flow at **`/to-spec`**, which collapses the map's linked decisions into a buildable plan, then `/to-tickets` and `/implement` as usual.」（`:54`）
- Codebase health：`/improve-codebase-architecture`「picking one _generates an idea_ you can take into the main flow at `/grill-with-docs`」（`:60`）。
- `/research`：「The file it produces is something to take *into* the main flow at `/grill-with-docs`, since research feeds the thinking rather than replacing it.」（`:88`）
- `/to-questionnaire`：「What comes back is material for `/grill-with-docs` or `/to-spec`.」（`:89`）

### Mermaid 圖

```mermaid
flowchart TD
  subgraph onramps[On-ramps / 輸入]
    TRIAGE[/triage/] -->|agent-ready issue| IMPL
    DIAG[/diagnosing-bugs/] -->|fix + regression test| RETRO
    DIAG -.->|no good seam| ICA[/improve-codebase-architecture/]
    WAY[/wayfinder/] -->|map clears| SPEC
    ICA -->|picked candidate = idea| GRILL
    RES[/research/] -->|cited .md| GRILL
    QUES[/to-questionnaire/] -->|answers| GRILL
    QUES -->|answers| SPEC
  end
  GRILL[/grill-with-docs/<br/>grilling + domain-modeling] -->|needs runnable answer| HO1[/handoff/]
  HO1 --> PROTO[/prototype/]
  PROTO --> HO2[/handoff/ back] --> GRILL
  GRILL -->|multi-session| SPEC[/to-spec/]
  SPEC --> TICKETS[/to-tickets/]
  TICKETS --> IMPL[/implement/ per ticket]
  TICKETS --> IMPLS[/implement-spec/ whole spec]
  GRILL -->|small| IMPL
  IMPL -->|calls| TDD[tdd]
  IMPLS -->|subagents call| TDD
  IMPL -->|calls| CR[code-review]
  IMPLS -->|once on integration branch| CR
  CR --> PR[pr]
  PR --> RETRO[/retro/]
```

### Skill 之間的明確呼叫（operative hand-off）

這些是 SKILL.md 內的操作指令，慣例是明寫 "Call the Skill tool with ..."。

| 呼叫方 → 被呼叫方 | 原文 | 出處 |
| --- | --- | --- |
| grill-with-docs → grilling + domain-modeling | "Call the Skill tool twice, for "grilling" and "domain-modeling"." | `grill-with-docs/SKILL.md:7` |
| grill-me → grilling | "Call the Skill tool with "grilling"." | `grill-me/SKILL.md:7` |
| implement → tdd | "Call the Skill tool with "tdd" where possible, at pre-agreed seams." | `implement/SKILL.md:11` |
| implement → code-review | "Once done, call the Skill tool with "code-review" to review the work." | `implement/SKILL.md:15` |
| implement-spec → tdd（每個 implementer subagent） | "calls the Skill tool with `tdd` to build the ticket" | `implement-spec/SKILL.md:31` |
| implement-spec → code-review | "call the Skill tool with `code-review` on the integration branch" | `implement-spec/SKILL.md:38` |
| wayfinder → grilling + domain-modeling | "Call the Skill tool twice, for "grilling" and "domain-modeling", to pin down what this map is finding its way to" | `wayfinder/SKILL.md:111` |
| wayfinder → research（subagent） | "spin up a subagent with a fresh context window that calls the Skill tool with "research"" | `wayfinder/SKILL.md:115` |
| wayfinder → prototype | "by calling the Skill tool with "prototype"" | `wayfinder/SKILL.md:78` |
| triage → grilling + domain-modeling | "call the Skill tool twice, for "grilling" and "domain-modeling"" | `triage/SKILL.md:76` |
| improve-codebase-architecture → codebase-design / grilling / domain-modeling | 見 :13、:64、:66、:71 各行 | `improve-codebase-architecture/SKILL.md:13,64,66,71` |
| tdd → codebase-design | "call the Skill tool with "codebase-design" for the vocabulary" | `tdd/SKILL.md:26` |
| retro → writing-for-agents | "Call the Skill tool with `writing-for-agents` for the writing style guide." | `retro/SKILL.md:11` |

沒有任何 skill 以 Skill tool 呼叫 `to-spec`、`to-tickets`、`implement`、`prototype`（從 main flow）等 user-invoked skill。`to-spec`、`to-tickets` 只在文字上互相銜接（見下節規則）。

### 跨 skill 呼叫的規則

- 「A user-invoked skill may invoke model-invoked skills, but it can never reach another user-invoked skill.」（`.agents/invocation.md:8`；`README.md:211`）
- 前置條件是 user-invoked skill 時，寫成叫人類去跑，不是 Skill tool 呼叫：「tell the user to run `/setup-matt-pocock-skills`」（`.agents/invocation.md:22`；實例 `to-spec/SKILL.md:9`、`to-tickets/SKILL.md:11`、`code-review/SKILL.md:13`）。
- Skill tool 一次只能叫一個 skill，需要兩個就寫「twice」（`.agents/invocation.md:20`）。
- 因為 user-invoked 之間不能互叫，main flow 的 grill → to-spec → to-tickets → implement 實際上是由人類依序輸入指令，連結靠 context window 延續，不靠程式化 hand-off。`ask-matt` 明說：「Keep steps 1–3 in **one unbroken context window** (don't compact or clear until after `/to-tickets`)」（`ask-matt/SKILL.md:38`）。

### Phase boundary 規則

在 phase 之間有五個選項：Continue、`/clear`、`/handoff`、subagent、`/compact`（`ask-matt/SKILL.md:71-77`；`ask-matt/PHASE-BOUNDARIES.md:7-15`）。判斷樹依序問：能否 continue（grilling → implementation 是標準的 yes）、context 是否可棄、是否需要 handoff（新 harness / 新目錄 / 同事 / mid-phase 分叉）、能否 AFK 丟給 subagent、否則 `/compact`（`PHASE-BOUNDARIES.md:19-40`）。smart zone 約 150k tokens（`ask-matt/SKILL.md:40`）。

## Artifacts

| Skill | 讀 / 寫 | 位置與命名 | 出處 |
| --- | --- | --- | --- |
| setup-matt-pocock-skills | 寫 | `docs/agents/issue-tracker.md`、`docs/agents/domain.md`、`docs/agents/triage-labels.md`（僅裝了 triage 時）；並在 `CLAUDE.md` 或 `AGENTS.md` 加 `## Agent skills` 區塊（已有哪個就改哪個） | `setup-matt-pocock-skills/SKILL.md:49,67-86,108-116` |
| domain-modeling / grill-with-docs | 讀寫 | `GLOSSARY.md`（repo 根；多 context 時為根目錄 `GLOSSARY-MAP.md` 加各 context 自己的 `GLOSSARY.md`）。ADR 在 `docs/adr/NNNN-slug.md`。皆 lazy 建立 | `domain-modeling/SKILL.md:10-40`；`domain-modeling/ADR-FORMAT.md:3-5` |
| GLOSSARY.md 限制 | | 「totally devoid of implementation details」，不是 spec、不是 scratch pad | `domain-modeling/SKILL.md:64` |
| ADR 門檻 | | 三條件全中才提議：hard to reverse、surprising without context、real trade-off | `domain-modeling/SKILL.md:66-74` |
| to-spec | 寫 | 發佈到 issue tracker 並貼 `ready-for-agent` label。本地 tracker 為 `.scratch/<feature-slug>/spec.md`。範本含 Problem Statement / Solution / User Stories / Implementation Decisions / Testing Decisions / Out of Scope / Further Notes | `to-spec/SKILL.md:19-73`；`issue-tracker-local.md:8` |
| to-tickets | 寫 | 本地：`.scratch/<feature-slug>/issues/<NN>-<slug>.md`，從 `01` 起依依賴順序編號，一票一檔；真 tracker：一票一 issue，用原生 blocking link，貼 `ready-for-agent` | `to-tickets/SKILL.md:62-63`；`issue-tracker-local.md:9` |
| implement-spec | 寫 | integration branch、各 implementer 的 worktree + branch；exploration subagent 的 markdown 筆記存 repo 外、讓後續 subagent 共用；可選開 draft PR | `implement-spec/SKILL.md:25-27,29` |
| research | 寫 | 單一 Markdown 檔，逐條引用來源；存「repo 既有放這類筆記的地方」，沒慣例就挑個合理位置並說明。skill 本身不指定路徑 | `research/SKILL.md:10-12`；`docs/engineering/research.md:41` |
| research（在 wayfinder 內） | 寫 | 發現存在拋棄式 `research/<name>` branch，push 但不開 PR、永不 merge，ticket 以 context pointer 指向 | `wayfinder/SKILL.md:115` |
| prototype | 寫 | 就近放在要使用它的 module / page 旁並明確命名為 prototype；logic 型為單一可雙擊的 HTML，UI 型為單一 route 上多個變體（`/prototype/<name>` 掛 switcher）。完成後把驗證過的決策併回真實程式碼，prototype 本身 commit 到 `prototype/<name>` branch（不進 main），並在 implementation issue 留 pointer | `prototype/SKILL.md:21,24-25,29`；`prototype/UI.md:75`；`ask-matt/SKILL.md:87` |
| wayfinder | 寫 | map 是 label `wayfinder:map` 的單一 issue（Destination / Notes / Decisions so far / Not yet specified / Out of scope）；ticket 是其 child issue，label `wayfinder:<type>`；本地：`.scratch/<effort>/map.md` 與 `.scratch/<effort>/issues/NN-<slug>.md`（`Type:`、`Status: claimed/resolved`、`Blocked by:` 行） | `wayfinder/SKILL.md:21,31-52,65`；`issue-tracker-local.md:23-30` |
| handoff | 寫 | 系統 temp 目錄（`$TMPDIR`，否則 `/tmp`），不放 workspace；內含 "suggested skills" 段；已存在於 spec / plan / ADR / issue / commit 的內容用路徑或 URL 引用，不重複 | `handoff/SKILL.md:8-12` |
| improve-codebase-architecture | 寫 | 自足 HTML 報告，寫在 OS temp 目錄 `<tmpdir>/architecture-review-<timestamp>.html`，不進 repo | `improve-codebase-architecture/SKILL.md:39` |
| triage | 寫 | issue comment（開頭必須有 AI disclaimer）；agent brief；被拒的需求寫進 `.out-of-scope/` 知識庫 | `triage/SKILL.md:13-17,79,83`；`triage/AGENT-BRIEF.md`；`triage/OUT-OF-SCOPE.md` |
| teach | 寫 | 在執行目錄下建立教學 workspace；每課一個 HTML，存 `./lessons/`，命名 `0001-<dash-case-name>.html`；另有 GLOSSARY / LEARNING-RECORD / MISSION / RESOURCES 格式檔 | `teach/SKILL.md:12,49`；`productivity/teach/*-FORMAT.md` |
| code-review | 讀 | 找 spec 的順序：commit message 中的 issue 參照 → 使用者給的路徑 → `docs/`、`specs/`、`.scratch/` 下符合 branch 名的檔案 → 問使用者。standards 來源：`CODING_STANDARDS.md`、`CONTRIBUTING.md` 等 | `code-review/SKILL.md:25-36` |
| retro | 讀 | 讀 session logs；建議改 `CLAUDE.md`/`AGENTS.md`（只放 navigation pointers）、`CODING_STANDARDS.md`（review 時讀，非實作時讀）、docs、skills | `retro/SKILL.md:13,39-44` |

repo 自己的 `GLOSSARY.md` 在根目錄，另有 `.changeset/`、`docs/<bucket>/<skill>.md`（人類導向的說明頁，每頁四節：What it does / When to reach for it / Common questions / It's working if，`AGENTS.md:17`）。

## HITL 與 AFK

wayfinder 的 "Ticket Types" 一節是 repo 中對這個區分最明確的定義：

> "Every ticket is either **HITL** (human in the loop, worked _with_ a human who speaks for themselves) or **AFK**, driven by the agent alone. A HITL ticket only resolves through that live exchange; the agent never stands in for the human's side of it (a grilling agent that answers its own questions has broken this)."
> （`wayfinder/SKILL.md:75`）

| Ticket / skill | 模式 | 出處 |
| --- | --- | --- |
| research | AFK，「Resolved by a subagent」 | `wayfinder/SKILL.md:77` |
| prototype | HITL，目的是「Raise the fidelity of the discussion」 | `wayfinder/SKILL.md:78` |
| grilling | HITL，「Conversation. The default case.」 | `wayfinder/SKILL.md:79` |
| task | HITL 或 AFK：能自己做就 AFK，否則給人一份精確 checklist | `wayfinder/SKILL.md:80` |

其他相關描述：

- research 本身設計成背景執行：「Spin up a **background agent** to do the research, so you keep working while it reads. Start it with a fresh context window.」（`research/SKILL.md:6`）。docs 頁稱它是「legwork you delegate, not thinking you outsource」（`docs/engineering/research.md:25`）。
- grilling 的分工：「Finding _facts_ is your job, never the user's」，事實由 fresh-context sub-agent 去查，且不阻塞其餘問題；「The _decisions_ are the user's」（`grilling/SKILL.md:28`）。
- grilling 結束條件：frontier 為空，且「Do not act on it until the user confirms you have reached a shared understanding.」（`grilling/SKILL.md:30`）。
- ticket 層面：`ready-for-agent` = 「fully specified, ready for an AFK agent」，`ready-for-human` = 「needs human implementation」（`triage/SKILL.md:35-36`）。
- Phase boundary 第四題用 AFK 判斷是否丟給 subagent：「Is it scoped tightly enough to run with you away from the keyboard, no steering? Then send it to a **subagent**」（`PHASE-BOUNDARIES.md:36`）。
- `implement-spec` 的 implementer 以 background 平行跑（`implement-spec/SKILL.md:19`）；`code-review` 兩個 sub-agent 以前景平行發出（`code-review/SKILL.md:60`）。
- `wizard` 專門處理人類才能做的步驟，並說「If the agent could just do it itself, it should」（`ask-matt/SKILL.md:90`）。
- `wayfinder` 單一 session 只解一張 ticket，research 除外（`wayfinder/SKILL.md:105`）。
- 已知問題：research 的 background agent 可能再生出 agent（open issue #530，`docs/engineering/research.md:33-35`）。

## 作者陳述的設計原則

- 反對流程擁有者：「Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.」（`README.md:17`）
- 「These skills are designed to be small, easy to adapt, and composable. They work with any model.」（`README.md:19`）
- 定位：「My agent skills that I use every day to do real engineering - not vibe coding.」（`README.md:15`）
- 失敗模式一（沒做對的東西）：「The most common failure mode in software development is misalignment.」解法是 grilling session，「Use them _every_ time you want to make a change.」（`README.md:119-128`）
- 失敗模式二（太囉嗦）：解法是 shared language（`GLOSSARY.md`），「It might be the single coolest technique in this repo.」（`README.md:138-158`）
- 失敗模式三（程式碼不能跑）：feedback loop，red-green-refactor 是關鍵（`README.md:173-183`）。引用 Pragmatic Programmer：「The rate of feedback is your speed limit.」（`README.md:169`）
- 失敗模式四（泥球）：「caring about the design of the code」；`/to-spec` 會在建 spec 前盤問你動到哪些 module（`README.md:197-201`）；建議每幾天跑一次 `/improve-codebase-architecture`（`README.md:203`）。
- 新增 skill 的門檻：「if you can compose the behaviour from existing skills, it does not get a new skill」（`.out-of-scope/new-skills.md`，"Why this is out of scope" 第二段）。收 issue 的標準：必須是真實 session 的「Observed failure」，且符合 philosophy（`SCOPE.md:7-10`）。
- wayfinder 預設只做規劃：「produce decisions, not deliverables」（`wayfinder/SKILL.md:13`）。它被定位為「situational on-ramp, not the new main entry flow」（`CHANGELOG.md:293`）。
- 跨 skill 依賴寫成明確的 "call the Skill tool"，不寫深層 `../other-skill/FILE.md` 路徑，也不留一個裸的 `/skill` 讓 model 自己猜（`.agents/invocation.md:16`）。
- retro 的核心主張：實作 agent 有最大的 context pressure，所以標準應由 review agent 施加（`retro/SKILL.md:31-35`）；機械性違規做成 deterministic check，只有判斷性規則才寫進 `CODING_STANDARDS.md`（`retro/SKILL.md:19`）。
- 每個派 subagent 的 skill 都要寫「start with a fresh context window」，因為部分 harness（如 Codex）預設 fork 父對話（`AGENTS.md:27`）。
- glossary 與 ADR 的長期價值論述：ADR 要保留、其他 research 筆記完成後宜 archive 或 delete，因為過期筆記比沒有更糟（`docs/engineering/research.md:41`，引用社群意見；作者本人的結論被截斷在該行之後，未再追）。

## 安裝與發佈

- Claude Code：`claude plugin install mattpocock-skills@claude-plugins-official`，預設自動更新（`README.md:34-38`）。這是 Claude 官方 marketplace 收錄的版本，listing 以 git URL 加 pinned sha 指向本 repo，直接讀 `.claude-plugin/plugin.json`（`.agents/adr/0002-ship-as-a-claude-code-plugin.md:32-40`）。
- repo 本身也是單一 plugin 的 marketplace（`name: mattpocock`，plugin `mattpocock-skills`，`source: ./`）（`.claude-plugin/marketplace.json:2,10-11`），作為直接安裝未發佈 commit 或 fork 的備援（ADR 0002 `:34`）。
- Codex：`codex plugin marketplace add mattpocock/skills` 再 `codex plugin add mattpocock-skills@mattpocock`（`README.md:46-48`）。
- GitHub Copilot（CLI 與 VS Code）：`copilot plugin marketplace add mattpocock/skills`（`README.md:58-59`）。
- Gemini CLI：`gemini skills install <url> --path skills/engineering` 與 `--path skills/productivity`（`README.md:80-81`）。
- 其他 agent / 可編輯副本：`npx skills@latest add mattpocock/skills -a <agent>`，安裝時要勾 `setup-matt-pocock-skills`；更新用 `npx skills@latest update`（`README.md:92-95`）。skills.sh 複製可編輯檔到專案，plugin 自動更新，兩者擇一否則每個 skill 會裝兩次（`README.md:27`）。
- 安裝後每個 repo 跑一次 `/setup-matt-pocock-skills`（`README.md:99-105`）。
- plugin 只出貨 promoted 的 27 個 skill，`plugin.json` 以顯式目錄陣列選取（`plugin.json:21-49`）。選擇陣列的原因是 bucket 結構下需要跨兩個資料夾挑選（ADR 0002 `:11`）。ADR 0002 的 2026-10-07 更新指出 Codex 現已接受 `skills` 陣列並在無 `.codex-plugin/` 時回退讀 `.claude-plugin/`（`:45`）。
- 每個 skill 另帶 `agents/openai.yaml`，放 Codex UI metadata，user-invoked 的另加 `policy.allow_implicit_invocation: false`（`.agents/invocation.md:10`）。
- 版本同步：`plugin.json` 的 `version` 與 `package.json` 同步，由 `scripts/sync-plugin-version.mjs` 處理（ADR 0002 `:28,53`）。

## 觀察

- 沒有任何機制強制 skill 的順序。main flow 的銜接全部依賴人類依序輸入 user-invoked 指令，加上 `ask-matt` 這份路由文件（`.agents/invocation.md:8`；`ask-matt/SKILL.md:9`）。程式化的 hand-off 只存在於「user-invoked → model-invoked」方向（見上方呼叫表）。
- 狀態全部落在檔案或 issue tracker：`GLOSSARY.md`、`docs/adr/`、`.scratch/`、tracker 上的 issue 與 label。沒有類似 `status.yaml` 的 phase 狀態檔；ticket 狀態靠 label 或 `Status:` 行（`issue-tracker-local.md:10`）。
- 沒有 design / plan 階段的獨立 skill。「設計」由 `grill-with-docs`（對話）加 `to-spec`（定稿）承擔，「plan」由 `to-tickets` 承擔（`ask-matt/SKILL.md:25`）。
- review 分在兩處：建置時由 `/implement` / `/implement-spec` 內建呼叫 `code-review`（`implement/SKILL.md:15`；`implement-spec/SKILL.md:38`），事後改善環境由 `retro`。`code-review` 的 Spec 軸是檢查實作對 spec 的步驟（`code-review/SKILL.md:8-9`）。
- repo 內搜尋 `superpowers` 無任何結果（全 repo grep），未引用該 plugin。唯一提到外部流程框架的是 README 把 GSD、BMAD、Spec-Kit 當作對照（`README.md:17`）。
- `ask-matt/SKILL.md:13` 說兩個 on-ramp，實際列出三項（`:44-54`）。
- 歷史改名（皆在 `CHANGELOG.md`）：`to-prd` → `to-spec`（`:252`）、`to-issues` → `to-tickets`（`:283` 仍用舊名，`:39` 起用新名）、`diagnose` → `diagnosing-bugs`（`:354`）、`decision-mapping` → `wayfinder`（`:297`）、`writing-great-skills` → `writing-for-agents`（`:192`）、`CONTEXT.md` / `CONTEXT-MAP.md` → `GLOSSARY.md` / `GLOSSARY-MAP.md`（`:77`）。

## 與 Beat 的對照

Beat 目前引用的 mattpocock skill 名稱在該 SHA 皆存在：`grill-with-docs`（`skills/engineering/grill-with-docs/SKILL.md`）、`research`（`skills/engineering/research/SKILL.md`）、`prototype`（`skills/engineering/prototype/SKILL.md`）、`retro`（`skills/engineering/retro/SKILL.md`）、`wayfinder`（`skills/engineering/wayfinder/SKILL.md`）；其中 `grill-with-docs`、`retro`、`wayfinder` 為 user-invoked，`research`、`prototype` 為 model-invoked；Beat 的 `beat/CONTEXT.md` 對應 mattpocock 已改名的 `GLOSSARY.md`（`CHANGELOG.md:77`）。
