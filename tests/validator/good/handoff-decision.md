# D1: 綁 credential 還是 backend？
來源：design Key Decision 2
影響：綁 credential 則換 credential 就換 model
選項：
  A. credential — 後果：Settings 多一欄
  B. backend — 後果：per-task pin 做不到
傾向：A，因為需求就是 per-task pin
擋住：design 的 schema 段落

## Beat Handoff
change: slack-thread-dedupe   phase: design   preset: standard
commit: 3f9c1a2   branch: feat/dedupe   dirty: no
decision: D1   sensitive: yes   diverging: no
next: /beat:design slack-thread-dedupe
blocked-on: decision — model binding layer
