スキルは `skills/` 配下のバケットフォルダに整理されている。**昇格済み**は `engineering/` と `productivity/` の2つだけで、ここにあるスキルはトップレベルの `README.md` への参照と `.claude-plugin/plugin.json` の `skills` 配列へのエントリを持ち、残りのバケット(`misc/`、`emdash/`、`personal/`、`in-progress/`、`deprecated/`)のスキルはどちらにも現れてはならない — Claude Code プラグインは昇格済みの集合だけを出荷する(双方向とも検査 4. が弾く)。各バケットが何のためにあり、なぜ昇格していないかは、そのバケットの `README.md` の冒頭にある。

昇格していないバケットのスキルは、プラグインではなく利用側リポジトリでの `npx skills` による実体配置で配る(`skills-lock.json` に載り、`npx skills update` で追随できる)。`emdash/` がこの経路の主な利用者である。

このリポジトリ自体が単一プラグインの Claude Code マーケットプレイスでもある: `.claude-plugin/marketplace.json` は `kjfsm-skills` プラグインを1つだけ列挙している。Claude プラグインとして出荷し、(今のところ)Codex プラグインとして出荷しない理由は [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md) にある。

`version` を **どこにも置かない** — `plugin.json` と `marketplace.json` のプラグインエントリの **両方** から省く。公式はコミット SHA をバージョンとして扱う条件をこの「両方から省く」で定めており、片方にでも書くとその文字列が固定のキャッシュキーになって、手で上げない限り更新が一切届かなくなる。省いてあるかぎり、push するたびにインストール済みユーザーへ更新が届く。リリースの刻みを持つと決めるまで、このフィールドは空けておく(検査 11. が両方を見る)。

`plugin.json` の `skills` 配列は、既定の `skills/` スキャンに **追加** されるのが原則で、`marketplace.json` の `source` がマーケットプレイスのルート(`"./"`)に解決される場合に限り **置き換え** になる。昇格していないバケットがプラグインに載らないのはこの例外に乗っているからなので、`source` を変えるときは `deprecated/` や `in-progress/` が出荷対象に混ざらないか確認する。

出力スタイルは `output-styles/` に置き、`plugin.json` の `outputStyles` で指す。`force-for-plugin` は **付けない** — 付けると入れた人の `outputStyle` 設定を黙って上書きするので、選ぶかどうかは利用者に残す。`keep-coding-instructions: true` は必須である: 出力スタイルは既定でハーネス組み込みのエンジニアリング指示(変更の切り方、**コメントの書き方**、検証のしかた)を外すため、付け忘れると規律を足すつもりで既存の規律を消すことになる。このリポジトリ自身は `.claude/output-styles/` のシンボリックリンクと `.claude/settings.json` の `outputStyle` で同じスタイルを選んでいる(検査 15. が両方を見る)。

出力スタイルが入るのはメイン会話のシステムプロンプトだけで、**サブエージェントには届かない**。届くのは `CLAUDE.md` と `.claude/rules/` の側である(組み込みの探索用エージェントを除く)。だから同じ応答・記述の規約が `setup-skills` の書く `## Agent skills` ブロックにも載る — 意図的な唯一の重複であり、どちらか片方だけでは穴が空く。

相談の規律(`## 同意ではなく立場を取る`)を出力スタイルだけに置いてあるのは、その裏返しである — サブエージェントはユーザーに相談しないので、届かなくても穴が空かない。3か所へ同期しない。

その重複が運ぶのは `where-to-write-what` への参照 1 行ではなく、**コメントの判定基準そのもの** である。スキルは呼ばれて初めて読まれるが、コメントを書く場面でモデルは「迷った」と自覚しないので呼ばない — 毎回効いてほしい規律は、参照ではなく本文として常駐していなければならない。常駐させるのはコメントの判定だけに留め、JSDoc・コミット・PR・ADR・docs のルーティングはスキル側に残す(規約は行数が増えるほど従われなくなる)。本文が載るのは `output-styles/kjfsm.md`、この `CLAUDE.md`、`setup-skills` の `### Conventions` テンプレートの3か所で、直すときは揃える(検査 16. が3か所を見る)。

