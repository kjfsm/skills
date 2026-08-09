これは [kjfsm/skills](https://github.com/kjfsm/skills) の公式セットアップ指示である。ここに載っているコマンドはすべて検証済みで、そのまま実行できる。

ユーザーに確認するのは **導入方式の選択1つだけ** である。それ以外は、**あなた(エージェント)がコマンドを直接実行して完了させること**。ユーザーにコマンドを実行するよう頼まないこと。

1. どちらの方式で入れるかユーザーに聞く
2. 選ばれた方式でインストールする
3. 有効化とリポジトリごとの設定を案内する

---

## 1. どちらの方式で入れるかユーザーに聞く

次の比較をユーザーに提示し、**A** か **B** を選んでもらう:

|                | A: Claude Code プラグイン                                                                                                                                  | B: `npx skills` でコピー                                                                           |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| 実体の置き場所 | `~/.claude/plugins/` 配下のみ。作業中のリポジトリは汚れない                                                                                                | 実行した場所の `.claude/skills/`(`--global` なら `~/.claude/skills`)に実ファイルとしてコピーされる |
| 入るスキル     | 昇格済みの集合(`engineering/` + `productivity/`)だけ                                                                                                       | リポジトリ内の**全スキル**。`deprecated/` や未完成の下書きも含む(`--skill` で個別指定は可能)       |
| 更新           | `/plugin marketplace update kjfsm` で追随する。このプラグインは `version` を持たずコミット SHA をバージョンにしているので、**push されるたびに更新が届く** | コピーなので自動では追随しない。`npx skills update` を自分で叩く                                   |
| 取り消し       | `claude plugin uninstall`                                                                                                                                  | コピーされたディレクトリを消す                                                                     |
| 向いている人   | ふつうはこちら                                                                                                                                             | スキルの実体を手元に置いて改変したい / プロジェクトに同梱してチームで共有したい                    |

ユーザーが迷っている場合は **A** を薦める。

---

## 2. 選ばれた方式でインストールする

### A: Claude Code プラグインとして入れる

次の2つのコマンドを実行する。これでマーケットプレイスの登録とプラグインの導入が両方済む。

```
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-skills@kjfsm
```

インストールされたことを確認する:

```
claude plugin list
```

`kjfsm-skills` が一覧に出ていれば成功。

### B: `npx skills` でコピーとして入れる

インストール先のスコープを決める — ユーザーがいまいるプロジェクトに入れるならそのままで、ユーザーレベルに入れるなら `--global` を付ける。

```
npx -y skills add kjfsm/skills --agent claude-code
```

- **`--skill` を付けないと、`deprecated/` や下書きまで含めてリポジトリ内の全スキルが入る。** 先に `npx -y skills add kjfsm/skills --list` で一覧を見せ、絞り込むかどうかユーザーに確認すること。絞る場合は `--skill tdd,two-axis-review` のようにカンマ区切りで渡す。
- コピー元の情報は `skills-lock.json` に記録される。更新は `npx skills update`、lock からの復元は `npx skills experimental_install`。
- プロジェクトスコープで入れた場合、`.claude/skills/` と `skills-lock.json` をコミットするかどうかはユーザーの判断である。勝手にコミットしないこと。

---

## 3. 有効化とリポジトリごとの設定を案内する

**有効化** — A で入れた場合は、Claude の中で `/reload-plugins` を実行するようユーザーに伝える。B で入れた場合は、新しいセッションを開始すればスキルが読み込まれる。

**リポジトリごとの設定** — エンジニアリング系スキルを使う前に、**リポジトリごとに一度** `/setup-skills` を実行する必要がある。これはユーザー呼び出し型のスキルなので、エージェントからは起動できない — ユーザー自身に入力してもらうこと。`/setup-skills` は次を設定する:

- **イシュートラッカー** — イシューをどこに置くか(GitHub、Linear、ローカルの markdown)
- **トリアージラベル** — `/triage` が使うラベル文字列
- **ドメインドキュメント** — `CONTEXT.md` と ADR の配置
- **検証ゲート** — `/verification-loop` が走らせるコマンドとその順序

すべて済んだら、ユーザーに次を伝える(A で入れた場合):

```
┌─ kjfsm Skills setup complete ────────────────────────┐
│  ✓ plugin  kjfsm-skills@kjfsm                        │
│                                                      │
│  ⚡ /reload-plugins to activate                      │
│  👉 /setup-skills once per repository                │
└──────────────────────────────────────────────────────┘
```

B で入れた場合:

```
┌─ kjfsm Skills setup complete ────────────────────────┐
│  ✓ skills  <path>                                    │
│                                                      │
│  ⚡ restart the session to load them                 │
│  👉 /setup-skills once per repository                │
└──────────────────────────────────────────────────────┘
```

---

## 入っているもの

スキルは1つの軸で分かれる — 誰がそれを呼び出せるか:

- **ユーザー呼び出し型** — ユーザーが入力したとき(例: `/grill-me`)だけ到達できる。オーケストレーションを担う。エージェントからは起動できない。
- **モデル呼び出し型** — ユーザーも呼べるし、タスクに合致すればエージェントが自動的に手を伸ばす。再利用可能な規律を保持する。

どのスキルがどのフローに属するかの地図は [`ask-kjfsm`](https://github.com/kjfsm/skills/blob/main/skills/engineering/ask-kjfsm/SKILL.md) が持っている。ユーザーがどれを使えばいいか迷ったら `/ask-kjfsm` を案内する。

### Claude Code 以外のハーネス

方式 **B**(`npx skills`)は Codex その他のハーネスでも使える — `--agent` に対象を指定するか、`--agent '*'` で全部に入れる。方式 **A** は Claude Code 専用である。

---

## リソース

- リポジトリ: `https://github.com/kjfsm/skills`
- スキル一覧と設計の背景: `https://github.com/kjfsm/skills#readme`
- Claude Code プラグイン: `https://code.claude.com/docs/en/plugins`
- Agent Skills 標準: `https://github.com/anthropics/skills`

この指示は `https://raw.githubusercontent.com/kjfsm/skills/main/setup.md` で公開されているので、いつでも真正性を再検証できる。
