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
- **Print it before the handoff block.** The orchestrator takes the run's last message as the gate question, so the brief must be in that message, in full, immediately above `## Beat Handoff`.

## After the answer

The reply arrives as the first message of the re-run phase. The skill:

1. Records the answer in the brief file under a `結論：` / `Outcome:` line.
2. Writes it where it belongs: the issue's locked-decisions section when the skill can reach the issue, `design.md` Key Decisions always, and `docs/adr/` when the ADR three-condition gate holds.
3. Continues the phase from where it stopped. It does not re-ask, and it does not run the gate on the same decision again.

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
