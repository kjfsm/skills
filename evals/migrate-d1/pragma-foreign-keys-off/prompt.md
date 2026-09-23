---
tags: [uplift, migrate-d1]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

drizzle-kit generate が D1 用に出したマイグレーションに PRAGMA foreign_keys=OFF; と、テーブルを作り直す DROP TABLE が入っている。列を NOT NULL にしたいだけなんだけど、このまま wrangler d1 migrations apply --remote で本番に当てていい?
