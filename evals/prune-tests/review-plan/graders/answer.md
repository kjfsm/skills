---
type: llm
---

PASS if the answer both (a) groups the files so that tests of the same production code across all layers (node, http and E2E) go to the same subagent, rather than splitting by directory or by runner, and (b) asks each subagent to report, besides delete/merge candidates, tests placed in the wrong layer and missing tests judged by which realistic bug no test would catch (not by coverage numbers). For (b), saying that the subagent's own definition already holds these criteria and only the file list and output paths are passed counts, as long as layer placement and missing tests are named as things it reports.
FAIL if the split is by directory or by layer, or if missing tests are framed as raising coverage.
