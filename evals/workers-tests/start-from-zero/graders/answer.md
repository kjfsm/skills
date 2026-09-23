---
type: llm
---

PASS if the answer both (a) splits Vitest into separate projects by runtime — a Node project for pure logic and a workerd project (via @cloudflare/vitest-plugin) only for things that need real bindings — and (b) says to pin the timezone at the top level of the config (e.g. process.env.TZ = "UTC"), or explains that test.env.TZ does not take effect.
FAIL if everything is put in the workers pool, or if the timezone is not addressed at all.
