---
name: setup-skills
description: このリポジトリをエンジニアリング系スキル向けに設定する — イシュートラッカー、トリアージラベルの語彙、ドメインドキュメントの配置、検証ゲート、応答と記述の規約。`docs/agents/` がまだ無いとき、他のエンジニアリング系スキルを初めて使う前、`/kjfsm-skills:setup-repo` の工程 A として使う。
---

# Setup Skills

エンジニアリング系スキルが前提とする、リポジトリごとの設定を組み立てる:

- **イシュートラッカー** — イシューがどこにあるか(デフォルトは GitHub。ローカルの markdown もそのまま対応)
- **トリアージラベル** — 5つの正規のトリアージロールに使われる文字列
- **ドメインドキュメント** — `CONTEXT.md` と ADR がどこにあり、それらを読む側のルールは何か
- **検証ゲート** — 変更が動くと確かめるために、どのコマンドをどの順で走らせるか
- **応答と記述の規約** — ユーザーに向けて話す言語と、書いたものの量

## 手順

### 1. 探索する

現在のリポジトリを見て、その出発点の状態を理解する。何が存在するかを読み、決めつけない:

- `git remote -v` と `.git/config` — これは GitHub のリポジトリか? どのリポジトリか?
- リポジトリルートの `AGENTS.md` と `CLAUDE.md` — どちらが存在し、どちらが本文を持つか(`CLAUDE.md` が `@AGENTS.md` を取り込むだけか、symlink か、実体か)? すでにどちらかに `## Agent skills` セクションがあるか?
- リポジトリルートの `CONTEXT.md` と `CONTEXT-MAP.md`
- `docs/adr/` とあらゆる `src/*/docs/adr/` ディレクトリ
- `docs/agents/` — このスキルの過去の出力がすでに存在するか?
- `.scratch/` — ローカル markdown のイシュートラッカー規約がすでに使われている印
- `package.json` の scripts、`Makefile`、`Taskfile`、`turbo.json`、`.github/workflows/*.yml` などの CI 設定 — このリポジトリが実際に使っている検証コマンド。加えて、アプリを起動する手段(開発サーバー、CLI のエントリ、E2E のランナー)
- `triage` スキルはインストールされているか?(このスキルの隣にある `triage` スキルのフォルダ、または利用可能なスキルの中に `triage` があるか)これによって Section B をそもそも実行するかどうかが決まる。同じ見方で `where-to-write-what` も探す — Section E がそれを指すかどうかが決まる。
- モノレポの兆候 — `pnpm-workspace.yaml`、`package.json` の `workspaces` フィールド、または独自の `src/` を持つ中身のある `packages/*`。本当に大きな複数パッケージのリポジトリにのみ存在する。これらがなければ単一コンテキストであり、それがほぼすべてのリポジトリに当てはまる。

### 2. 発見を提示し、尋ねる

何があり、何がないかを要約する。それからセクションを順番に進める — 1セクションにつき1つの答え、それから次へ。

各セクションは推奨する答えから始め、ユーザーが一言で受け入れられるようにする。選択が本当に分かれる場合にだけ1行の説明を加える。探索によってすでに決まっているセクションは丸ごとスキップする(`triage` がインストールされていなければ Section B、モノレポでなければ Section C)。

**Section A — イシュートラッカー。**

> 説明: 「イシュートラッカー」とは、このリポジトリのイシューが存在する場所である。`to-tickets`、`triage`、`to-spec` のようなスキルはここから読み書きする — それらは、`gh issue create` を呼ぶべきか、`.scratch/` 配下にマークダウンファイルを書くべきか、あなたが説明する何か別のワークフローに従うべきかを知る必要がある。このリポジトリで実際に作業を追跡している場所を選ぶ。

デフォルトの姿勢: これらのスキルは GitHub 向けに設計されている。`git remote` が GitHub を指していれば、それを提案する。`git remote` が GitLab(`gitlab.com` かセルフホストのホスト)を指していれば、GitLab を提案する。そうでなければ(あるいはユーザーが望めば)、次を提示する:

