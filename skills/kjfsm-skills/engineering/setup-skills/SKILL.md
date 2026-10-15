---
name: setup-skills
description: このリポジトリをエンジニアリング系スキル向けに設定する — イシュートラッカー、トリアージラベルの語彙、ドメインドキュメントの配置、検証ゲート、応答と記述の規約。`docs/agents/` がまだ無いとき、他のエンジニアリング系スキルを初めて使う前、`/kjfsm-skills:setup-repo` の工程 A として使う。
---

# Setup Skills

エンジニアリング系スキルが前提とする、リポジトリごとの設定を組み立てる:

- **イシュートラッカー** — イシューがどこにあるか(既定は GitHub)
- **トリアージラベル** — 5つのトリアージロールに使う文字列
- **ドメインドキュメント** — `CONTEXT.md` と ADR の置き場所と、読む側のルール
- **検証ゲート** — 変更が動くと確かめるコマンドとその順序
- **応答と記述の規約** — ユーザーに話す言語と、書いたものの宛先

## 手順

### 1. 探索する

何が存在するかを読み、決めつけない:

- `git remote -v` — GitHub か GitLab か、どのリポジトリか
- リポジトリルートの `AGENTS.md` と `CLAUDE.md` — どちらが存在し、どちらが本文を持つか(`CLAUDE.md` が `@AGENTS.md` を取り込むだけか、symlink か、実体か)? すでにどちらかに `## Agent skills` セクションがあるか?
- リポジトリルートの `CONTEXT.md` と `CONTEXT-MAP.md`
- `docs/adr/` とあらゆる `src/*/docs/adr/` ディレクトリ
- `docs/agents/` — このスキルの過去の出力がすでに存在するか?
- `.scratch/` — ローカル markdown のイシュートラッカー規約がすでに使われている印
- `package.json` の scripts、`Makefile`、`Taskfile`、`turbo.json`、`.github/workflows/*.yml` — 実際に使っている検証コマンドと、アプリを起動する手段(開発サーバー、CLI のエントリ、E2E のランナー)
- `triage` スキルの有無(Section B を回すか) — ユーザー呼び出し型なので利用可能なスキルの一覧には出ない。`claude plugin list` に `mattpocock-skills` があれば在る。決められなければ訊く。`where-to-write-what` の有無(Section E がそれを指すか)はモデル呼び出し型なので一覧で探す
- モノレポの兆候 — `pnpm-workspace.yaml`、`package.json` の `workspaces`、独自の `src/` を持つ中身のある `packages/*`。無ければ単一コンテキストで、ほぼすべてのリポジトリがこれに当たる

### 2. 発見を提示し、尋ねる

何があり、何がないかを要約し、セクションを1つずつ進める — 1セクションにつき1つの答え。

各セクションは推奨する答えから始め、一言で受け入れられるようにする。選択が本当に分かれる場合にだけ1行の説明を足す。探索で決まったセクションは飛ばす(`triage` が無ければ B、モノレポでなければ C)。

**Section A — イシュートラッカー。**

`to-tickets`・`triage`・`to-spec` などがイシューを読み書きする場所。`git remote` が GitHub なら GitHub を、GitLab(`gitlab.com` かセルフホスト)なら GitLab を提案する。どちらでもなければ次から選んでもらう:

