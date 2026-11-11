---
tags: [trigger, fix-on-integration-branch]
runs: 3
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

レビューで出た一覧の B1〜B20 と K1〜K8 を、寝ている間にまとめて直しておいて。develop ブランチを作って、PR は確かめたら develop にマージしてよい。main には入れないで。
