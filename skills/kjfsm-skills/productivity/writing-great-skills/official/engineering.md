# Anthropic Engineering の既読台帳

AI に読ませる文書の書き方に関わる記事だけを載せる。**仕分け済みの範囲に入っていて、ここに無い記事は、読んだうえで対象外と判断したもの**である — もう一度開かない。範囲より新しい記事は未読である。

- **要約は開くかどうかを決めるためのもの。** 従う規則は `OFFICIAL.md` の本文にあり、キーはそこの引用キーである。キーが空の行は、まだ `OFFICIAL.md` に取り込んでいない
- **2026年より前の記事は slug だけ残す。** 載っていること自体が「読んだ・関連あり」を表す
- **仕分けるとき:** 一覧ページで仕分け済みの範囲より新しい記事をタイトルで振り分け、判断がつかないものだけ本文を開く。関連する記事を表に足し、範囲の日付を書き換える

URL は `https://www.anthropic.com/engineering/<slug>`。仕分け済み: **2026-05-25 公開分(how-we-contain-claude)まで全件**。一覧にある `claude-code-best-practices` は docs への転送で、実体は `OFFICIAL.md` の `cb` である。

| 公開日     | slug                             | キー | 何が書いてあるか                                                                                        |
| ---------- | -------------------------------- | ---- | ------------------------------------------------------------------------------------------------------- |
| 2026-04-23 | april-23-postmortem              |      | system prompt に「発言は25語以内」のような長さの制限を足したら、精度が3%落ちた実例                      |
| 2026-03-24 | harness-design-long-running-apps |      | 評価役への採点基準を、主観的な判断から採点できる文へ言い換える(4つの基準と few-shot での校正)           |
| 2026-02-05 | building-c-compiler              |      | Claude に読ませるテスト・ログ出力の設計: ERROR を同じ行に置いて grep 可能に、要約統計を先に計算しておく |

2026年より前: effective-harnesses-for-long-running-agents `lh`, advanced-tool-use, code-execution-with-mcp, equipping-agents-for-the-real-world-with-agent-skills `eq`, effective-context-engineering-for-ai-agents `ce`, writing-tools-for-agents `wt`, multi-agent-research-system, claude-think-tool, swe-bench-sonnet, building-effective-agents
