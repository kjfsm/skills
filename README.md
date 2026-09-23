# kjfsm's Skills

Claude Code、Codex、その他 Agent-Skills 標準に準拠したハーネス向けのエージェントスキル(スラッシュコマンドと振る舞い) — 雰囲気で書くコーディングではなく、実務のエンジニアリングのために使う。

[mattpocock/skills](https://github.com/mattpocock/skills) を日本語訳し、kjfsm 向けに調整した独立フォークから出発した。**本家由来のスキル(`/mattpocock-skills:tdd`、`/mattpocock-skills:grill-with-docs`、`/mattpocock-skills:to-spec` など)は、依存先の本家 `mattpocock-skills` がそのまま配る。** このリポジトリの `kjfsm-skills` が持つのは自作のスキルと、本家から離れて自作の流れの中心になったもの(`/kjfsm-skills:implement-and-review`、`/kjfsm-skills:ask-kjfsm`、`/kjfsm-skills:setup-skills`、`/kjfsm-skills:writing-great-skills`)である。

これらのスキルは小さく、手を加えやすく、組み合わせやすいように設計されている。どのモデルでも動作する。

## Quickstart

スキルは **スラッシュコマンド** として呼ぶ。名前を全部覚える必要はない — 迷ったら `/kjfsm-skills:ask-kjfsm` が、いまの状況に合うフローを教える。

以下は[インストール](#インストール)を済ませた後の話。

### 初回だけ: リポジトリを整える

| 状況                     | コマンド                                                  |
| ------------------------ | --------------------------------------------------------- |
| リポジトリがまだ無い     | `/kjfsm-skills:setup-cf-app` → `/kjfsm-skills:setup-repo` |
| 既存のリポジトリに入れる | `/kjfsm-skills:setup-repo`                                |

`/kjfsm-skills:setup-repo` は setup 系の **唯一の入口** で、順序と依存はこれが持つ。**何度でも再実行してよい** — 済んだ工程は飛ばし、ずれだけを直す。

敷かれるのは届き方の違う4層(検証ゲートの定義、パス別ルール、CI、フック)で、以降のスキルはこれを前提にする。特に `/kjfsm-skills:verification-loop` は「記録されたゲート」を読むので、ここを飛ばすと空回りする。

### 毎回の開発

| やりたいこと           | コマンド                                                                                          |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| 新機能をつくる         | `/mattpocock-skills:grill-with-docs` で設計を詰める → `/kjfsm-skills:implement-and-review` で作る |
| 何かが壊れている       | `/mattpocock-skills:diagnosing-bugs`                                                              |
| イシューが積み上がった | `/mattpocock-skills:triage`                                                                       |
| 大きすぎて見通せない   | `/mattpocock-skills:wayfinder`                                                                    |
| どれを使うか分からない | **`/kjfsm-skills:ask-kjfsm`**                                                                     |

締めまで持つのは `/kjfsm-skills:implement-and-review` である: `/mattpocock-skills:tdd` でビルドし、`/kjfsm-skills:verification-loop` でクリーンランを取り、`/kjfsm-skills:prune-comments` でコメントを削り、`/kjfsm-skills:two-axis-review` でレビューしてからコミットし、PR を出す。**`/kjfsm-skills:implement-and-review` はユーザーからしか呼べない** ので、打たなければこの並びは丸ごと走らない。

複数セッションにまたがる規模なら、`/mattpocock-skills:grill-with-docs` と `/kjfsm-skills:implement-and-review` の間に `/mattpocock-skills:to-spec` → `/mattpocock-skills:to-tickets` を挟んでチケットへ割る。規模の判定とフロー全体は `/kjfsm-skills:ask-kjfsm` が持つ。

## インストール

### いちばん手っ取り早い方法: Claude に貼る

Claude Code に次の1行を貼れば、あとはエージェントが[セットアップ手順](./setup.md)を読んでインストールまで済ませる:

```
Fetch https://raw.githubusercontent.com/kjfsm/skills/main/setup.md
```

自分の手で入れたい場合は、以下から選ぶ。

### 入るものの差

3つは **配るものが違う**。スキルの数は現時点の実測値である。

|                  | A: シンボリックリンク        | B: プラグイン                          | C: `npx skills`                          |
| ---------------- | ---------------------------- | -------------------------------------- | ---------------------------------------- |
| スキル           | **39**(全部)                 | **30**(昇格済み集合のみ)+ 本家 25      | **39**(全部)                             |
| 出力スタイル     | 入らない                     | **入る**(有効化は別途)                 | 入らない                                 |
| サブエージェント | 入らない                     | **入る**(5体)                          | 入らない                                 |
| 実体             | このリポジトリ(clone が必要) | `~/.claude/plugins/` のキャッシュ      | コピー先に実ファイル                     |
| 更新             | `git pull` で即反映          | push のたびに届く(コミット SHA で追随) | 追随しない。`npx skills update` を自分で |
| スコープ         | ユーザー(`~/.claude/skills`) | ユーザー / **プロジェクト** / ローカル | プロジェクト、または `--global`          |
| 向いている人     | このリポジトリ自体を開発する | ふつうはこちら                         | 実体を手元に置いて改変したい             |

**`in-progress/` と別プラグインのバケットを配らないのは B だけである。** C は `--skill` で名前を挙げれば絞れるが、既定は全部入りで、上流で削除したスキルもコピー先には残り続ける。

**サブエージェントと出力スタイルを運べるのも B だけである。** A と C でコメントの判定基準を効かせるには `/kjfsm-skills:setup-repo` を実行して `AGENTS.md` 側に書かせる。

### 選択肢 A: ローカルのハーネススキルディレクトリへシンボリックリンクする

リポジトリのルートから:

```bash
scripts/link-skills.sh
```

これはすべてのスキルを `~/.claude/skills` と `~/.agents/skills` にシンボリックリンクする。各エントリはこのリポジトリへのシンボリックリンクなので、`git pull` すればインストール済みのスキルは常に最新の状態を保つ。スキルを追加・削除・改名したあとは、このスクリプトを再実行すること。

### 選択肢 B: Claude Code プラグインとしてインストールする

昇格済みのスキル集合(`engineering/` + `productivity/`)は、ネイティブな [Claude Code プラグイン](https://code.claude.com/docs/en/plugins)としても出荷されている:

```
/plugin marketplace add kjfsm/skills
/plugin install kjfsm-skills@kjfsm
```

またはシェルから:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-skills@kjfsm
```

既定の導入先はユーザー全体である。**そのリポジトリに入れて、clone した全員へ届けたい**なら `--scope project` を付ける:

```bash
claude plugin marketplace add kjfsm/skills --scope project
claude plugin install kjfsm-skills@kjfsm --scope project
```

`kjfsm-skills` は本家の `mattpocock-skills@mattpocock` に依存しており、インストール時に本家も自動で入る(このマーケットプレイスは `allowCrossMarketplaceDependenciesOn` で `mattpocock` を許可している)。実装からレビュー・PR までの流れは kjfsm の `/kjfsm-skills:implement-and-review` が持つ(本家の `/mattpocock-skills:implement` は経由しない)。

これは `.claude/settings.json` に `extraKnownMarketplaces` と `enabledPlugins` を書き込む。コミットすれば、そのリポジトリで作業する人は何も入れなくてもスキルが有効になる — `npx skills` のようにスキルの実体をリポジトリへコミットせずに済む。

### 選択肢 C: `npx skills` でコピーとして入れる

スキルの **実体** を手元に置きたい場合(このリポジトリを clone せずに使いたい、プロジェクトに同梱したい、など):

```bash
npx -y skills add kjfsm/skills
```

- 何が入るかを先に見るには `--list`、個別に選ぶには `--skill tdd,two-axis-review`、対象ハーネスを決め打ちするには `--agent claude-code` を付ける。
- プロジェクト内で実行するとそのプロジェクトのスキルディレクトリ(`.claude/skills/` など)へ**実ファイルとしてコピー**され、`skills-lock.json` が作られる。`--global` を付けるとユーザーレベル(`~/.claude/skills`)に入る。
- コピーなので `git pull` では追随しない。更新は `npx skills update`、`skills-lock.json` からの復元は `npx skills experimental_install`。
- この CLI はリポジトリ全体を走査するため、`--skill '*'` は `in-progress/` や EmDash 専用のバケットまで含めて全スキルを入れてしまう。昇格済みの集合だけが欲しいなら選択肢 B を使うか、`--skill` で名前を挙げること。
- **`--skill` で絞る場合も `setup-repo` とその工程(`setup-skills`、`setup-rules`、`setup-ci`、`setup-hooks`)は含めること。** この経路では、応答と記述の規約の届け先がそこしかない。

**3つの方法は併用しない。** 同じスキルが2系統で入ると、スラッシュコマンドが重複し、常時読み込まれる description も二重に数えられる。このリポジトリを開発するなら選択肢 A、使うだけなら選択肢 B を選ぶ。

**このリポジトリを clone した場合、下書きのスキルは何も入れなくても使える。** `.claude/skills/` に、どのプラグインも配らない `in-progress/` のスキルへのシンボリックリンクがコミットされているので、この clone の中で作業するかぎりそのまま呼べる。**昇格済みのスキルはここに張らない** — 配るのはプラグイン(選択肢 B)の役目で、両方から見えると同じスキルがセッション開始時に2度並び、上の併用の禁止がそのまま当たる。この clone で `/kjfsm-skills:ask-kjfsm` や `/mattpocock-skills:tdd` を呼ぶには、選択肢 A か B のどちらかを1つ入れる。**選択肢 A はこの clone のリンクと重ならない** — どちらもこのリポジトリの同じ実体を指すので、Claude Code はスキルを1回しか読み込まない。重なるのは実体が別になる B・C の側である。リンクの張り直しは `scripts/sync-project-skills.sh` で、ずれは `scripts/check-invariants.sh` が落とす。

どの方法でも、他のエンジニアリング系スキルを使う前にリポジトリごとに一度 **`/kjfsm-skills:setup-repo`** を実行すること。setup 系4工程の入口であり、届き方の違う4つの層を順に敷く:

| 層                     | 効くとき                 | 工程                                                                                                                                       |
| ---------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 規約・ドキュメント配置 | 毎セッション             | `/kjfsm-skills:setup-skills` — イシュートラッカー、トリアージラベル、ドメインドキュメントの配置、検証ゲート、応答と記述の規約              |
| パス別ルール           | その glob を編集するとき | `/kjfsm-skills:setup-rules` — `paths:` を持つ rule を `.claude/rules/` へ、絶対ルールを `AGENTS.md` へ                                     |
| CI                     | push / PR のとき         | `/kjfsm-skills:setup-ci` — 記録された検証ゲートを GitHub Actions で回す                                                                    |
| 弾く機構               | 該当する操作のたび       | `/kjfsm-skills:setup-hooks` — 散文では守られないものを、効く範囲の広い層から順に(`permissions.deny` / 検査スクリプト / フック)決定的に弾く |

**再実行してよい。** 2回目は済んだ工程を飛ばし、設定と実態のずれ — verification.md に無いコマンドを CI が走らせている、`paths:` がもう存在しないディレクトリを指している — だけを直す。

`AGENTS.md` しか無いリポジトリでは、`.claude/` を読まないハーネスが対象なので `/kjfsm-skills:setup-rules` と `/kjfsm-skills:setup-hooks` は飛ばされる。

### 出力スタイル

プラグインには `kjfsm` という[出力スタイル](https://code.claude.com/docs/en/output-styles)が同梱されている — ユーザーへの応答を日本語にし、コメントの判定基準(何をコメントに書き、何をコード自体やコミットメッセージへ回すか)をセッションに常駐させる。残る宛先 — JSDoc・PR 本文・ADR・docs — は [`where-to-write-what`](./skills/kjfsm-skills/engineering/where-to-write-what/SKILL.md) が決める。

**自動では有効にならない。** 使うなら1回選ぶ — `/config` の **Output style** から `kjfsm` を選ぶか、設定ファイルに直接書く:

```json
{
  "outputStyle": "kjfsm"
}
```

出力スタイルが効くのは**メインの会話だけ**で、サブエージェントには届かない。レビューや調査を子コンテキストに投げたときにも同じ規約を効かせたいなら、`/kjfsm-skills:setup-repo` を実行して `CLAUDE.md` / `AGENTS.md` 側にも書かせること — そちらはサブエージェントにも読まれる。

### サブエージェント

プラグインには5体の[サブエージェント](https://code.claude.com/docs/en/sub-agents)が同梱されている。どれもスキルから起動される — 名前を覚えて呼ぶものではない。

| エージェント         | 呼ぶスキル                        | 何を押し出すか                                   |
| -------------------- | --------------------------------- | ------------------------------------------------ |
| `verifier`           | `/kjfsm-skills:verification-loop` | 型チェック・lint・テスト・ビルドの生ログ         |
| `standards-reviewer` | `/kjfsm-skills:two-axis-review`   | Standards 軸(明文化された標準、スメル、Why not)  |
| `spec-reviewer`      | `/kjfsm-skills:two-axis-review`   | Spec 軸(元のイシュー/PRD との突き合わせ)         |
| `comment-pruner`     | `/kjfsm-skills:prune-comments`    | 触れたファイルのコメントを6段のルールで削る1パス |
| `test-auditor`       | `/kjfsm-skills:prune-tests`       | テストの棚卸しと削除・統合の判定(スライスごと)   |

理由は並列化ではなく **押し出し** である — 中間のツール結果は子のコンテキストに留まり、親に戻るのは要約だけになる(→ [`/kjfsm-skills:delegation`](./skills/kjfsm-skills/engineering/delegation/SKILL.md))。`verifier` が `Edit` も `Write` も持たないのは意図で、ゲートを回す側がゲートを動かせてはならない。`comment-pruner` を分けてあるのは、**直前に自分で書いたコメントは目的が思い出せてしまう分だけ残る**からである。`test-auditor` を分けてあるのは、数百のテストファイルを1つのコンテキストで読むと後半ほど判定が雑になるからで、`Write` は棚卸し表を書き出すためにだけ持つ。二軸のレビュアーを2体に分けてあるのも同じく意図で、**互いのコンテキストを汚染しないこと自体が成果物である。**

**A と C ではこれらは入らない。** 呼ぶ側のスキルは依頼内容をエージェント側に預けているので、落ちる先は汎用のサブエージェントか手元の実行になり、**規律の本文はそこには無い** — `/kjfsm-skills:two-axis-review` の Standards 軸はスメルの基準線を、`/kjfsm-skills:prune-comments` は6段のルールを、`/kjfsm-skills:prune-tests` は判定の問いと6分類を失う。この3つを本来の形で使うなら B を選ぶ。

## これらのスキルが存在する理由

コーディングエージェントで繰り返し起きる4つの失敗モードと、各スキルが当てる対処法:

**エージェントが望んだ通りに動かなかった。** ミスアライメントはソフトウェア開発で最もよくある失敗モードである — エージェントが理解してくれたと思っていたのに、できあがったものを見て実はそうでなかったと気づく。対処法は **グリリングセッション**: 作り始める前に、作ろうとしているものについて詳細な質問をエージェントにさせることである。`/mattpocock-skills:grill-me`(コードベースなし)と `/mattpocock-skills:grill-with-docs`(コードベースあり)を参照。

**エージェントが冗長すぎる。** 共有された語彙がなければ、エージェントは1語で済むところに20語を使い、物事の名付け方も一貫しなくなる。対処法は、プロジェクトの専門用語を解読するドキュメントである — `/mattpocock-skills:grill-with-docs` に組み込まれており、グリリングをしながら `CONTEXT.md` と ADR を保守する。

**コードが動かない。** 何を作るか意識をそろえていても、フィードバックを受け取れずに手探りで進むエージェントは質の悪いコードを生む。対処法は、いつものひとそろいのフィードバックループ — 静的型付け、ブラウザへのアクセス、自動テスト — であり、レッド・グリーン・リファクタリングのループが仕事の大半を担う。`/mattpocock-skills:tdd` と `/mattpocock-skills:diagnosing-bugs` を参照。作り終えた変更が本当に動くかは [`/kjfsm-skills:verification-loop`](./skills/kjfsm-skills/engineering/verification-loop/SKILL.md) が締める — 記録されたゲートを中断なく1回で通し、変更した経路を実際に駆動して観測する。

**コードベースが泥団子になった。** エージェントはコーディングを劇的に加速させるが、それはソフトウェアのエントロピーも加速させる。対処法は、あらゆる層でコードの設計を気にかけることである — `/mattpocock-skills:to-spec`(スペックを書く前にどのモジュールが影響を受けるか問いを立てる)と `/mattpocock-skills:improve-codebase-architecture`(コードベースが泥団子へと漂流しつつあるのを定期的に捉える)を参照。

## リファレンス

これらは1つの軸で分かれる — 誰がそれを呼び出せるか。**ユーザー呼び出し型** のスキルは、あなたが入力したとき(例: `/mattpocock-skills:grill-me`)だけ到達できる。その役目はオーケストレーションである。**モデル呼び出し型** のスキルは、あなたが呼び出すこともできるし、タスクに合致すればエージェントが自動的に手を伸ばすこともできる。それらは再利用可能な規律を保持する。ユーザー呼び出し型のスキルはモデル呼び出し型のスキルを呼び出せるが、別のユーザー呼び出し型のスキルは決して呼び出せない。

### Engineering

日々のコード作業のためのスキル。

<!-- catalog:begin kjfsm-skills/engineering -->

**ユーザー呼び出し型**

- **[ask-kjfsm](./skills/kjfsm-skills/engineering/ask-kjfsm/SKILL.md)** — どのスキルやフローが自分の状況に合うかを尋ねる。このリポジトリのスキルを案内するルーター。
- **[implement-and-review](./skills/kjfsm-skills/engineering/implement-and-review/SKILL.md)** — スペックやチケットが記述する作業を、既定ブランチへの追従からビルド・検証・コメント削り・二軸レビュー・PR まで1本で進める。
- **[setup-repo](./skills/kjfsm-skills/engineering/setup-repo/SKILL.md)** — このリポジトリのエージェント向け設定を一括で敷く — 規約とドキュメント配置、パス別ルール、CI、弾く機構。再実行すると現況を読み、足りない工程とずれた箇所だけを当てる。
- **[squash-d1-migrations](./skills/kjfsm-skills/engineering/squash-d1-migrations/SKILL.md)** — 積み上がった D1 のマイグレーションを1本に畳み、適用済みの各環境と突き合わせる。
- **[tend-memory-files](./skills/kjfsm-skills/engineering/tend-memory-files/SKILL.md)** — AGENTS.md・CLAUDE.md と .claude/rules/ を新規に書く、または既存のものを監査してトリムする — 行数の目安に収め、具体的で矛盾のない指示だけを残す。

**モデル呼び出し型**

- **[ai-efficiency](./skills/kjfsm-skills/engineering/ai-efficiency/SKILL.md)** — 大量のファイル移動・リネーム・import 付け替えを、1ファイルずつ読み書きせずシェルで機械的に処理する戦略。「大量リネーム」「一括置換」「ディレクトリ再編」「import パスの一括付け替え」などで参照する。
- **[d1-bound-parameters](./skills/kjfsm-skills/engineering/d1-bound-parameters/SKILL.md)** — Cloudflare D1 へ多数の値を渡すクエリの規律 — bound parameter は1文あたり100個まで。`D1_ERROR: too many SQL variables` が出たとき、D1 へ大量の行を INSERT するとき、`inArray` / `IN (...)` に長い ID の列を渡すとき、`db.batch()` で分割するときに使う。
- **[delegation](./skills/kjfsm-skills/engineering/delegation/SKILL.md)** — 作業をサブエージェントの子コンテキストへ押し出し、タスクに見合ったモデル階層に回す判断。サブエージェントを起動するとき、大量の出力を伴う作業を始めるとき、他のスキルが委譲の語彙を必要とするときに使う。
- **[dev-bypass-sign-in](./skills/kjfsm-skills/engineering/dev-bypass-sign-in/SKILL.md)** — 叩くだけでサインイン済みになる開発・E2E 用の入口(dev bypass)を作る。ログインの要る画面を E2E やエージェントから駆動したいとき、dev サーバーでソーシャルログインやパスワード登録を踏まずに座りたいとき、better-auth の `testUtils` の使いどころを決めるとき、既存の bypass の戸が本番の成果物に残っていないか確かめたいとき、他のスキルが認証済みのセッションを必要とするときに使う。
- **[drizzle-generate-non-interactive](./skills/kjfsm-skills/engineering/drizzle-generate-non-interactive/SKILL.md)** — TTY の無いところで `drizzle-kit generate` を完走させる。エージェント・フック・CI から generate を回すとき、`Interactive prompts require a TTY terminal` で落ちたとき、`missing_hints` で exit 2 したとき、rename を含むスキーマ変更のマイグレーションを生成するときに使う。
- **[migrate-d1](./skills/kjfsm-skills/engineering/migrate-d1/SKILL.md)** — Cloudflare D1 のスキーマを変えるときの規律。drizzle-kit などが `PRAGMA foreign_keys=OFF` と `DROP TABLE` を含むマイグレーションを生成したとき、列を NOT NULL にしたいとき、CHECK 制約や複合ユニークを足したいとき、本番に `--remote` でマイグレーションを当てる前に使う。**D1 では `PRAGMA foreign_keys=OFF` が効かないので、生成物をそのまま流すと参照している側のテーブルが空になる。**
- **[partyserver-on-durable-objects](./skills/kjfsm-skills/engineering/partyserver-on-durable-objects/SKILL.md)** — partyserver(`Server`)を Durable Object の上に載せるときの、公式ドキュメントに載っていない挙動。stub の取り方でリクエスト数が2倍になるとき、`onStart` に初期化や移行を置くとき、WebSocket のハイバネーションと keepalive を組むとき、RPC メソッドを足すか `onRequest` のままにするか決めるときに使う。素の Durable Objects の API は公式の `durable-objects` スキルが持つ。
- **[prune-comments](./skills/kjfsm-skills/engineering/prune-comments/SKILL.md)** — 書かれてしまったコメントを1パスで削る。コミットや PR を出す直前、コメントが冗長・AI が書いたように見える・整理したいとき、他のスキルがコメントの掃除を必要とするときに使う。順序の決まった6段のルールと非対称の残す基準を当て、実行ごとのばらつきを潰す。
- **[prune-tests](./skills/kjfsm-skills/engineering/prune-tests/SKILL.md)** — 既存のテストを全部読み、削除・統合できるものを「消すと、どんな現実的な不具合を見逃すか」で洗い出す。テストが多すぎる・遅い・振る舞いを変えない変更のたびに大量に落ちるとき、テストを整理したい・減らしたいとき、他のスキルが削れるテストの判定を必要とするときに使う。
- **[react-router-route-module](./skills/kjfsm-skills/engineering/react-router-route-module/SKILL.md)** — React Router（framework mode）の route module に何をどの export へ置くかの規律。認可ガードを足すとき、loader と action に同じチェックを書いているとき、レイアウトが持つ値を配下のコンポーネントへ渡したいとき、`useRouteLoaderData` と `<Outlet context>` のどちらを使うか迷ったとき、Cloudflare Workers の `env` を loader / action へ渡すときに使う。
- **[setup-cf-access](./skills/kjfsm-skills/engineering/setup-cf-access/SKILL.md)** — Cloudflare Access を Worker・ホスト名・パスに、いつもの3層ルール(人間=指定メール / 機械=サービストークン / アプリ側に認証があるパス=bypass)で掛ける。「Access を掛ける」「認証を必要にする」「workers.dev が素通り」「Zero Trust のアプリを作る」で参照する。
- **[setup-cf-app](./skills/kjfsm-skills/engineering/setup-cf-app/SKILL.md)** — 新規の Cloudflare Workers フルスタックアプリを、いつも使う標準ライブラリ構成で立ち上げる。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
- **[setup-ci](./skills/kjfsm-skills/engineering/setup-ci/SKILL.md)** — 記録された検証ゲートを CI に敷き、ローカルの規律を機構に変える。ゲートを強制する仕組みがまだ無いとき（CI が無い、あるいは誰も走らせていない）、CI が `docs/agents/verification.md` とずれてきたとき、`/kjfsm-skills:setup-repo` の工程 C として使う。
- **[setup-hooks](./skills/kjfsm-skills/engineering/setup-hooks/SKILL.md)** — 散文のルールでは守られないものを機構へ落とし、決定的に弾く — `permissions.deny`、git hook と CI が同じ述語を呼ぶ検査スクリプト、Claude Code のフックの3層。書いてある規約が実際には破られ続けているとき（生成物の手編集、シークレットのコミット）、フックにだけ存在する検査が CI やクローンをすり抜けているとき、セッション開始時に環境を用意させたいとき、`/kjfsm-skills:setup-repo` の工程 D として使う。
- **[setup-playwright](./skills/kjfsm-skills/engineering/setup-playwright/SKILL.md)** — Playwright の E2E を入れ、ブラウザをどの層で用意するか決める。E2E をこれから入れるとき、`Executable doesn't exist` や `Missing system dependencies` が出たとき、コンテナやクラウドのサンドボックスに置いてあるブラウザと Playwright が要求するビルド番号がずれたとき、CI でだけブラウザの取得に失敗するとき、`playwright install` をセットアップスクリプト・SessionStart フック・CI のどこに置くか決めるときに使う。
- **[setup-rules](./skills/kjfsm-skills/engineering/setup-rules/SKILL.md)** — このリポジトリのルールを `.claude/rules/` と `AGENTS.md` の2層に敷く — パスに応じて自動注入されるパス別ルールと、全セッションに効く絶対ルール。Claude Code を使うリポジトリを初めて設定するとき、`.claude/rules/` がまだ無いとき、同じ指摘を2回以上受けてルールに落としたいとき、`/kjfsm-skills:setup-repo` の工程 B として使う。
- **[setup-skills](./skills/kjfsm-skills/engineering/setup-skills/SKILL.md)** — このリポジトリをエンジニアリング系スキル向けに設定する — イシュートラッカー、トリアージラベルの語彙、ドメインドキュメントの配置、検証ゲート、応答と記述の規約。`docs/agents/` がまだ無いとき、他のエンジニアリング系スキルを初めて使う前、`/kjfsm-skills:setup-repo` の工程 A として使う。
- **[two-axis-review](./skills/kjfsm-skills/engineering/two-axis-review/SKILL.md)** — まだコミットしていない編集と新規ファイルまで含めて、差分を kjfsm のレビュアー2体で並列にレビューする — Standards(明文化された標準、Fowler のスメル、書かれなかった Why not)と Spec(元のイシュー/PRD)。範囲は固定した基点(コミット、ブランチ、タグ)とのマージベースから作業ツリーまで。コミット前の作業をレビューしたいとき、ブランチ・PR・進行中の変更をレビューしたいとき、「X 以降をレビューして」と求めたとき、他のスキルが差分のレビューを必要とするときに使う。
- **[verification-loop](./skills/kjfsm-skills/engineering/verification-loop/SKILL.md)** — 変更が本当に動くことを、記録された検証ゲートのクリーンラン — 型チェック、lint、テスト、ビルド、そして実際に動かしての観測 — で確かめる。ユーザーが動作確認や検証を求めたとき、変更を完了と宣言する前(コミットや PR を出す直前)、他のスキルが作業の検証を必要とするときに使う。
- **[where-to-write-what](./skills/kjfsm-skills/engineering/where-to-write-what/SKILL.md)** — コード・テスト・コメント・JSDoc・コミットメッセージ・PR 本文・ADR・docs のどこに何を書くかを決めるルーティング規律 — コードには How、テストには What、コミットログには Why、コメントには Why not。コメントを書くか消すか判断するとき、JSDoc に何を載せるか決めるとき、コミットメッセージや PR 本文を書くとき、README を足すか迷ったとき、実装の背景や設計判断をどこに残すか迷ったときに使う。
- **[workers-tests](./skills/kjfsm-skills/engineering/workers-tests/SKILL.md)** — Cloudflare Workers のプロジェクトでテストスイートを作る・立て直すときの規律。テストが1本も無いところから始めるとき、vitest.config が複雑すぎる・テストが遅い・OOM する・vi.mock だらけで信用できないとき、@cloudflare/vitest-plugin(旧 @cloudflare/vitest-pool-workers)を上げたら壊れたとき、React Router などの SSR を `main` に載せていて1ファイルに十数秒かかる・`applyD1Migrations` が遅い・`createTestHarness` で HTTP の層を作るとき、Workers / D1 / Durable Objects / Queues にテストを入れたいときに使う。

<!-- catalog:end -->

### Productivity

コードに限らない、一般的なワークフローツール。

<!-- catalog:begin kjfsm-skills/productivity -->

**モデル呼び出し型**

- **[sharpen-request](./skills/kjfsm-skills/productivity/sharpen-request/SKILL.md)** — 曖昧な改善・整理の依頼を、1項目ずつ判定できる問いと止まる地点を持った指示に研ぐ。「〜を整理したい」「〜を改善したい」のように、既にあるものを良くしたい依頼が何をもって良いかを言わずに来たとき、同じ指示を複数のリポジトリやセッションに配りたいときに使う。
- **[writing-great-skills](./skills/kjfsm-skills/productivity/writing-great-skills/SKILL.md)** — スキルを書く・直すための判断基準と、公式が定める仕様。SKILL.md を新規に書くとき、既存のスキルを編集・分割・刈り込むとき、description のトリガーを調整するとき、name や description の文字数上限・frontmatter の書き方を確かめるとき、スキルが発火しない・実行ごとに動きがばらつく原因を診断するときに使う。

<!-- catalog:end -->

本家由来のスキル(`/mattpocock-skills:grill-me`、`/mattpocock-skills:grill-with-docs`、`/mattpocock-skills:tdd`、`/mattpocock-skills:diagnosing-bugs`、`/mattpocock-skills:to-spec`、`/mattpocock-skills:to-tickets`、`/mattpocock-skills:triage`、`/mattpocock-skills:wayfinder` ほか)は依存先の本家が配るので、ここには載らない。一覧は[本家の README](https://github.com/mattpocock/skills#readme) にある。

### その他のバケット

昇格していない(`kjfsm-skills` へのエントリなし、上記の README への掲載もなし) — 中身については各バケット自身の `README.md` を参照:

- [`skills/kjfsm-emdash/`](./skills/kjfsm-emdash/README.md) — [EmDash](https://docs.emdashcms.com) CMS のサイト専用。EmDash を使わないプロジェクトでは無価値なので、別プラグイン `kjfsm-emdash` でサイトのリポジトリにだけ入れる
- [`skills/kjfsm-personal/`](./skills/kjfsm-personal/README.md) — この端末固有のセットアップに紐づく。別プラグイン `kjfsm-personal` で自分の端末にだけ入れる
- [`skills/in-progress/`](./skills/in-progress/README.md) — まだ出荷準備が整っていない下書き

退役したスキルは削除する。理由と代わりに使うものは [`.agents/retired-skills.md`](./.agents/retired-skills.md) にある。
