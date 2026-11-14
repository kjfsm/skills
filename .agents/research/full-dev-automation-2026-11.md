# 開発の全工程を自動化する — 公式の手段と他の実践者(2026-11 時点)

問い: Factorio のように、人間は工場の設計と詰まりの解消だけをする状態へ近づくには何を足すか。Anthropic の公式情報と、ほかの実践者のやり方を調べる。

調査日: 2026-11-12。数値と仕様は取得時点のもの。調査役2体(公式 / 他の実践者)の報告を突き合わせたもので、**ソース表の「読み」が「二次」「未読」のものは一次本文を確かめていない。** 未調査: Devin、Factory.ai、Cursor background agents、OpenHands、Claude Tag(Slack)の詳細、Anthropic 社内の利用実態の一次情報。

## ソース

| キー  | ソース                                                                                                                                                                | 日付 / 版  | 読み                     |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------ |
| `hl`  | [Headless](https://code.claude.com/docs/en/headless.md)                                                                                                               | docs       | 一次                     |
| `av`  | [Agent view](https://code.claude.com/docs/en/agent-view.md)                                                                                                           | docs       | 一次                     |
| `cw`  | [Claude Code on the web](https://code.claude.com/docs/en/claude-code-on-the-web.md)                                                                                   | docs       | 一次                     |
| `rt`  | [Scheduled tasks(旧 routines)](https://code.claude.com/docs/en/routines.md)                                                                                           | docs       | 一次                     |
| `ga`  | [GitHub Actions](https://code.claude.com/docs/en/github-actions.md)                                                                                                   | docs       | 一次                     |
| `ch`  | [Channels](https://code.claude.com/docs/en/channels.md)                                                                                                               | docs       | 一次                     |
| `rc`  | [Remote Control](https://code.claude.com/docs/en/remote-control.md)                                                                                                   | docs       | 一次                     |
| `bp`  | [Best practices](https://code.claude.com/docs/en/best-practices.md)                                                                                                   | docs       | 一次                     |
| `at`  | [Agent teams](https://code.claude.com/docs/en/agent-teams.md)                                                                                                         | docs       | 一次                     |
| `wf`  | [Workflows](https://code.claude.com/docs/en/workflows.md)                                                                                                             | docs       | 一次                     |
| `gl`  | [/goal](https://code.claude.com/docs/en/goal.md)                                                                                                                      | docs       | 一次                     |
| `sdk` | [Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview.md)                                                                                                    | docs       | 一次                     |
| `ma`  | [Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)                                                                                         | docs, beta | 一次                     |
| `pm`  | [Permission modes](https://code.claude.com/docs/en/permission-modes.md)                                                                                               | docs       | 一次                     |
| `sb`  | [Sandboxing](https://code.claude.com/docs/en/sandboxing.md)                                                                                                           | docs       | 一次                     |
| `co`  | [Costs](https://code.claude.com/docs/en/costs.md)                                                                                                                     | docs       | 一次                     |
| `am`  | [Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode)                                                                                  | —          | 一次                     |
| `be`  | [Building effective agents](https://www.anthropic.com/research/building-effective-agents)                                                                             | —          | 一次                     |
| `eh`  | [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)                                      | 2025-11-26 | 一次                     |
| `hd`  | [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)                                                        | 2026-03-24 | 一次                     |
| `cc`  | [Building a C compiler](https://www.anthropic.com/engineering/building-c-compiler)                                                                                    | 2026-02-05 | 一次                     |
| `mr`  | [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)                                                                      | 2025-06-13 | 一次                     |
| `ce`  | [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)                                                    | 2025-09-29 | 一次                     |
| `sm`  | [Safely scaling multi-agent teams](https://claude.dev/blog/safely-scaling-multi-agent-teams-with-fable-5-2/)                                                          | 2026-11-09 | 一次                     |
| `sc`  | [Redesigning source control](https://www.anthropic.com/research/redesigning-source-control)                                                                           | 2026-10-13 | 一次                     |
| `ct`  | [How we contain Claude across products](https://www.anthropic.com/research/how-we-contain-claude)                                                                     | 2026-05-25 | 一次                     |
| `rl`  | [Ralph](https://ghuntley.com/ralph/)(G. Huntley)                                                                                                                      | 2025-07-14 | 一次                     |
| `le`  | [What is loop engineering](https://newsletter.pragmaticengineer.com/p/what-is-loop-engineering)                                                                       | 2026       | 一次(有料部分未読)       |
| `ah`  | [Getting started with Ralph](https://aihero.dev/getting-started-with-ralph)(M. Pocock)                                                                                | —          | 検索抜粋のみ             |
| `gt`  | [Gas Town 批評](https://maggieappleton.com/gastown)                                                                                                                   | 2026       | 一次                     |
| `sed` | [Gas Town, Beads(SE Daily)](https://softwareengineeringdaily.com/2026/02/12/gas-town-beads-and-the-rise-of-agentic-development-with-steve-yegge/)                     | 2026-02-12 | 二次                     |
| `sf`  | [StrongDM の software factory](https://simonwillison.net/2026/Feb/7/software-factory/)(S. Willison)                                                                   | 2026-02-07 | 二次                     |
| `fl`  | [The five levels](https://simonwillison.net/2026/Jan/28/the-five-levels/)(D. Shapiro の要約)                                                                          | 2026-01-28 | 二次                     |
| `oh`  | [OpenAI harness engineering(InfoQ)](https://www.infoq.com/news/2026/02/openai-harness-engineering-codex)                                                              | 2026-02    | 二次(一次は 403)         |
| `pa`  | [Parallel coding agents](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/)                                                                                | 2025-10-05 | 一次                     |
| `gw`  | [GitHub Agentic Workflows](https://github.blog/changelog/2026-02-13-github-agentic-workflows-are-now-in-technical-preview/)                                           | 2026-02-13 | 一次                     |
| `zt`  | [ラベル駆動 + n8n の実践記](https://zenn.dev/tesla/articles/3abc9e61da0b1e)                                                                                           | —          | 一次                     |
| `tb`  | [The Final Bottleneck](https://lucumr.pocoo.org/2026/2/13/the-final-bottleneck/)、[The Coming Loop](https://lucumr.pocoo.org/2026/6/23/the-coming-loop/)(A. Ronacher) | 2026       | 未読(URL の前者は未確認) |

## 0. 結論

**次に足すのはエージェントの数でも起動の仕組みでもなく、人間が差分を読まなくても通してよいと言える検証である。**

- ボトルネックはレビューの速度にある。Willison は4並列でも消耗すると書き [pa]、Anthropic 社内も全行ではなく変更の意図をレビューする方向へ移った [sc]。
- テストだけでは足りない。StrongDM ではエージェントがテストを偽装し、隠した受入シナリオが必要になった [sf]。C コンパイラの記事も、テストが通ると完了だと思い込みやすいと警告している [cc]。
- 生成と評価を分けると効く。フルハーネスは6時間・$200 で動くものができ、単独実行は20分・$9 で中核機能が動かなかった [hd]。
- マージ・本番デプロイ・マイグレーションは公式が既定で人の承認に残している [am][bp]。目標は「人間ゼロ」ではなく「人間は仕様と承認だけで、差分は読まない」に置く。

足す順番:

1. 検証を厚くする — 実装セッションから見えない受入シナリオ(holdout)と、プレビュー環境への E2E を CI のゲートにする。
2. 起動を無人にする — イシューのラベルや cron から draft PR まで。Scheduled tasks か claude-code-action に、ターン上限と `--max-budget-usd` を付ける。
3. 入口を自動にする — 本番のエラーからイシューを起票する。
4. 並列を増やす — Workflow や多数並列は最後。

順番が変わる条件: CI が緑なら差分を読まずにマージしているなら 2 から。実装待ちのチケットが常に空なら 3 が先。使用量の上限に頻繁に当たるなら 2 と 4 は詰まりを増やす。

## 1. 無人実行の手段(公式)

| 手段                            | トリガー                          | 制約                                                                                                                                                                                   |
| ------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude -p` [hl]                | スクリプト、cron                  | 終了コードで成否、`--output-format json` に `total_cost_usd`。無人では `--permission-mode auto` か `dontAsk`、`--max-budget-usd`。スクリプトには `--bare` が推奨                       |
| Agent view / `claude --bg` [av] | 人                                | 研究プレビュー。承認待ちは人が attach して答える。マシンの再起動で止まる                                                                                                               |
| Cloud sessions [cw]             | 人、GitHub App                    | Anthropic 管理の VM。auto-fix が CI 失敗とレビューコメントに対応する。conflict は検知されない                                                                                          |
| Scheduled tasks [rt]            | cron、API POST、GitHub イベント   | 研究プレビュー。クラウドの auto mode。スケジュール実行 100 回/時(アカウント)、Run now と API 30 回/時(タスク)。GitHub 接続が 72 時間切れると止まる。発火したプロンプトは承認にならない |
| claude-code-action [ga]         | `@claude`、`prompt` 指定(cron 可) | 起動は write 権限のあるユーザーだけ。bot は `allowed_bots` に入れる。public repo の schedule は 60 日無活動で止まる                                                                    |
| Channels [ch]                   | MCP 経由のイベント                | 研究プレビュー。セッションが開いている間だけ届く。許可リストの送信者が権限プロンプトを承認できる                                                                                       |
| Remote Control [rc]             | 人(携帯・ブラウザ)                | 処理はローカル。マシンは起動し続ける                                                                                                                                                   |

公式は、起動はトリガーに任せ、完了後のマージとデプロイは人の承認、と分けている [bp]。

## 2. オーケストレーション(公式)

- **Subagents**: 1セッションの中で配り、結果は親の文脈へ戻る。
- **Agent teams** [at]: 実験的で既定オフ。`-p` では teammate を作らない。1セッション1チーム、ネスト不可、推奨 3〜5 人。
- **Workflows** [wf]: スクリプトが多数の subagent を回す。1 run 最大 1,000 agents、同時 16 が既定。実行中は人に聞けない。先に小さなスライスで費用を測るよう書かれている。
- **`/goal`** [gl]: 完了条件を毎ターン別モデルが判定する。判定者はコマンドを実行せず、会話に出た内容だけで決める。
- **Agent SDK** [sdk] / **Managed Agents** [ma]: 前者は自分のインフラ、後者は Anthropic がサンドボックスとループを運用する(beta)。
- 指針は「最も単純な解から始め、必要なときだけ複雑さを足す」 [be]。マルチエージェントはトークンが約 15 倍で、幅優先の調査に強く、依存の強いコーディングに弱い [mr]。

## 3. 無人で回すための安全装置(公式)

- **auto mode** [am][pm]: 分類器が操作ごとに判定する。curl|bash、本番デプロイとマイグレーション、force push、人が承認していない PR のマージを既定で止める。同じ操作が 3 回連続か計 20 回ブロックされると人へ戻る。社内評価で危険な操作の見逃し率 17%、誤検知 0.4%。安全を保証しないと明記されている。
- **bypassPermissions** は隔離されたコンテナや VM 専用 [pm]。
- **sandbox** [sb]: 囲うのは Bash だけで、ファイルツール・MCP・hooks は対象外。`failIfUnavailable: true` と `allowUnsandboxedCommands: false` を設定し、プロセス全体をコンテナか VM に入れるのが推奨。
- **上限** [co]: `--max-turns`、`--max-budget-usd`、Console の workspace spend limit。
- **hooks**: `TaskCompleted` と `TeammateIdle` で exit 2 を返すと完了を差し戻せる。
- 承認プロンプトの約 93% は許可されており、基本方針は「監督するより囲い込む」 [ct]。
- 1,000 agents の事例では、agent ごとに隔離 VM・ネットワークなし・agent 間通信なしで、main への統合は別ジョブが行った [sm]。

## 4. 長時間・自律開発の教訓(公式)

- 初期化用と作業用のエージェントを分ける。機能リストは JSON にして `passes` だけを変更可にし、1回に1機能だけ進める。ブラウザでの E2E 検証が効いた [eh]。
- 評価者は初期状態では甘く、few-shot での調整が要る。モデルが進むたびにハーネスの部品を削る [hd]。
- タスクはロックファイルで取り、git で統合する。テストを oracle にし、出力は短く、詳細はファイルへ。全体が同じバグで衝突したときは既知の正解(GCC)で作業を分けた。約 2,000 セッション・約 $20,000・約 10 万行 [cc]。
- 無人にする前の5問: done の定義、自己検証の手段、触ってよい範囲、停止条件(turn・spend の上限)、結果の行き先と承認者。新しい処理は最初の数回を見届ける [bp]。
- 文脈は compaction、ノートの外出し、subagent、just-in-time の取得で保つ [ce]。

## 5. 他の実践者

| 手法                            | 構成                                                                                         | 検証の機械化                                                                                                      | 失敗・批判                                                                                                                |
| ------------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Ralph ループ [rl][ah]           | while で同じプロンプトを回し、計画ファイルから1ループ1タスク。計画ループと実装ループを分ける | テストと型検査だけ                                                                                                | greenfield 前提。重複実装と空実装に寄る。Pocock は人が見て1回走らせてから無人へ移し、イテレーション上限を付けるよう勧める |
| loop engineering [le]           | Sentry のエラー・新規チケット・cron で起動                                                   | —                                                                                                                 | drift して止めた開発者がいる。API 課金では高い                                                                            |
| Gas Town / Beads [sed][gt]      | 20〜30体を役割分けして並列。状態は Git 管理のイシューに置く                                  | merge queue 役のエージェント                                                                                      | API 費用が月数千ドル規模。設計と計画がボトルネックになる                                                                  |
| StrongDM [sf]                   | 人間はコードを書かず、レビューもしない                                                       | エージェントから隠した受入シナリオ(holdout)と、外部サービスの挙動クローン。合否は satisfaction という確率的な指標 | テストの偽装が起きた。1人1日 $1,000 が目安とされる                                                                        |
| OpenAI harness engineering [oh] | 約 100 万行を人手のコード 0 行で出荷                                                         | ログ・メトリクスをエージェントが見る。構造テストと linter を CI で強制                                            | コストと人間レビューの有無は未確認                                                                                        |
| GitHub Agentic Workflows [gw]   | イシュー・cron・コメントで起動し draft PR まで                                               | 既定は read-only、書き込みは許可済みの操作だけ                                                                    | マージは人間                                                                                                              |
| ラベル駆動 + n8n [zt]           | ラベルで 計画→実装→レビュー を進める                                                         | PR ではなくコメントでレビュー                                                                                     | Overloaded からは自動復旧できない                                                                                         |

成熟度の物差しとして Shapiro の5段階がある [fl]: L3 は人間が常時レビュアー、L4 は人間が仕様と計画、L5 は人間が検証の仕組みだけを作る。

共通する設計原則:

- 検証を人間のレビューから機械へ移す(holdout シナリオ、ログ観測、構造テスト、CI での強制)。
- 状態はエージェントの記憶ではなく、ファイル・イシュー・Git に置く。
- 1タスク1単位に切り、イテレーション上限と権限の限定を既定にする。
- 人間の仕事は実装から、仕様・環境設計・詰まりの解消へ移る。

意見が割れている点: 人間のレビューを外すか(StrongDM は外す、Willison は懸念、Pocock と GitHub は残す)、並列の数、ループ運転そのものの是非。