このリポジトリは [mattpocock/skills](https://github.com/mattpocock/skills) の日本語訳から出発した独立フォークで、git 上の共通祖先が無い。本家のどこまでを突き合わせ済みか、何を意図的に取り込んでいないか、差分をどう測るか(`scripts/upstream-diff.py`)は [.agents/upstream-sync.md](./.agents/upstream-sync.md) にある — 本家由来のスキルを直すときは、そこを見てから決める。

スキルを追加・改名・昇格・退役させる手順は [.agents/adding-a-skill.md](./.agents/adding-a-skill.md) にある — バケットと呼び出し方式の選び方、そして検査に出ない後始末(`ask-kjfsm`、`link-skills.sh`、他のスキルからの文中呼び出し)。

マニフェストを触ったあとは `scripts/check-invariants.sh` を実行する。`claude plugin validate .` も走らせてよいが、リポジトリルートを渡すと `marketplace.json` しか検証せず `plugin.json` の壊れたパスを見逃すこと、`--strict` は `version` 不在を error に格上げしてしまうこと(上記の通り、これは意図的な状態である)に注意する。

各スキルは、自分のバケットの `README.md` と(昇格済みなら)トップレベルの `README.md` に、スキル名から `SKILL.md` へのリンクと1行の説明つきで載る。**掲載されているかは検査 4./5. が弾くが、以下は弾かない** — 昇格済みバケットとトップレベルの `README.md` はエントリを **ユーザー呼び出し型** と **モデル呼び出し型** にグループ分けし、昇格していないバケット(`misc/`、`personal/`)はフラットなリストを使う。

すべての `SKILL.md` は、ユーザー呼び出し型(`disable-model-invocation: true` に加えて `agents/openai.yaml` で `policy.allow_implicit_invocation: false`、人間だけが到達できる)か、モデル呼び出し型(モデルからもユーザーからも到達できる)のいずれかである。[.agents/invocation.md](./.agents/invocation.md) を参照。

メモリファイルに何を書くかの基準(**発見不可能 ∧ グローバルに有用**)と、`/init` を出発点にしない理由は [.agents/adr/0003-never-start-from-init-output.md](./.agents/adr/0003-never-start-from-init-output.md) にある — `tend-memory-files` と `setup-rules` はこの決定に従っているので、片方だけ動かさない。

スキルを書く・直すときの判断基準は [`writing-great-skills`](./skills/productivity/writing-great-skills/SKILL.md) にある。公式が定める数値上限、frontmatter のどのフィールドが Agent Skills 標準でどれが Claude Code 独自か、公式が名指ししているアンチパターンは、同じフォルダの [`OFFICIAL.md`](./skills/productivity/writing-great-skills/OFFICIAL.md) にまとまっている — スキルを新規に書く前と、frontmatter や参照ファイルの構成を確定させるときに引く。

[`ask-kjfsm`](./skills/engineering/ask-kjfsm/SKILL.md) は、ユーザーが到達できるすべてのスキルとその関係を対応付けるルーターである。ドキュメントページを再同期させるのと同じトリガーがこれにも当てはまる: ユーザーが到達できるスキルを追加・改名・削除したり、フローへの組み込み方を変えたりしたときは、必ず `ask-kjfsm` の `SKILL.md` を読み直して更新し、この地図が正確であり続けるようにする — 一度も言及されない新しいスキルや、いまだにルーティングされる古びたスキルがあれば、それは嘘をつくルーターである。

すべてのスキルをローカルのハーネススキルディレクトリ(`~/.claude/skills`、`~/.agents/skills`)へ(再)リンクするには、`scripts/link-skills.sh` を実行する。各エントリはこのリポジトリへのシンボリックリンクなので、`git pull` すればインストール済みのスキルは常に最新の状態を保つ。スキルを追加・削除・改名したあとは、このスクリプトを再実行すること。

このリポジトリは自分のスキルを自分自身で使う。`.claude/skills/` に `deprecated/` を除く全スキルの実体へのシンボリックリンクが **コミットされている** ので、ここで作業するエージェントは `/ask-kjfsm` や `/writing-great-skills` をそのまま呼べる — Claude Code がプロジェクトスキルとして見るのは `.claude/skills/<名前>/SKILL.md` だけで、`skills/<バケット>/` は見に行かないためである。`link-skills.sh` が端末側(`~`)を埋めるのに対しこちらはリポジトリ側なので、クローンした誰にでも、`~` を持ち越せないクラウドセッションにも届く。張り直すのは `scripts/sync-project-skills.sh`、ずれの検出は検査 14. が行う。`in-progress/` を含めてあるのは意図的である: 下書きは実際に呼んでみて初めて直せる。

ユーザーとのやり取りは日本語で行う。コミットメッセージと PR 本文もこのリポジトリの慣習に従って日本語である(識別子とファイル名は英語)。

コードを読めば分かることは書かない。書いたものを消してコードだけを読み、失われる情報が無ければ、その宛先はコードだった — 命名・関数抽出・型で言い直し、コメントは消す。**周囲に合わせるのは命名とイディオムであって、コメントの密度ではない。**

コメントが運ぶのはコードから読めない情報に限る: 採らなかった素直な書き方とそれがだめな理由、外部の制約(API 仕様・RFC・プラットフォームの上限)、不変条件と順序依存、issue や ADR への参照 1 行。それ以外は宛先が違う — 逐語的な説明(「〜を取得」「〜を更新」)はコード自体へ、変更の経緯はコミットメッセージへ、使わなくなったコードは削除して git 履歴へ、ディレクトリ構成やアーキテクチャの概観は書かない。

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は [`where-to-write-what`](./skills/engineering/where-to-write-what/SKILL.md) が決める。
