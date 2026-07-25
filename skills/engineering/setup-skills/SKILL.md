---
name: setup-skills
description: このリポジトリをエンジニアリング系スキル向けに設定する — イシュートラッカー、トリアージラベルの語彙、ドメインドキュメントの配置をセットアップする。他のエンジニアリング系スキルを初めて使う前に一度実行する。
disable-model-invocation: true
---

# Setup Skills

エンジニアリング系スキルが前提とする、リポジトリごとの設定を組み立てる:

- **イシュートラッカー** — イシューがどこにあるか(デフォルトは GitHub。ローカルの markdown もそのまま対応)
- **トリアージラベル** — 5つの正規のトリアージロールに使われる文字列
- **ドメインドキュメント** — `CONTEXT.md` と ADR がどこにあり、それらを読む側のルールは何か
- **検証ゲート** — 変更が動くと確かめるために、どのコマンドをどの順で走らせるか

これはプロンプト駆動のスキルであり、決定的なスクリプトではない。探索し、見つけたものを提示し、ユーザーと確認し、それから書く。

## 手順

### 1. 探索する

現在のリポジトリを見て、その出発点の状態を理解する。何が存在するかを読み、決めつけない:

- `git remote -v` と `.git/config` — これは GitHub のリポジトリか? どのリポジトリか?
- リポジトリルートの `AGENTS.md` と `CLAUDE.md` — どちらかが存在するか? すでにどちらかに `## Agent skills` セクションがあるか?
- リポジトリルートの `CONTEXT.md` と `CONTEXT-MAP.md`
- `docs/adr/` とあらゆる `src/*/docs/adr/` ディレクトリ
- `docs/agents/` — このスキルの過去の出力がすでに存在するか?
- `.scratch/` — ローカル markdown のイシュートラッカー規約がすでに使われている印
- `package.json` の scripts、`Makefile`、`Taskfile`、`turbo.json`、`.github/workflows/*.yml` などの CI 設定 — このリポジトリが実際に使っている検証コマンド。加えて、アプリを起動する手段(開発サーバー、CLI のエントリ、E2E のランナー)
- `triage` スキルはインストールされているか?(このスキルの隣にある `triage` スキルのフォルダ、または利用可能なスキルの中に `triage` があるか)これによって Section B をそもそも実行するかどうかが決まる。
- モノレポの兆候 — `pnpm-workspace.yaml`、`package.json` の `workspaces` フィールド、または独自の `src/` を持つ中身のある `packages/*`。本当に大きな複数パッケージのリポジトリにのみ存在する。これらがなければ単一コンテキストであり、それがほぼすべてのリポジトリに当てはまる。

### 2. 発見を提示し、尋ねる

何があり、何がないかを要約する。それからセクションを順番に進める — 1セクションにつき1つの答え、それから次へ。

各セクションは推奨する答えから始め、ユーザーが一言で受け入れられるようにする。選択が本当に分かれる場合にだけ1行の説明を加える。探索によってすでに決まっているセクションは丸ごとスキップする(`triage` がインストールされていなければ Section B、モノレポでなければ Section C)。

**Section A — イシュートラッカー。**

> 説明: 「イシュートラッカー」とは、このリポジトリのイシューが存在する場所である。`to-tickets`、`triage`、`to-spec`、`qa` のようなスキルはここから読み書きする — それらは、`gh issue create` を呼ぶべきか、`.scratch/` 配下にマークダウンファイルを書くべきか、あなたが説明する何か別のワークフローに従うべきかを知る必要がある。このリポジトリで実際に作業を追跡している場所を選ぶ。

デフォルトの姿勢: これらのスキルは GitHub 向けに設計されている。`git remote` が GitHub を指していれば、それを提案する。`git remote` が GitLab(`gitlab.com` かセルフホストのホスト)を指していれば、GitLab を提案する。そうでなければ(あるいはユーザーが望めば)、次を提示する:

- **GitHub** — イシューはこのリポジトリの GitHub Issues にある(`gh` CLI を使う)
- **GitLab** — イシューはこのリポジトリの GitLab Issues にある([`glab`](https://gitlab.com/gitlab-org/cli) CLI を使う)
- **ローカル markdown** — イシューはこのリポジトリの `.scratch/<feature>/` 配下のファイルとしてある(個人プロジェクトや remote のないリポジトリに向く)
- **その他**(Jira、Linear など) — ユーザーにそのワークフローを1段落で説明してもらう。このスキルはそれを自由な文章として記録する

選んだ内容を `docs/agents/issue-tracker.md` に記録する。GitHub と GitLab のテンプレートは「PR を要望の受け口として扱う」フラグを持ち、デフォルトは **オフ** である — オフのままにし、こちらから提起しない。外部の PR をトリアージのキューに含めたいユーザーは、後でそのファイル内でフラグを切り替えられる。

**Section B — トリアージラベルの語彙。** `triage` スキルがインストールされていなければ(探索でそう分かった場合)、このセクションは丸ごとスキップする — インストールされていないスキルにラベルは不要である。

インストールされている場合は、正確に1つの質問をする:

> デフォルトのトリアージラベルをそのまま使いますか?(推奨: **はい**)

デフォルトは5つの正規のロールであり、各ラベル文字列はその名前と同じである: `needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。**はい** ならそのまま書く。ユーザーが「いいえ」と答えた場合 — たいていはそのトラッカーがすでに別の名前(例えば `needs-triage` に対して `bug:triage`)を使っているため — だけ、上書き内容を集め、`triage` が重複を作らず既存のラベルを適用できるようにする。

**Section C — ドメインドキュメント。** デフォルトは **単一コンテキスト** — リポジトリルートに `CONTEXT.md` と `docs/adr/` を1組。これはほぼすべてのリポジトリに合うので、尋ねずに書く。

**複数コンテキスト** — コンテキストごとの `CONTEXT.md` ファイルを指すルートの `CONTEXT-MAP.md` — は、探索でモノレポの兆候が見つかったときにだけ提案する。そのうえで、どちらの配置を望むか確認する。

**Section D — 検証ゲート。** 変更が本当に動くと確かめる方法 — `/verification-loop` が上から順に走らせるコマンド列。

探索で **実際に見つけたコマンドだけ** から提案する。慣習から推測して埋めない。そのうえで1問だけ尋ねる:

> この順序でよいですか?(推奨: 速いものから — 型チェック → lint → テスト → ビルド → 観測)

**観測** の行は他と違う。これはアプリを起動して、変更した経路を実際に1度通す手段である(開発サーバーの起動コマンドと叩く URL、Playwright スクリプト、CLI の呼び出しなど)。駆動できるものが何もないリポジトリでは空のままにし、その理由を書く。

**カスタムチェック** — 汎用のリンターが見逃す、このリポジトリ固有の決定的なルール。デフォルトは **なし** であり、こちらから捻り出さない。`/verification-loop` のラチェットが、実際に手作業で捕まえた不具合からここを埋めていく。

### 3. 確認して編集する

ユーザーに次の下書きを見せる:

- 編集対象となる `CLAUDE.md` / `AGENTS.md` のどちらかに追加する `## Agent skills` ブロック(選び方は手順4を参照)
- `docs/agents/issue-tracker.md`、`docs/agents/domain.md`、`docs/agents/verification.md`、`docs/agents/triage-labels.md` の内容(最後のものは `triage` がインストールされている場合のみ)

書く前に、ユーザーに編集させる。

### 4. 書く

**編集するファイルを選ぶ:**

- `CLAUDE.md` が存在すれば、それを編集する。
- そうでなく `AGENTS.md` が存在すれば、それを編集する。
- どちらも存在しなければ、どちらを作成するかユーザーに尋ねる — 代わりに選ばない。

`CLAUDE.md` がすでに存在するのに `AGENTS.md` を新たに作成しない(逆も同様) — 常にすでにある方を編集する。

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
```

`### Triage labels` サブブロックの記載と `docs/agents/triage-labels.md` の作成は、`triage` がインストールされていて Section B が実行された場合にのみ行う。そうでない場合は、両方とも省略する。

それから、このスキルのフォルダにある元テンプレートを出発点として、ドキュメントファイルを書く:

- [issue-tracker-github.md](./issue-tracker-github.md) — GitHub イシュートラッカー
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md) — GitLab イシュートラッカー
- [issue-tracker-local.md](./issue-tracker-local.md) — ローカル markdown イシュートラッカー
- [triage-labels.md](./triage-labels.md) — ラベルの対応付け(`triage` がインストールされている場合のみ)
- [domain.md](./domain.md) — ドメインドキュメントを読む側のルール+配置
- [verification.md](./verification.md) — 検証ゲート、観測の手段、カスタムチェック

「その他」のイシュートラッカーについては、ユーザーの説明を使ってゼロから `docs/agents/issue-tracker.md` を書く。

### 5. 完了

セットアップが完了したこと、そしてどのエンジニアリング系スキルが今後これらのファイルから読み込むかをユーザーに伝える。`docs/agents/*.md` は後で直接編集できることに触れる — このスキルの再実行が必要になるのは、イシュートラッカーを切り替えたいときや、ゼロからやり直したいときだけである。
