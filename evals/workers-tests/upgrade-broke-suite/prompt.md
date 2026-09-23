---
tags: [uplift, workers-tests]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

@cloudflare/vitest-pool-workers を最新に上げたらテストが大量に壊れた。defineWorkersProject が無いと言われるし、Durable Object のテストで前のテストの状態が残る。何が変わったのか、どう直せばいいか教えて。