- **GitHub**(`gh`)/ **GitLab**([`glab`](https://gitlab.com/gitlab-org/cli))
- **ローカル markdown** — `.scratch/<feature>/` 配下のファイル。個人プロジェクトや remote の無いリポジトリ向け
- **その他**(Jira、Linear など) — ワークフローを1段落で説明してもらい、そのまま記録する

`docs/agents/issue-tracker.md` に記録する。テンプレートの「PR を要望の受け口として扱う」フラグは **オフ** のままにし、こちらから提起しない — 既定値も切り替え方もテンプレート自身が書いている。

**Section B — トリアージラベルの語彙。** `triage` が入っているときだけ、1問だけ尋ねる:

> デフォルトのトリアージラベルをそのまま使いますか?(推奨: **はい**)

デフォルトはロール名そのまま: `needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。「いいえ」(たいていはトラッカーが `bug:triage` のような別名を使っている)のときだけ対応を集め、`triage` が重複を作らず既存のラベルを使えるようにする。

**Section C — ドメインドキュメント。** 既定は **単一コンテキスト**(ルートに `CONTEXT.md` と `docs/adr/` を1組)で、尋ねずに書く。**複数コンテキスト**(コンテキストごとの `CONTEXT.md` を指すルートの `CONTEXT-MAP.md`)は、モノレポの兆候があったときだけ提案し、どちらにするか確認する。

**Section D — 検証ゲート。** `/kjfsm-skills:verification-loop` が上から順に走らせるコマンド列。探索で **実際に見つけたコマンドだけ** から提案し、慣習から推測して埋めない。1問だけ尋ねる:

> この順序でよいですか?(推奨: 速いものから — 型チェック → lint → テスト → ビルド → 観測)

**観測** と **カスタムチェック** の2行は他と違う扱いになる。どちらも既定は空で、何を書くかは [verification.md](./verification.md) が持つ。

**Section E — 応答と記述の規約。** 1問だけ尋ねる:

> ユーザーへの応答は日本語、書いたものの宛先は `where-to-write-what` に従う。これでよいですか?(推奨: **はい**)

「いいえ」なら応答言語だけ差し替える。宛先の規律は差し替えない。`where-to-write-what` が無い場合は、スキルを指す最後の 1 段落だけを落とす — 4本の柱とコメントの判定はこのブロックが単体で持っている。

**ユーザーの `~/.claude/CLAUDE.md` に4本の柱とコメントの判定が本文で載っていれば、リポジトリには書かない**(サブエージェントにも届く。写すとずれる)。応答言語もそこにあれば `### Conventions` ごと省く(ADR 0007)。

このセクションだけは **ブロックの中に本文を置く** — 規約は毎セッション読まれなければ効かず、スキルへの参照ではコメントを書く場面で呼ばれない。8 行に収める。出力スタイルで同じことを指定済みでも消さない — 出力スタイルは(fork を除く)サブエージェントに届かないが、本体のファイルは届く。

**手順4で本体が `CLAUDE.md` のまま残ると決まったら、[claude-md.md](./claude-md.md) を読む。** 本文の置き場所が変わる。

### 3. 確認して編集する

ユーザーに次の下書きを見せる:

- 本体(手順4)に追加する `## Agent skills` ブロックと、`AGENTS.md` へ移す・`CLAUDE.md` を消すならその変更
- `.claude/rules/writing-conventions.md` の内容(本体が `CLAUDE.md` のままの場合のみ。[claude-md.md](./claude-md.md))
- グローバルにあるので省く規約(Section E)。`~` の無いクラウドでも効かせるなら書く
- `docs/agents/issue-tracker.md`、`docs/agents/domain.md`、`docs/agents/verification.md`、`docs/agents/triage-labels.md` の内容(最後のものは `triage` がインストールされている場合のみ)

書く前に、ユーザーに編集させる。

### 4. 書く

**本体は `AGENTS.md` で、`CLAUDE.md` は置かない。** Claude Code は、作業ディレクトリとその上に `CLAUDE.md` も `CLAUDE.local.md` も無いときだけ `AGENTS.md` を直接読む。1行の `CLAUDE.md`(`@AGENTS.md`)は、`CLAUDE.local.md` を使う人か v2.1.277 未満の人がいるリポジトリにだけ残す。symlink は使わない(Windows のクローンで1行のテキストになる)。根拠は ADR 0007。

- **どちらも無い** → `AGENTS.md` を作って編集する
- **`AGENTS.md` だけ** → `AGENTS.md` を編集する
- **`CLAUDE.md` が `@AGENTS.md`(と Claude Code 専用の追記)だけ、または `AGENTS.md` への symlink** → 追記を `AGENTS.md` か `.claude/rules/` へ移し、`CLAUDE.md` を消す案を手順3で見せる(例外なら1行で残す)
- **`CLAUDE.md` だけ、または `AGENTS.md` が `CLAUDE.md` への symlink** → `git mv CLAUDE.md AGENTS.md` の案を手順3で見せ、同意を得て移す。断られたら `CLAUDE.md` を本体として編集する
- **両方が別々の中身を持つ** → どちらにも書き足さず、`AGENTS.md` へ統合するかをユーザーに訊く

選んだファイルにすでに `## Agent skills` ブロックが存在する場合は、重複を追記するのではなく、その場で内容を更新する。周囲のセクションへのユーザーによる編集を上書きしない。

このブロック:

```markdown
## Agent skills

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout — "single-context" or "multi-context"]. See `docs/agents/domain.md`.

### Verification gates

[one-line summary of the gate chain]. See `docs/agents/verification.md`.

### Conventions

[応答言語の指定を1行]。

**コードには How、テストには What、コミットログには Why、コードコメントには Why not。**

コードを読めば分かることは書かない。書いたものを消してコードだけを読み、失われる情報が無ければ、その宛先はコードだった — 命名・関数抽出・型で言い直し、コメントは消す。**周囲に合わせるのは命名とイディオムであって、コメントの密度ではない。**

コメントが運ぶのはコードから読めない情報に限る: 採らなかった素直な書き方とそれがだめな理由、外部の制約(API 仕様・RFC・プラットフォームの上限)、不変条件と順序依存、issue や ADR への参照 1 行。それ以外は宛先が違う — 逐語的な説明(「〜を取得」「〜を更新」)はコード自体へ、変更の経緯はコミットメッセージへ、使わなくなったコードは削除して git 履歴へ。

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は `where-to-write-what` スキルが決める。書く前にそれを読む。
```

`### Triage labels` サブブロックの記載と `docs/agents/triage-labels.md` の作成は、`triage` がインストールされていて Section B が実行された場合にのみ行う。そうでない場合は、両方とも省略する。

`### Conventions` の本文は Section E の答えで決まる。

続けて、このフォルダのテンプレートを出発点にドキュメントを書く:

- [issue-tracker-github.md](./issue-tracker-github.md) — GitHub イシュートラッカー
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md) — GitLab イシュートラッカー
- [issue-tracker-local.md](./issue-tracker-local.md) — ローカル markdown イシュートラッカー
- [triage-labels.md](./triage-labels.md) — ラベルの対応付け(`triage` がインストールされている場合のみ)
- [domain.md](./domain.md) — ドメインドキュメントを読む側のルール+配置
- [verification.md](./verification.md) — 検証ゲート、観測の手段、カスタムチェック

「その他」のイシュートラッカーについては、ユーザーの説明を使ってゼロから `docs/agents/issue-tracker.md` を書く。

### 5. パス別ルールを敷く

Claude Code を使うリポジトリなら、続けて `/kjfsm-skills:setup-rules` を実行する(`/kjfsm-skills:setup-repo` 経由なら、そちらが持つ)。パスで注入される `.claude/rules/` はそちらが敷く。

### 6. 完了

どのスキルがこれらのファイルを読むかを伝え、`docs/agents/*.md` は直接編集してよいと添える。
