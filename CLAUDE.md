スキルは `skills/` 配下のバケットフォルダに整理されている:

- `engineering/` — 日々のコード作業
- `productivity/` — 日々の非コード系ワークフローツール
- `misc/` — 残してあるがほとんど使われない、昇格していない
- `personal/` — この端末固有のセットアップに紐づく、昇格していない
- `in-progress/` — まだ出荷準備が整っていない下書き
- `deprecated/` — もう使われていない

`engineering/` または `productivity/`(**昇格済み**バケット)にあるすべてのスキルは、トップレベルの `README.md` への参照と、`.claude-plugin/plugin.json` の `skills` 配列へのエントリを持たなければならない(Claude Code プラグインは昇格済みの集合だけを出荷する)。`misc/`、`personal/`、`in-progress/`、`deprecated/` のスキルはどちらにも現れてはならない。

このリポジトリ自体が単一プラグインの Claude Code マーケットプレイスでもある: `.claude-plugin/marketplace.json` は `kjfsm-skills` プラグインを1つだけ列挙している。Claude プラグインとして出荷し、(今のところ)Codex プラグインとして出荷しない理由は [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md) にある。

`plugin.json` に `version` を **置かない**。Claude Code は version が無いとき git のコミット SHA をバージョンとして扱うので、push するたびにインストール済みユーザーへ更新が届く。`version` を書くとその文字列が固定のキャッシュキーになり、手で上げない限り更新が一切届かなくなる。リリースの刻みを持つと決めるまで、このフィールドは空けておく。

`plugin.json` の `skills` 配列は、既定の `skills/` スキャンに **追加** されるのが原則で、`marketplace.json` の `source` がマーケットプレイスのルート(`"./"`)に解決される場合に限り **置き換え** になる。昇格していないバケットがプラグインに載らないのはこの例外に乗っているからなので、`source` を変えるときは `deprecated/` や `in-progress/` が出荷対象に混ざらないか確認する。

マニフェストを触ったあとは `scripts/check-invariants.sh` を実行する。`claude plugin validate .` も走らせてよいが、リポジトリルートを渡すと `marketplace.json` しか検証せず `plugin.json` の壊れたパスを見逃すこと、`--strict` は `version` 不在を error に格上げしてしまうこと(上記の通り、これは意図的な状態である)に注意する。

トップレベルの `README.md` にある各スキルのエントリは、スキル名をその `SKILL.md` へリンクしなければならない。

各バケットフォルダには、バケット内の全スキルを1行の説明つきで列挙し、スキル名をその `SKILL.md` へリンクした `README.md` がある。昇格済みバケットの `README.md` とトップレベルの `README.md` は、エントリを **ユーザー呼び出し型** と **モデル呼び出し型** にグループ分けする。昇格していないバケットの `README.md`(`misc/`、`personal/`)はフラットなリストを使う。

すべての `SKILL.md` は、ユーザー呼び出し型(`disable-model-invocation: true` に加えて `agents/openai.yaml` で `policy.allow_implicit_invocation: false`、人間だけが到達できる)か、モデル呼び出し型(モデルからもユーザーからも到達できる)のいずれかである。[.agents/invocation.md](./.agents/invocation.md) を参照。

[`ask-kjfsm`](./skills/engineering/ask-kjfsm/SKILL.md) は、ユーザーが到達できるすべてのスキルとその関係を対応付けるルーターである。ドキュメントページを再同期させるのと同じトリガーがこれにも当てはまる: ユーザーが到達できるスキルを追加・改名・削除したり、フローへの組み込み方を変えたりしたときは、必ず `ask-kjfsm` の `SKILL.md` を読み直して更新し、この地図が正確であり続けるようにする — 一度も言及されない新しいスキルや、いまだにルーティングされる古びたスキルがあれば、それは嘘をつくルーターである。

すべてのスキルをローカルのハーネススキルディレクトリ(`~/.claude/skills`、`~/.agents/skills`)へ(再)リンクするには、`scripts/link-skills.sh` を実行する。各エントリはこのリポジトリへのシンボリックリンクなので、`git pull` すればインストール済みのスキルは常に最新の状態を保つ。スキルを追加・削除・改名したあとは、このスクリプトを再実行すること。
