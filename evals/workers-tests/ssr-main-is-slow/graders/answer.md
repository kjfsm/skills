---
type: llm
---

PASS if the answer says the cost comes from `main` (the SSR app's module graph being transformed/booted), not from the migrations themselves, and proposes pointing a bindings-only test project at a tiny stand-in `main` Worker (or a prebuilt bundle) instead of the SSR entry.
FAIL if it accepts that the migrations are the bottleneck and only suggests caching, batching, or parallelising them.
