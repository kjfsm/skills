---
tags: [uplift, workers-tests]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

React Router の SSR アプリを wrangler の main に載せた Worker で、vitest のテストが1ファイルあたり15秒くらいかかる。setup で applyD1Migrations を呼んでいて、D1 のマイグレーションが遅いんだと思う。どう速くすればいい?
