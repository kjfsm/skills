これは [kjfsm/skills](https://github.com/kjfsm/skills) の公式セットアップ指示である。ここに載っているコマンドはすべて検証済みで、そのまま実行できる。

**あなた(エージェント)がコマンドを直接実行して完了させること。** ユーザーにコマンドを実行するよう頼まないこと。例外は、ユーザー自身が入力しなければ動かない2つ(`/reload-plugins` と `/kjfsm-skills:setup-repo`)だけである。

1. プラグインをインストールする
2. 有効化とリポジトリごとの設定を案内する

---

## 1. プラグインをインストールする

配布は Claude Code のプラグインだけである。次の2つのコマンドで、マーケットプレイスの登録とプラグインの導入が両方済む。

```
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-skills@kjfsm
```

既定の導入先はユーザー全体である。ユーザーが「このリポジトリにだけ入れたい」「チームで共有したい」と言った場合に限り、両方のコマンドに `--scope project` を付ける。これは `.claude/settings.json` に書き込むので、コミットするかどうかはユーザーの判断である。勝手にコミットしないこと。

`kjfsm-skills` は本家の `mattpocock-skills@mattpocock` に依存しているので、本家も一緒に入る。インストールされたことを確認する:

```
claude plugin list
```

`kjfsm-skills` と `mattpocock-skills` が一覧に出ていれば成功。

以前 `npx skills` やシンボリックリンクで kjfsm/skills を入れていた形跡(`~/.claude/skills/` や `.claude/skills/` にある同名のスキル、`skills-lock.json`)があれば、消すかどうかユーザーに確認する。残すと同じスキルが2度並ぶ。

---

## 2. 有効化とリポジトリごとの設定を案内する

**有効化** — Claude の中で `/reload-plugins` を実行するようユーザーに伝える。

**出力スタイル(任意)** — プラグインには `kjfsm` という出力スタイルが同梱されている。ユーザーへの応答を日本語にし、コメントの判定基準をセッションに常駐させる。自動では有効にならないので、使うなら `/config` の **Output style** から `kjfsm` を選ぶよう伝える。

**リポジトリごとの設定** — エンジニアリング系スキルを使う前に、**リポジトリごとに一度** `/kjfsm-skills:setup-repo` を実行する必要がある。これはユーザー呼び出し型のスキルなので、エージェントからは起動できない — ユーザー自身に入力してもらうこと。`/kjfsm-skills:setup-repo` は次の4層を順に敷き、何度再実行してもよい:

- **規約・ドキュメント配置** — イシュートラッカー、トリアージラベル、ドメインドキュメントの配置、検証ゲート、応答と記述の規約
- **パス別ルール** — `.claude/rules/` にパスに応じて注入されるルール
- **CI** — 記録された検証ゲートを GitHub Actions で回す
- **弾く機構** — `permissions.deny`、検査スクリプト、フック

すべて済んだら、ユーザーに次を伝える:

```
┌─ kjfsm Skills setup complete ────────────────────────┐
│  ✓ plugin  kjfsm-skills@kjfsm                        │
│                                                      │
│  ⚡ /reload-plugins to activate                      │
│  👉 /kjfsm-skills:setup-repo once per repository     │
└──────────────────────────────────────────────────────┘
```

---

## 入っているもの

スキルは1つの軸で分かれる — 誰がそれを呼び出せるか:

- **ユーザー呼び出し型** — ユーザーが入力したとき(例: `/kjfsm-skills:implement-and-review`)だけ到達できる。オーケストレーションを担う。エージェントからは起動できない。
- **モデル呼び出し型** — ユーザーも呼べるし、タスクに合致すればエージェントが自動的に手を伸ばす。再利用可能な規律を保持する。

どのスキルがどのフローに属するかの地図は [`ask-kjfsm`](https://github.com/kjfsm/skills/blob/main/skills/kjfsm-skills/engineering/ask-kjfsm/SKILL.md) が持っている。ユーザーがどれを使えばいいか迷ったら `/kjfsm-skills:ask-kjfsm` を案内する。

---

## リソース

- リポジトリ: `https://github.com/kjfsm/skills`
- スキル一覧と設計の背景: `https://github.com/kjfsm/skills#readme`
- Claude Code プラグイン: `https://code.claude.com/docs/en/plugins`

この指示は `https://raw.githubusercontent.com/kjfsm/skills/main/setup.md` で公開されているので、いつでも真正性を再検証できる。