- **GitHub** — イシューはこのリポジトリの GitHub Issues にある(`gh` CLI を使う)
- **GitLab** — イシューはこのリポジトリの GitLab Issues にある([`glab`](https://gitlab.com/gitlab-org/cli) CLI を使う)
- **ローカル markdown** — イシューはこのリポジトリの `.scratch/<feature>/` 配下のファイルとしてある(個人プロジェクトや remote のないリポジトリに向く)
- **その他**(Jira、Linear など) — ユーザーにそのワークフローを1段落で説明してもらう。このスキルはそれを自由な文章として記録する

選んだ内容を `docs/agents/issue-tracker.md` に記録する。テンプレートが持つ「PR を要望の受け口として扱う」フラグは **オフ** のままにし、こちらから提起しない — 既定値も切り替え方も、テンプレート自身が書いている。

**Section B — トリアージラベルの語彙。** `triage` スキルがインストールされていなければ(探索でそう分かった場合)、このセクションは丸ごとスキップする — インストールされていないスキルにラベルは不要である。

インストールされている場合は、正確に1つの質問をする:

> デフォルトのトリアージラベルをそのまま使いますか?(推奨: **はい**)

デフォルトは5つの正規のロールであり、各ラベル文字列はその名前と同じである: `needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`。**はい** ならそのまま書く。ユーザーが「いいえ」と答えた場合 — たいていはそのトラッカーがすでに別の名前(例えば `needs-triage` に対して `bug:triage`)を使っているため — だけ、上書き内容を集め、`triage` が重複を作らず既存のラベルを適用できるようにする。

**Section C — ドメインドキュメント。** デフォルトは **単一コンテキスト** — リポジトリルートに `CONTEXT.md` と `docs/adr/` を1組。これはほぼすべてのリポジトリに合うので、尋ねずに書く。

**複数コンテキスト** — コンテキストごとの `CONTEXT.md` ファイルを指すルートの `CONTEXT-MAP.md` — は、探索でモノレポの兆候が見つかったときにだけ提案する。そのうえで、どちらの配置を望むか確認する。

**Section D — 検証ゲート。** 変更が本当に動くと確かめる方法 — `/kjfsm-skills:verification-loop` が上から順に走らせるコマンド列。

探索で **実際に見つけたコマンドだけ** から提案する。慣習から推測して埋めない。そのうえで1問だけ尋ねる:

> この順序でよいですか?(推奨: 速いものから — 型チェック → lint → テスト → ビルド → 観測)

**観測** と **カスタムチェック** の2行は他と違う扱いになる。どちらも既定は空で、何を書くかは [verification.md](./verification.md) が持つ。

**Section E — 応答と記述の規約。** エージェントがユーザーに向けて話す言語と、書いたものの量。1問だけ尋ねる:

> ユーザーへの応答は日本語、書いたものの宛先は `where-to-write-what` に従う。これでよいですか?(推奨: **はい**)

「いいえ」なら応答言語だけ差し替える。宛先の規律は差し替えない。`where-to-write-what` が無い場合は、スキルを指す最後の 1 段落だけを落とす — 4本の柱とコメントの判定はこのブロックが単体で持っている。

このセクションだけは **ブロックの中に本文を置く** — 規約は毎セッション読まれなければ効かず、スキルへの参照ではコメントを書く場面で呼ばれない。8 行に収める。

置き場所は、本体がどちらかで分かれる(手順4):

- **本体が `AGENTS.md`** — Codex など `.claude/rules/` を読まないハーネスも同じファイルを読む。本文はブロックの中に置く。
- **本体が `CLAUDE.md` のまま**(手順4で移行を断られた) — 本文は `.claude/rules/writing-conventions.md` へ移し、ブロックにはそれを指す 1 行だけを残す。`paths:` の無い rule は `CLAUDE.md` と同じ優先度で毎セッション読まれるので、届き方は変わらず `CLAUDE.md` だけが短くなる。

**どちらか一方にだけ置く。** 両方に本文があると、片方だけ直った日にもう片方が嘘をつく。rule に `paths:` は **付けない** — マッチするファイルを **読んだ** ときにしかロードされず、新規ファイルやコミットメッセージを書く場面で消える。

出力スタイルで同じことを指定済みでも消さない — 出力スタイルは(fork を除く)サブエージェントに届かないが、このファイルは届く。

### 3. 確認して編集する

ユーザーに次の下書きを見せる:

- 本体(手順4)に追加する `## Agent skills` ブロックと、`AGENTS.md` / `CLAUDE.md` を作る・移すならその変更
- `.claude/rules/writing-conventions.md` の内容(本体が `CLAUDE.md` のままの場合のみ)
- `docs/agents/issue-tracker.md`、`docs/agents/domain.md`、`docs/agents/verification.md`、`docs/agents/triage-labels.md` の内容(最後のものは `triage` がインストールされている場合のみ)

書く前に、ユーザーに編集させる。

### 4. 書く

**本体は `AGENTS.md`、`CLAUDE.md` は先頭の `@AGENTS.md` 1 行で本体を取り込む。** Claude Code 専用の追記だけを import の下に置く。Claude Code は `CLAUDE.md` があると `AGENTS.md` を直接読まず、直接読めないセッション(v2.1.277 未満、フィーチャーフラグを取得しないセッション、インストール直後の初回)もあるので、import で1部を両方に届ける。symlink は Windows のクローンで1行のテキストになるので使わない。

- **どちらも無い** → `AGENTS.md` を作って編集し、`CLAUDE.md` を `@AGENTS.md` の1行で作る
- **`AGENTS.md` だけ** → `AGENTS.md` を編集し、`CLAUDE.md` を同じ1行で作る。Claude Code を使わないリポジトリなら作らない
- **`CLAUDE.md` が `@AGENTS.md` を取り込む、または `AGENTS.md` への symlink** → `AGENTS.md` を編集する
- **`CLAUDE.md` だけ、または `AGENTS.md` が `CLAUDE.md` への symlink** → 中身を `AGENTS.md` へ移して `CLAUDE.md` を import にする案を手順3で見せ、同意を得てから移す。断られたら `CLAUDE.md` を本体として編集する
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

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は `where-to-write-what` スキルが決める。
```

`### Triage labels` サブブロックの記載と `docs/agents/triage-labels.md` の作成は、`triage` がインストールされていて Section B が実行された場合にのみ行う。そうでない場合は、両方とも省略する。

`### Conventions` の本文は Section E の答えで決まる。`where-to-write-what` がインストールされていなければ最後の段落を落とす。

本体が `CLAUDE.md` のままの場合は、記述の規約をブロックに置かず `.claude/rules/writing-conventions.md` を作る。`# 書いたものの宛先` を見出しにし、その下へ上のテンプレートの記述の規約(応答言語の行を除く残り)をそのまま置く。ブロックに残るのは2行になる:

```markdown
### Conventions

[応答言語の指定を1行]。

書いたものの宛先は `.claude/rules/writing-conventions.md` にある。
```

それから、このスキルのフォルダにある元テンプレートを出発点として、ドキュメントファイルを書く:

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

どのエンジニアリング系スキルが今後これらのファイルを読むかをユーザーに伝え、`docs/agents/*.md` は直接編集してよいことに触れる。
