---
tags: [uplift, d1-bound-parameters]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

Drizzle で D1 に対して inArray(users.id, ids) を 500 件の id で投げたら D1_ERROR: too many SQL variables で落ちた。どう書き直すのがいい?
