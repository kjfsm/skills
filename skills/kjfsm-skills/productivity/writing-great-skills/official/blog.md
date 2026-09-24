# 公式ブログの既読台帳

AI に読ませる文書の書き方に関わる記事だけを載せる。**仕分け済みの範囲に入っていて、ここに無い記事は、読んだうえで対象外と判断したもの**である — もう一度開かない。範囲より新しい記事は未読である。

- **要約は開くかどうかを決めるためのもの。** 従う規則は `OFFICIAL.md` の本文にあり、キーはそこの引用キーである。キーが空の行は、まだ `OFFICIAL.md` に取り込んでいない。`—` は読んだうえで、取り込む新しい事実が無かった(既存の項目の裏づけ、対象の範囲外、古いモデル向け)もの
- **2026年より前の記事は slug だけ残す。** 載っていること自体が「読んだ・関連あり」を表す
- **仕分けるとき:** 一覧ページで仕分け済みの範囲より新しい記事をタイトルで振り分け、判断がつかないものだけ本文を開く。関連する記事を表に足し、範囲の日付を書き換える。同じ日付の記事は slug で表と照合する

## claude.com/blog

URL は `https://claude.com/blog/<slug>`(`hc` `se` `cm` `pe` は `OFFICIAL.md` が日本語版 `/ja/blog/` を引いている)。仕分け済み: **2026-09-23 公開分まで全件**

| 公開日     | slug                                                                             | キー | 何が書いてあるか                                                                                                                  |
| ---------- | -------------------------------------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-23 | how-to-prepare-for-ai-driven-code-modernization-projects                         | md   | 完了条件(certificate)の各項目を人間抜きで判定できる形にし、満たすまで反復させる。問題が出たら個々の変更ではなくワークフローを直す |
| 2026-09-22 | what-a-task-costs-on-opus-5-5                                                    | tc   | effort の選び方、サブエージェントのモデル、prompt-audit の実測                                                                    |
| 2026-09-08 | reducing-cost-and-improving-performance-with-claude-platform                     | rc   | フロンティアモデルで逆効果になる指示の6類型と、外したときの実測(Opus 5.5 で再測定)                                                |
| 2026-08-26 | how-warp-builds-self-improving-agents-on-claude                                  | wp   | 規則より理由を渡す、スキルは手続きで安定・メモリは自動で変わり続ける                                                              |
| 2026-08-21 | the-ai-native-sdlc-playbook                                                      | sd   | CLAUDE.md は1ページ未満、2度間違えたら書く、組織の知識はスキルに                                                                  |
| 2026-08-18 | ai-ci-cd-on-call                                                                 | ct   | 学びを `lessons.md` に書き溜め、繰り返したものをスキルへ昇格させる運用                                                            |
| 2026-08-14 | maximizing-the-value-of-your-claude-code-sessions                                | mx   | CLAUDE.md に置く日常のコマンド、ワークフロー固有の指示はスキルへ                                                                  |
| 2026-07-22 | building-verification-loops-in-claude-code-with-skills                           | vl   | 検証スキルの SKILL.md 実例(`allowed-tools` 込み)、standalone / embedded / chained の3分類、検証ループの埋め込み方                 |
| 2026-07-06 | a-field-guide-to-claude-fable-finding-your-unknowns                              | —    | 曖昧さを埋めるプロンプト例文集(blind spot pass、「1問ずつ訊いて」)                                                                |
| 2026-06-18 | steering-claude-code-skills-hooks-rules-subagents-and-more                       | st   | CLAUDE.md / rules / スキル / フック / サブエージェントの使い分け                                                                  |
| 2026-05-14 | how-claude-code-works-in-large-codebases-best-practices-and-where-to-start       | lb   | ルートの CLAUDE.md は要点と gotcha だけ・局所の規約はサブディレクトリへ、3〜6か月ごとに見直して旧モデル向けの迂回を削る           |
| 2026-04-28 | onboarding-claude-code-like-a-new-developer-lessons-from-17-years-of-development | —    | CLAUDE.md は地図で専門知識はスキルへ、スキルは参照であって埋め込まない                                                            |
| 2026-04-16 | best-practices-for-using-claude-opus-4-7-with-claude-code                        | —    | 最初のターンで意図・制約・受入基準・ファイルの場所を書き切る、否定形より肯定の例が効く(Opus 4.7 時点)                             |
| 2026-04-07 | subagents-in-claude-code                                                         | sg   | サブエージェントの description は役割でなくトリガー条件で書く、CLAUDE.md / スキル / フックの使い分け表                            |
| 2026-04-02 | harnessing-claudes-intelligence                                                  |      | プロンプトは静的を先・動的を後(キャッシュ)、専用ツールにするかは可逆性で決める                                                    |
| 2026-03-05 | skills-explained                                                                 | se   | どの手段に載せるかの使い分け                                                                                                      |
| 2026-03-03 | improving-skill-creator-test-measure-and-refine-agent-skills                     | sc   | スキルを capability uplift と encoded preference に分ける、eval で description の誤発火と不発火を直す、A/B 比較                   |
| 2026-01-23 | building-multi-agent-systems-when-and-how-to-use-them                            | ma   | 依頼文に目的・出力形式・境界を渡す、問題の種類でなく文脈の境界で分ける、ツールが15〜20を超えたら分割を検討                        |
| 2026-01-22 | building-agents-with-skills-equipping-agents-for-specialized-work                | ba   | 3層開示の実測トークン(メタデータ約50 / SKILL.md 約500 / 参照2,000超)                                                              |

2026年より前: extending-claude-capabilities-with-skills-mcp-servers, using-claude-md-files `cm`, how-to-create-skills-key-steps-limitations-and-examples `hc`, improving-frontend-design-through-skills, best-practices-for-prompt-engineering `pe`, scaling-agentic-coding, claude-2-1-prompting

## claude.dev/blog

URL は `https://claude.dev/blog/<slug>/`。仕分け済み: **2026-09-23 公開分まで全件**

| 公開日     | slug                                                                | キー | 何が書いてあるか                                                                              |
| ---------- | ------------------------------------------------------------------- | ---- | --------------------------------------------------------------------------------------------- |
| 2026-09-22 | getting-the-most-out-of-opus-5-5                                    | o5   | 思考の指示を外す、完了の定義、停止と継続のルール、タスク一覧のファイル化                      |
| 2026-07-24 | the-new-rules-of-context-engineering-for-claude-5-generation-models | c5   | 過剰な制約を外す、例より interface 設計、progressive disclosure、CLAUDE.md は gotcha に使う   |
| 2026-06-03 | lessons-from-building-claude-code-how-we-use-skills                 | lc   | Gotchas、トリガーとしての description、最小から育てる、スキルの類型                           |
| 2026-06-02 | a-harness-for-every-task-dynamic-workflows-in-claude-code           | hw   | workflow の JS をスキルのフォルダに置いて SKILL.md から指し、「テンプレートとして扱え」と書く |
| 2026-04-10 | seeing-like-an-agent                                                | —    | ツールを足す閾値を高く保つ、サブエージェントに検索手順を細かく渡して結果だけ返させる          |
