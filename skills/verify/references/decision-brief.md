# Decision Brief

What a skill writes when it has to stop for a human in unattended mode (`references/unattended-mode.md`). The brief is the only thing the human reads before answering, so it has to stand alone: no reference to "the design above", no artifact to open.

## Format

File: `beat/changes/<name>/decisions/D<n>.md`. Ten lines or fewer.

```
# D<n>: <the question, one sentence>
來源：<phase> <where it came up — Key Decision 2 / Task 4 / finding F7>
影響：<what changes depending on the answer, one or two sentences>
選項：
  A. <option> — 後果：<one sentence>
  B. <option> — 後果：<one sentence>
傾向：<A or B>，因為 <one sentence>
擋住：<what cannot proceed until this is answered>
```

Write it in the project's `language` from `beat/config.yaml`; the labels above are the zh-TW form, use `Source / Impact / Options / Leaning / Blocks` for English projects.

## Rules

- **Two or three options, never one.** A brief with one option is a notification, not a decision; take the option and record it in `assumed.md` instead.
- **Every option has a consequence.** The reader compares consequences, not options.
- **State a leaning.** The skill has read everything; the human has read nothing. A brief without a leaning pushes the reading back onto the human.
- **Name what it blocks.** The reader decides how urgently to answer from this line.
- **No file paths or code.** They go stale and they are not what the decision turns on. If a type shape or schema is the decision, inline the minimum (three lines, not a listing).
- **The file is the record.** The handoff block lists the ids in `decision` (`references/handoff-report.md`); a caller that needs the question text reads `decisions/D<n>.md`. Also print each brief in full above the handoff block so a person reading the run sees it.
- **Several decisions, one stop.** When a phase finds more than one, write one file each, print them all, and put every id in the handoff block (`decision: D1,D2`). The human answers them in one reply.

## Plan brief

When `/beat:plan` runs unattended and finds `decisions/sensitive.md` says `yes`, it writes a summary of the plan to `beat/changes/<name>/decisions/P1.md` and prints it above the handoff block, so that whoever reads `sensitive: yes` has something to show a human before apply. Whether to stop there is the caller's decision; the handoff stays `blocked-on: none`, `decision: none`. There is nothing to choose, so the one-option rule does not apply; the brief is a confirmation:

```
# P1: <matched situation, one line>
來源：design 對到 config.yaml sensitive.situations 第 <n> 條 / paths <glob>
決定：<each Key Decision from design.md, one line each>
工作：<each task from tasks.md, one line each>
回覆：continue，或說明要改什麼
```

Ten lines; trim tasks before decisions if it runs long.

The plan brief is not a decision brief: it has no outcome line, it is never listed in the handoff `decision` field, and it does not count as an open brief when a reply is matched. Beat reads no reply to it. "continue" means the caller invokes `/beat:apply`. A change request is text the caller passes to whichever phase it invokes next: `/beat:plan` again to redo the tasks, or `/beat:apply`, which takes it as an instruction from the user.

## After the answer

The reply arrives in the prompt the next time the same phase is invoked (a resumed session or a new one). Beat prescribes no reply syntax: the skill lists the open briefs (files without an outcome line) and matches the reply to them by id (`D1: A`, "D1 選 A，D2 選 B"); a reply that names no id answers the only open brief. A brief the reply does not settle stays open and the run stops on it again. The skill:

1. Records the answer in the brief file under a `結論：` / `Outcome:` line.
2. Writes it into `design.md` Key Decisions, and into `docs/adr/` when the ADR three-condition gate holds. The skill never edits the issue body; recording the answer on the issue is up to whoever relayed it.
3. Continues the phase from where it stopped. It does not re-ask, and it does not run the gate on the same decision again. An ADR for the decision is written now, from the answer, never before it.

## Example

```
# D1: evaluator 的 model 要綁 credential 還是 backend？
來源：design Key Decision 2
影響：綁 credential 則換 credential 就換 model；綁 backend 則同 backend 的所有 Task 共用一個 model
選項：
  A. credential — 後果：Settings 多一欄，prod 現有 Task 要補值
  B. backend — 後果：改一行，但 per-task pin 的需求做不到
傾向：A，因為原始需求就是 per-task pin
擋住：design 的 schema 段落
```
