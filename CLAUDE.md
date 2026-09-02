スキルは `skills/` 配下のバケットフォルダに整理されている。**昇格済み**は `engineering/` と `productivity/` の2つだけで、そこにあるスキルだけがトップレベルの `README.md` と `.claude-plugin/plugin.json` の `skills` 配列に載る — 残りのバケット(`misc/`、`emdash/`、`personal/`、`in-progress/`、`deprecated/`)はどちらにも現れてはならない(双方向とも検査 4. が弾く)。各バケットが何のためにあり、なぜ昇格していないかは、そのバケットの `README.md` の冒頭にある。

このリポジトリ自体が単一プラグイン `kjfsm-skills` の Claude Code マーケットプレイスでもある。そう決めた理由は [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md) にある。**`version` はどこにも置かない** — `plugin.json` と `marketplace.json` の **両方** から省いてあるあいだだけ、push した内容がインストール済みユーザーへ更新として届く(検査 11. が両方を見る)。マニフェストの他の決まりと、触ったあとに走らせるものは [.agents/adding-a-skill.md](./.agents/adding-a-skill.md) が持つ。

出力スタイルは `output-styles/` に置き、`plugin.json` の `outputStyles` で指す。**`force-for-plugin` は付けない** — 入れた人の `outputStyle` 設定を黙って上書きする。**`keep-coding-instructions: true` は必須**で、付け忘れるとハーネス組み込みのエンジニアリング指示(変更の切り方、**コメントの書き方**、検証のしかた)ごと外れる — 規律を足すつもりで既存の規律を消すことになる。このリポジトリ自身も `.claude/output-styles/` のシンボリックリンクと `.claude/settings.json` の `outputStyle` で同じスタイルを選んでおり、**出荷と自家用の2本が要る**(検査 15. が両方を見る)。

出力スタイルが入るのはメイン会話のシステムプロンプトだけで、**サブエージェントには届かない**。届くのは `CLAUDE.md` と `.claude/rules/` の側である(組み込みの探索用エージェントを除く)。だから下のコメントの判定基準は、`output-styles/kjfsm.md`・この `CLAUDE.md`・`setup-skills` の `### Conventions` テンプレートの3か所に **本文として** 載る — スキルは呼ばれて初めて読まれるが、コメントを書く場面でモデルは「迷った」と自覚しないので呼ばない。参照 1 行に痩せた瞬間に効かなくなり、しかも症状が出ない。直すときは3か所を揃える(検査 16.)。常駐させるのは4本の柱とコメントの判定に留め、JSDoc・PR・ADR・docs のルーティングはスキル側に残す(規約は行数が増えるほど従われなくなる)。配布先のリポジトリへ届けるのは `setup-skills` の一度きりの書き込みで、こちらを直しても追随はしない。

相談の規律(`## 同意ではなく立場を取る`)を出力スタイルだけに置いてあるのは、その裏返しである — サブエージェントはユーザーに相談しないので、届かなくても穴が空かない。3か所へ同期しない。

その3か所は常に読まれる。それでも守られない。**4か所目を同じ「常に読まれる」層へ足さない** — `SessionStart` フックの標準出力が着く先も同じシステムプロンプトなので、同期先が1つ増えるだけである。代わりに三層で押さえる: `Edit`/`Write` でコメント行が**増えたときだけ**鳴るフック(`hooks/hooks.json` から出荷)、書かれたものを削る `/prune-comments`、書かれなかった Why not を探す `/two-axis-review` の Standards 軸。理由・分業の境界・却下した手・覆る条件は [.agents/adr/0004-enforce-comment-conventions-in-three-layers.md](./.agents/adr/0004-enforce-comment-conventions-in-three-layers.md) にある。フックについて押さえるのは2点だけである。**4本の柱を復唱させない**(復唱した瞬間に常駐3か所の同期先4つ目になる — 検査 17.)、そして**判定させない**(鳴る条件は機械的、適切かの判断はモデルに残す)。

すべての `SKILL.md` は、ユーザー呼び出し型(`disable-model-invocation: true` に加えて `agents/openai.yaml` で `policy.allow_implicit_invocation: false`、人間だけが到達できる)か、モデル呼び出し型(モデルからもユーザーからも到達できる)のいずれかである — [.agents/invocation.md](./.agents/invocation.md)。スキルを追加・改名・昇格・退役させる手順と、検査に出ない後始末(`ask-kjfsm`、`link-skills.sh`、他のスキルからの文中呼び出し)は [.agents/adding-a-skill.md](./.agents/adding-a-skill.md)。書く・直すときの判断基準は [`writing-great-skills`](./skills/productivity/writing-great-skills/SKILL.md) と、同じフォルダの [`OFFICIAL.md`](./skills/productivity/writing-great-skills/OFFICIAL.md)(公式の数値上限・frontmatter の出自・名指しされたアンチパターン)。メモリファイルに何を書くかの基準(**発見不可能 ∧ グローバルに有用**)と `/init` を出発点にしない理由は [.agents/adr/0003-never-start-from-init-output.md](./.agents/adr/0003-never-start-from-init-output.md) にあり、`tend-memory-files` と `setup-rules` はこの決定に従っているので片方だけ動かさない。

このリポジトリは [mattpocock/skills](https://github.com/mattpocock/skills) の日本語訳から出発した独立フォークで、git 上の共通祖先が無い。本家のどこまでを突き合わせ済みか、何を意図的に取り込んでいないか、差分をどう測るかは [.agents/upstream-sync.md](./.agents/upstream-sync.md) にある — 本家由来のスキルを直すときは、そこを見てから決める。

このリポジトリは自分のスキルを自分自身で使う。`.claude/skills/` に **昇格していない** バケット(`deprecated/` を除く)のスキルの実体へのシンボリックリンクがコミットされているので、クローンした誰にでも、`~` を持ち越せないクラウドセッションにも届く。**昇格済みはここに張らない** — 配るのはプラグインの役目で、両方から見えると Claude Code はセッション開始時に同じスキルを2度並べ、name と description のぶんだけ毎セッション二重に払う。張り直すのは `scripts/sync-project-skills.sh`、ずれの検出は検査 14. が行う。`in-progress/` を張るのは意図的である: 下書きは実際に呼んでみて初めて直せる。

ユーザーとのやり取りは日本語で行う。コミットメッセージと PR 本文もこのリポジトリの慣習に従って日本語である(識別子とファイル名は英語)。

**コードには How、テストには What、コミットログには Why、コードコメントには Why not。**

コードを読めば分かることは書かない。書いたものを消してコードだけを読み、失われる情報が無ければ、その宛先はコードだった — 命名・関数抽出・型で言い直し、コメントは消す。**周囲に合わせるのは命名とイディオムであって、コメントの密度ではない。**

コメントが運ぶのはコードから読めない情報に限る: 採らなかった素直な書き方とそれがだめな理由、外部の制約(API 仕様・RFC・プラットフォームの上限)、不変条件と順序依存、issue や ADR への参照 1 行。それ以外は宛先が違う — 逐語的な説明(「〜を取得」「〜を更新」)はコード自体へ、変更の経緯はコミットメッセージへ、使わなくなったコードは削除して git 履歴へ、ディレクトリ構成やアーキテクチャの概観は書かない。

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は [`where-to-write-what`](./skills/engineering/where-to-write-what/SKILL.md) が決める。
