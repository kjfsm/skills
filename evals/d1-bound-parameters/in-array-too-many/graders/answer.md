---
type: llm
---

PASS if the answer states that D1 allows at most 100 bound parameters per statement and proposes either keeping the id set inside SQL (subquery / INSERT ... SELECT) when the source data is already in the database, or splitting into chunks that fit under the limit, sent together with db.batch().
FAIL if it cites SQLite's default limit (999 or 32766) as the relevant limit, or only suggests raising a limit.
