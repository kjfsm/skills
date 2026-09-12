# 効果的な CLAUDE.md とスキルの書き方(公式、2026-09 時点)

問い: 効果的な `CLAUDE.md` とスキルの書き方。Anthropic の公式ドキュメントとブログを優先し、最新のものに絞る。

調査日: 2026-09-12。数値と仕様は取得時点のもの。[`OFFICIAL.md`](../../skills/productivity/writing-great-skills/OFFICIAL.md)(最終突き合わせ 2026-08-09)と重なる項目は要点だけにとどめ、**その後に出た・動いたもの**は [§5](#5-officialmd-に未反映のもの) に分けてある。

## ソース

| キー  | ソース                                                                                                                                                                                                      | 日付 / 版                   |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `mm`  | [How Claude remembers your project](https://code.claude.com/docs/en/memory)                                                                                                                                 | docs(取得時点)              |
| `bp`  | [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)                                                                                                                            | docs                        |
| `fo`  | [Extend Claude Code](https://code.claude.com/docs/en/features-overview)                                                                                                                                     | docs                        |
| `dc`  | [Debug your configuration](https://code.claude.com/docs/en/debug-your-config)                                                                                                                               | docs                        |
| `cc`  | [Extend Claude with skills](https://code.claude.com/docs/en/skills)                                                                                                                                         | docs                        |
| `pe`  | [Test plugins with evals](https://code.claude.com/docs/en/plugin-evals)                                                                                                                                     | docs, v2.1.269+             |
| `sb`  | [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)                                                                                          | docs                        |
| `od`  | [Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)                                                                                                              | Agent Skills 標準           |
| `c5`  | [The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)                                          | 2026-07-24, T. Shihipar     |
| `st`  | [Steering Claude Code: when to use CLAUDE.md, skills, hooks, and subagents](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more)                                             | 2026-06-18, M. Segner       |
| `lc`  | [Lessons from building Claude Code: How we use skills](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills)                                                                         | 2026-06-03, T. Shihipar     |
| `w28` | [What's new, Week 28](https://code.claude.com/docs/en/whats-new/2026-w28)                                                                                                                                   | 2026-07, v2.1.205           |
| `x`   | [@ClaudeDevs の投稿](https://x.com/ClaudeDevs/status/2098500999656923145)(本文は [fxtwitter API](https://api.fxtwitter.com/ClaudeDevs/status/2098500999656923145) で取得)                                   | 2026-09-11                  |
| `rc`  | [Reducing cost and improving performance with Claude Platform](https://claude.com/blog/reducing-cost-and-improving-performance-with-claude-platform)(@ClaudeDevs が同日に X の記事として投稿したものと同題) | 2026-09-08, Lance Martin    |
| `ct`  | [How Claude Tag serves as Anthropic's first responder for CI/CD failures](https://claude.com/blog/ai-ci-cd-on-call)                                                                                         | 2026-08-18, Sachin Malhotra |

## 0. 最新の公式の立場を一言で

**Claude 5 世代では「足す」より「削る」が既定になった。** Anthropic は Claude Code のシステムプロンプトの 80% 超を削り、コーディング eval で測れる劣化は出なかった — "We removed over 80% of Claude Code's system prompt for models like Claude Opus 5 and Claude Fable 5 with no measurable loss on our coding evaluations." [c5] 同じ記事は、原因を**過剰な制約と、層どうしで衝突する指示**だとしている: "we were overconstraining Claude Code, both through our system prompt and in our CLAUDE.md files and skills"、"conflicting messages in a single request like 'leave documentation as appropriate,' or 'DO NOT add comments'" [c5]。そのうえで読者にも同じことを求めている: "Across your system prompt, skills, and CLAUDE.md files, you may need to simplify just like we did." [c5]

以下の CLAUDE.md とスキルの項目は、どれもこの方針の具体化として読める。

## 1. CLAUDE.md

### 何を入れるか — 基準は「毎セッション要る」かつ「コードから推測できない」

- 公式の問いは1つだけ: "For each line, ask: _'Would removing this cause Claude to make mistakes?'_ If not, cut it." [bp]
- 入れるもの/入れないものの表 [bp]:
  - 入れる: Claude が推測できない Bash コマンド、既定と違うコードスタイル、テストの流儀、リポジトリの作法(ブランチ名・PR)、プロジェクト固有のアーキテクチャ判断、開発環境の癖(必須の環境変数)、"Common gotchas or non-obvious behaviors"
  - 入れない: コードを読めば分かること、言語の標準慣習、詳細な API ドキュメント(リンクで済ませる)、頻繁に変わる情報、長い説明やチュートリアル、ファイルごとの説明、「きれいなコードを書く」のような自明な実践
- 紙面の大半は gotcha に使う: "Keep your CLAUDE.md lightweight and briefly describe what your repo is for, but spend most of the tokens on gotchas inside of the codebase … Avoid stating 'the obvious' things Claude should know by looking at your file system or your repo." [c5]
- 書き足すきっかけは4つ: 同じ間違いを2度された、コードレビューで「このコードベースなら知っていてほしかった」ことが見つかった、前のセッションと同じ訂正をまた打った、新しいチームメイトにも同じ説明が要る [mm]。`fo` の「育て方」表も、最初の行は "Claude gets a convention or command wrong twice → Add it to CLAUDE.md" [fo]。
- 自動メモリとの分業: Claude は自動メモリに、コードベースから導けること(アーキテクチャ、パス、デバッグの修正)と CLAUDE.md に既に書いてあることは保存しない [mm]。c5 も、以前 CLAUDE.md が担っていた「記憶」の役は memory・artifacts・skills に移ったとしている [c5]。

### 大きさ

- **1ファイル200行未満**が目標。長くなると文脈を食い、遵守率が下がる [mm][fo]。`st` はさらに運用を足している: "Keep CLAUDE.md under 200 lines, give it an owner, and review changes to it like code." [st]
- なぜ短く保つのか: "Every line loads into every session for every engineer working in the repo, whether it's relevant to their task or not. This consumes tokens and dilutes adherence to the instructions that actually matter." [st] / "Bloated CLAUDE.md files cause Claude to ignore your actual instructions!" [bp]
- ハードな上限: 4 MiB を超えるファイルは丸ごとスキップされる(自動メモリの `MEMORY.md` は別で、先頭200行または25KB)[mm]。
- `@import` は整理にはなるが**文脈は減らさない** — import 先も起動時にロードされる [mm]。再帰は4ホップまで [mm]。
- ブロックレベルの HTML コメント `<!-- … -->` は注入前に取り除かれるので、人間向けのメモはトークンを払わずに残せる [mm]。

### 書き方

- **具体的に、検証できる形で**: "Use 2-space indentation" であって "Format code properly" ではない。"Run `npm test` before committing" であって "Test your changes" ではない [mm]。
- **構造**: Markdown の見出しと箇条書きでまとめる。密な段落より追いやすい [mm]。
- **一貫性**: "if two rules contradict each other, Claude may pick one arbitrarily." ネストした CLAUDE.md と `.claude/rules/` も含めて、定期的に見直す [mm]。
- **強調は1行だけに**: "If Claude keeps skipping one instruction, add emphasis such as 'IMPORTANT' to that line alone. If you emphasize many lines, none of them stands out." [bp] 一方で、4.5 世代以降は強い言葉が過剰発火を招くので "CRITICAL: You MUST use this tool when..." を "Use this tool when..." へ戻せ、というのがプロンプティングガイドの立場である([Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))。
- **規則ではなく判断を渡す**: c5 は旧システムプロンプトの "In code: default to writing no comments. Never write multi-paragraph docstrings…" を、新しい "Write code that reads like the surrounding code: match its comment density, naming, and idiom." に置き換えた例を挙げている [c5]。旧い規則は古いモデルの最悪ケースを避けるためのもので、"newer models have better judgement and can handle these decisions well without explicit rules." [c5]
- **例示は探索空間を狭める**: "giving examples actually constrains them to a certain exploration space"。例を足すより、ツール・スクリプト・ファイルの形(列挙型の引数など)を表現力のあるものにする [c5]。これは `sb` の Examples pattern とは食い違って見える(`OFFICIAL.md` §6 に既に両論併記がある)。c5 の文脈は**ツール使用例**の話である。
- **古いモデル向けの「儀式」を外す** [rc]: API のコスト記事は、フロンティアモデルで逆効果になる指示の型を5つ名指ししている。
  - 検証の儀式(「作業を二重に確かめよ」)。文字どおりに実行されて、トークンを浪費する
  - 徹底や強調の上乗せ(「最大限徹底的に」「CRITICAL: YOU MUST ALWAYS…」)。冗長な出力と余計なツール呼び出しを招く
  - 固定手順とスクラッチパッドの足場: "reasoning templates are rituals that frontier models don't need. This scaffolding can stack on top of native reasoning and use unnecessary tokens."
  - 古いモデルの失敗に合わせて作った few-shot 例
  - 矛盾する規則。指示追従が上がった分、矛盾がより文字どおりに実行される
  - 実測: Opus 4.8 → Opus 5 への移行で、これらを1つずつ仕込んだプロンプトから取り除いたところ "decreasing costs by 14.6% and increasing accuracy by 5.3% on average." 精度が上がった理由は2つある。矛盾する返金規則のせいで Opus 5 が払うべき返金を4件保留していた。手書きのスクラッチパッドが組み込みの thinking とぶつかり、3件ではツール呼び出しを推論の中に書いたまま実行しなかった [rc]
  - 対象は API アプリのシステムプロンプトだが、c5 が CLAUDE.md とスキルについて言っていること(過剰な制約・衝突・例示)と同じ向きを、数値で裏づけている

### 置き場所の振り分け(CLAUDE.md に入れないものの行き先)

| 中身                                         | 行き先                           | 根拠                                                                                                                                                                 |
| -------------------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 毎セッション要る事実・「常に X」             | `CLAUDE.md`                      | [mm][fo]                                                                                                                                                             |
| 一部のファイル・ディレクトリにだけ効く規約   | `.claude/rules/` + `paths:`      | 一致するファイルを Read したときにだけロードされる [mm]。"migrations are append-only" のようなファイル固有の制約はここ [st]                                          |
| 複数ステップの手順、時々だけ要る参照資料     | スキル                           | "If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule" [mm]。30行の手順が典型的な失敗例 [st] |
| 絶対に起きてはならないこと、毎回必ずやること | フック / パーミッション          | "an instruction is the wrong tool … A real guardrail needs to be deterministic" [st]。CLAUDE.md の "never edit `.env`" は "a request, not a guarantee" [fo]          |
| 個人の好み                                   | `CLAUDE.local.md` / `~/.claude/` | [mm][st]                                                                                                                                                             |

- `paths:` の無いルールは `.claude/CLAUDE.md` と同じ優先度で起動時にロードされる — 分けても文脈は減らない。減らしたいなら `paths:` を付ける [mm][st]。
- 圧縮(`/compact`)後: ルート CLAUDE.md はディスクから読み直されて再注入される。ネストした CLAUDE.md と path-scoped ルールは、該当ファイルを再び読むまで戻らない [mm]。

### プロンプトキャッシュに効く配置

- `rc` がキャッシュについて挙げる原則: 静的なもの(ツール定義とシステムプロンプト)を先に置き、伸びていく会話を後ろに置く。前半には、呼び出しごとに変わる値(タイムスタンプや ID など)を入れない — "Lay out the request out so the stable part stays stable"。ツール定義の順序が揺れるだけでもキャッシュが壊れる — "Avoid tool definitions that reorder themselves" [rc]
- **推論(公式は明言していない)**: CLAUDE.md は起動時にロードされ、会話の前に置かれる [mm]。したがって CLAUDE.md に日付・ビルド番号のような変わる値を書かないことは、上の原則からそのまま出てくる。ただし `rc` は Messages API を直接使うアプリの話で、Claude Code の CLAUDE.md やスキルには直接触れていない

### 保守のしかた

- "Treat CLAUDE.md like code: review it when things go wrong, prune it regularly, and test changes by observing whether Claude's behavior actually shifts." [bp]
- 症状から原因を読む: ルールがあるのに守られない → ファイルが長すぎて埋もれている。CLAUDE.md に書いてあることを質問してくる → 書き方が曖昧 [bp]。守られない指示はまず `/context` でロードされているかを確かめる。ロードされているなら、書き方(曖昧・衝突・長すぎ)の問題である [dc]。
- "Ruthlessly prune. If Claude already does something correctly without the instruction, delete it or convert it to a hook." [bp]
- `/doctor`(v2.1.205 で全面的なチェックアップになった)は、コミットされた CLAUDE.md からコードベースで導ける中身(ディレクトリ構成・依存一覧・アーキテクチャ概要)を削る提案を出し、落とし穴・理由・ツール既定と違う規約は残す。ローカル CLAUDE.md とコミット版の重複も除く [mm][w28]。c5 は、この記事の方針を `/doctor` に実装したと明言している [c5]。
- `/init` は出発点。"Refine from there with instructions Claude wouldn't discover on its own." [mm](このリポジトリが `/init` から始めない理由は [ADR-0003](../adr/0003-never-start-from-init-output.md))

### 学んだことを書き溜める運用例: Claude Tag の `lessons.md`

Anthropic の CI チームは Claude Tag を on-call の一次対応に置き、その常設の指示をファイルで持っている [ct]。**CLAUDE.md の書き方の指針ではない。** gotcha を書き溜めてスキルへ昇格させる、という流れの実例として参考になる。

- 常設の指示はスキルとして Markdown に書き、GitHub にコミットする: "Standing instructions are in markdown files as skills, committed in a GitHub repository. This way multiple teammates can iterate on them and we can manage changes just like we do code." ルーティングの指示、ポリシー、学びのログも含む [ct]
- `lessons.md` は解決した障害ごとのログで、何が起きたか・根本原因・直し方・覚えておくべき gotcha を書く。Claude が自動で追記し、"Every new investigation starts by reading it, so Claude's first hypothesis starts with what has happened recently." [ct]
- **同じパターンが何度も出たら、ログからスキル本体へ昇格させる**: "If the same pattern shows up enough times, we promote it into the investigation skill itself." [ct] — Gotchas 節は Claude が踏んだ失敗から育てる、という `lc` の指針と同じ向きである
- 判定の規則は、データを見て調整してから具体的な閾値で書く。例: 「エラー率が 2% を超えて5分以上続き、既知のデプロイ時間帯でなければ on-call を呼ぶ。そうでなければ lessons.md に書く」[ct]
- 人間向けの引き継ぎ(日次・週次のまとめ、SITREP)は `lessons.md` と分けている — `lessons.md` は "a journal for itself" [ct]
- 書かれていないこと: `lessons.md` の長さの上限、古い項目の刈り込み方、項目の書式。ここは Claude Code の自動メモリ(`MEMORY.md` は先頭200行/25KB、1項目1行、詳細はトピックファイルへ)[mm] の方が具体的である

## 2. スキル

### description — 発火のすべてがここにかかる

- "the description field is not a summary, it's a description of when to trigger this skill." [lc] / "the description carries the entire burden of triggering." [od]
- 「何をするか」と「いつ使うか」を両方入れる。三人称で書く(システムプロンプトに注入されるため、人称が揺れると発見に響く)[sb]。
- **主要なユースケースを先頭に置く** — Claude Code では `description` と `when_to_use` を合わせた長さがスキル一覧で 1,536 文字に切り詰められる [cc]。標準側の上限は 1,024 文字 [sb][od]。前者は Claude Code が一覧に載せる長さ、後者は標準が許すフィールドの長さで、別物である。
- 一覧全体にも予算がある: モデルのコンテキストウィンドウの 1%。溢れたら**呼ばれる頻度の低いスキルから** description が削られ、マッチに要るキーワードが落ちることがある [cc]。
- agentskills.io の書き方の指針 [od]: 命令形で書く("Use this skill when…")、実装ではなくユーザーの意図を書く、"Err on the side of being pushy"(ユーザーが領域名を口にしなくても当たる文脈まで挙げる)、数文〜短い段落に収める。
- 注意: 1ステップで済む単純な依頼は、description が完全に一致していても発火しないことがある。基本ツールで片付くためである [od]。
- 4.5 世代以降は発火しすぎの方が問題になりやすい: "If in doubt, use [tool]" のような過剰なプロンプトは外す([Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices))。

### 本文

- **500行未満** [cc][sb]。一度ロードされた本文はその後のターンにも残り続けるので、1行1行が繰り返し払うコストになる [cc]。
- 本文は**読み直されない** — 後のターンでスキルファイルを読み直さないので、タスク全体に効く「常設の指示」として書く [cc]。
- 圧縮後に残るのは各スキルの先頭 5,000 トークン、全スキルで合計 25,000 トークン(最近呼んだものから詰める)[cc]。**大事なことを先頭に置く理由**がここにある。
- "Think of skills as lightweight guides to let Claude find information when needed. Avoid making them overconstrained, except in highly important areas." [c5]
- 分量が増えたら複数ファイルに割り、SKILL.md を目次にする(段階的開示)。参照は SKILL.md から1階層まで、100行を超える参照ファイルには先頭に目次 [sb]。
- **Gotchas 節が最も信号が濃い**: "The highest-signal content in any skill is the Gotchas section. These sections should be built up from common failure points that Claude runs into when using your skill." [lc]
- 自明なことを書かない。Claude の通常の考え方から押し出すものを書く [lc][sb]。
- "Avoid railroading Claude" — 必要な情報は渡し、状況に合わせる余地を残す [lc]。例外は壊れやすい操作で、そこでは自由度を下げて厳密なスクリプトを渡す [sb]。
- 決定的な処理はスクリプトとして同梱する。Claude のターンは組み立てに使わせる [lc][sb]。
- 選択肢を並べない。既定を1つ出し、逃げ道を添える [sb]。

### frontmatter で効かせるもの(Claude Code)

- `disable-model-invocation: true`: 副作用のあるワークフロー向け。description がモデルに渡らなくなるので、文脈コストもゼロになる [cc][fo]。
- `user-invocable: false`: ユーザーの操作ではない背景知識向け [cc]。
- `paths`: 一致するファイルを扱うときだけ自動発火させる [cc]。
- `context: fork`: 本文を隔離したサブエージェントの依頼文として走らせる。会話の履歴は見えない [cc]。
- claude.ai へのアップロードと Skills API で通るのは、標準のフィールド(`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`)だけ [cc]。

## 3. 測る — 「効いているか」を仮定しない

- eval を先に作り、ベースライン(スキル無し)と比べる [sb]。
- **`claude plugin eval`(2026-09-11 に告知)**: "You can create test cases, run your plugin or skill against those test cases, score those runs, then run each case again without the plugin to see the differences." [x] 仕様は [pe]:
  - v2.1.269 以降。プラグインのマニフェスト、または skills-directory plugin が要る。実行も judge も実際のモデル呼び出しで、プランの使用量か API 課金に計上される。ドキュメントには "plugin eval is currently in early access" というエラーのトラブルシュート項目もある [pe]。
  - 1ケース = `evals/<case>/prompt.md`(ユーザーが打つ形の依頼。**スキル名を書かない**)+ `graders/*.md` [pe]。
  - 既定では各ケースを3回ずつ走らせる("One run of a non-deterministic agent tells you little")。既定の `--threshold` は 1.0 [pe]。
  - 既定ではプラグイン無しでも同じだけ走らせ、`WITH` / `W/OUT` / `Δ` を出す。"If a case scores 1.0 both with and without the plugin, the plugin isn't what made it pass." [pe]
  - grader の選び方: 各ケースに「結果」を見る grader を1つ、「どう到達したか」(`tool_used` / `tool_order`)を見る grader を1つ置く。長い出力は `llm` ではなく `regex` で見る。`llm` の rubric は具体的な PASS/FAIL 条件で書く [pe]。
  - プラグインがロードされたのに `Δ` がほぼ0で、`tool_used: Skill` も落ちている → たいていは本物の発見で、description がそのプロンプトの言い回しで発火していない [pe]。
  - `claude plugin eval init` がケースと grader を提案し、試走してから書き出す(推奨の経路)。skill-creator の `evals/evals.json` とは形式が別 [pe]。
- 発火率の測り方(標準側)[od]: クエリは約20本(発火すべき 8〜10、すべきでない 8〜10)。負例は**ニアミス**(キーワードを共有するが別の仕事)にする。各クエリを3回走らせて発火率 0.5 を閾値にし、train 60% / validation 40% に分けて過学習を避ける。失敗したクエリのキーワードをそのまま足さない。5回ほどの反復で十分なことが多い。
- 運用中の観測: `/skill-doctor`(v2.1.252+)が各スキルのトークンコストと使用頻度を出し、止める候補を示す [cc]。`/doctor` もスキル一覧の文脈コストを見積もる [cc][w28]。

## 4. 実務上の結論

1. CLAUDE.md は「消したら Claude が間違えるか」で1行ずつ削り、200行未満に収める。残す中身は gotcha・既定と違う規約・推測できないコマンド・理由 [bp][mm][c5]。
2. 手順はスキルへ、一部のファイルにだけ効く規約は `paths:` 付きのルールへ、絶対に守らせたいものはフックへ移す [mm][st][fo]。
3. 層どうし(システムプロンプト・CLAUDE.md・スキル・ユーザーの依頼)で指示が衝突していないか見る。衝突はモデルに余計な熟考を強いる [c5][mm]。
4. 強調・MUST・例示・検証の儀式・固定手順は減らす方向で見直す。強調するなら1行だけ。API ではこれを外してコスト -14.6%・精度 +5.3% の実測がある [bp][c5][rc]。
5. スキルは description を「いつ発火するか」として書き、主要なユースケースを先頭に置く。本文は500行未満で、Gotchas を厚くし、大事なことを先頭 5,000 トークンに入れる [lc][cc]。
6. 効いているかは `claude plugin eval` の `Δ` で測る。ニアミスの負例も含める [pe][od]。

## 5. OFFICIAL.md に未反映のもの

`OFFICIAL.md` の最終突き合わせ(2026-08-09)以降に出た、あるいはそこに載っていない公式の事実。取り込むなら `OFFICIAL.md` の「この文書を編集するとき」の手順に従う。

- **`claude plugin eval`**(v2.1.269+、[pe][x]): §8 の「eval を先に作る」「delta で判断する」を実装した公式ツール。3回ずつの実行、プラグイン無しのベースライン、`Δ`、grader の6種類、CI での閾値ゲート
- **スキル一覧の予算はコンテキストの 1%**。溢れたら使用頻度の低いスキルから description が削られる。`skillListingBudgetFraction` / `skillListingMaxDescChars` / `skillOverrides: "name-only"` で調整する [cc]
- **`/skill-doctor`**(v2.1.252+)と `/doctor` のチェックアップ化(v2.1.205)[cc][w28]
- **ソース表に `st`(Steering Claude Code, 2026-06-18)が無い**。CLAUDE.md の 200 行・オーナー・コードと同じレビュー、ファイル固有の制約は path-scoped ルールへ、ガードレールはフックへ、の出典として使える
- 4 MiB を超える CLAUDE.md はスキップされる。ブロックレベルの HTML コメントは注入前に取り除かれる [mm]
- CLAUDE.md の中身は**システムプロンプトではなく、その後の user メッセージとして**渡される。システムプロンプトの層に置きたいなら `--append-system-prompt` [mm]
- **`rc`(2026-09-08)**: 指示のアンチパターン5類型と、それを外したときの実測値。§6 の「過剰に制約しない」「当たり前を書かない」に数値の裏づけを足せる
- **`ct`(2026-08-18)**: gotcha を `lessons.md` に書き溜め、繰り返したものをスキルへ昇格させる運用例。§8 の「最小から始めて、踏んだ分だけ育てる」の実例になる

## 取得できなかったもの・未確認

- `x.com` の投稿本体は HTTP 402 で取れず、fxtwitter API で本文を取得した。投稿にはリンクが無く画像が1枚あるだけで、画像の中身は見ていない。内容は `claude plugin eval` の告知で、仕様は [pe] で裏を取った。
- [The Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)(PDF)は検索に出たが読んでいない。日付も未確認である。
- `pe` の early access の条件(誰が使えるか)は、トラブルシュート項目の見出しだけで、本文は確認していない。
- X の記事(status/2097369738968195513)は fxtwitter API で本文ごと取得できた。ただ、同題・同日の claude.com のブログ `rc` を出典にしており、記事本文とブログを一文ずつ突き合わせてはいない。`rc` の引用のうち原文と照合したのは、スクラッチパッドの一文、14.6% / 5.3% の一文、キャッシュの節の見出し2つ。残りの類型は要約から訳した。
- `ct` の元の投稿(status/2097437571634639035)が触れている "a template and skills" の中身は見ていない。
