---
type: llm
---

PASS if the answer mentions at least two of: the package was renamed to @cloudflare/vitest-plugin (a codemod exists); defineWorkersProject was replaced by the cloudflareTest() plugin; storage/Durable Object isolation changed from per-test to per-test-file, so reuse of the same idFromName leaks state (fix with unique names or reset()/abortAllDurableObjects()).
FAIL if it names none of these changes.
