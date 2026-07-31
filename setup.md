これは [kjfsm/skills](https://github.com/kjfsm/skills) の公式セットアップ指示である。ここに載っているコマンドはすべて検証済みで、そのまま実行できる。

以下のステップは、**あなた(エージェント)がコマンドを直接実行して完了させること**。ユーザーにコマンドを実行するよう頼まないこと。

- kjfsm-skills プラグインをインストールする

---

## kjfsm-skills プラグインをインストールする

### Claude Code

次の2つのコマンドを実行する。これでマーケットプレイスの登録とプラグインの導入が両方済む。`npx skills` は使わない — 下のプラグインコマンドがすべてを賄う。

```
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-skills@kjfsm
```

インストールされたことを確認する:

```
claude plugin list
```

`kjfsm-skills` が一覧に出ていれば成功。そのうえで、Claude の中で `/reload-plugins` を実行するようユーザーに伝える。

### Claude Code 以外のハーネス

このセットアップ指示は Claude Code 専用である。Codex その他 Agent Skills 標準に準拠したハーネスへの導入手順は、README のインストール節にある: `https://github.com/kjfsm/skills#インストール`

---

## 入っているもの

昇格済みのスキル集合(`skills/engineering/` と `skills/productivity/`)。スキルは1つの軸で分かれる — 誰がそれを呼び出せるか:

- **ユーザー呼び出し型** — ユーザーが入力したとき(例: `/grill-me`)だけ到達できる。オーケストレーションを担う。エージェントからは起動できない。
- **モデル呼び出し型** — ユーザーも呼べるし、タスクに合致すればエージェントが自動的に手を伸ばす。再利用可能な規律を保持する。

どのスキルがどのフローに属するかの地図は [`ask-kjfsm`](https://github.com/kjfsm/skills/blob/main/skills/engineering/ask-kjfsm/SKILL.md) が持っている。ユーザーがどれを使えばいいか迷ったら `/ask-kjfsm` を案内する。

---

## インストール後にユーザーがやること

エンジニアリング系スキルを使う前に、**リポジトリごとに一度** `/setup-skills` を実行する必要がある。これはユーザー呼び出し型のスキルなので、エージェントからは起動できない — ユーザー自身に入力してもらうこと。`/setup-skills` は次を設定する:

- **イシュートラッカー** — イシューをどこに置くか(GitHub、Linear、ローカルの markdown)
- **トリアージラベル** — `/triage` が使うラベル文字列
- **ドメインドキュメント** — `CONTEXT.md` と ADR の配置
- **検証ゲート** — `/verification-loop` が走らせるコマンドとその順序

すべて済んだら、ユーザーに次を伝える:

```
┌─ kjfsm Skills setup complete ────────────────────────┐
│  ✓ plugin  kjfsm-skills@kjfsm                        │
│                                                      │
│  ⚡ /reload-plugins to activate                      │
│  👉 /setup-skills once per repository                │
└──────────────────────────────────────────────────────┘
```

---

## リソース

- リポジトリ: `https://github.com/kjfsm/skills`
- スキル一覧と設計の背景: `https://github.com/kjfsm/skills#readme`
- Claude Code プラグイン: `https://code.claude.com/docs/en/plugins`
- Agent Skills 標準: `https://github.com/anthropics/skills`

この指示は `https://raw.githubusercontent.com/kjfsm/skills/main/setup.md` で公開されているので、いつでも真正性を再検証できる。
