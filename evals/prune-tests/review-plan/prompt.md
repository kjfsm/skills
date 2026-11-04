---
tags: [uplift, prune-tests]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

テストが 300 ファイルほどある。vitest に node と http の2プロジェクト、別に Playwright の E2E がある。被っているテストを消して、層が間違っているものを移して、足りないテストも洗い出したい。サブエージェントに分担させるとして、テストファイルをどう分けて渡し、何を報告させればいい? まだ何も消さず、分析だけしたい。
