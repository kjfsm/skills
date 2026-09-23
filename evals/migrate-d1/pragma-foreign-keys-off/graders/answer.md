---
type: llm
---

PASS if the answer warns that PRAGMA foreign_keys=OFF has no effect on D1 (inside the migration's transaction), so dropping the parent table cascades and empties the referencing child tables, and says not to apply it as generated (rewrite so the affected rows are saved and restored, and take a restore point / Time Travel bookmark first).
FAIL if it says the generated SQL is safe to apply as-is.
