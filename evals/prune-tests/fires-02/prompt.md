---
tags: [trigger, prune-tests]
runs: 3
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

E2E で確かめなくていいことまで Playwright で書いてあって、逆にユニットで書くべきでない配線のテストもある気がする。どのテストをどの層へ移すべきか洗い出したい
