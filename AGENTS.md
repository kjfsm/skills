スキルは `skills/` 配下のバケットフォルダに整理されている。**昇格済み**は `skills/kjfsm-skills/` の下の `engineering/` と `productivity/` の2つだけで、そこにあるスキルだけがトップレベルの `README.md` と `.claude-plugin/plugin.json` の `skills` 配列に載る — 残りのバケット(`kjfsm-emdash/`、`kjfsm-personal/`、`in-progress/`)はどちらにも現れてはならない(双方向とも検査 4. が弾く)。ただし `kjfsm-emdash/`・`kjfsm-personal/` は、同じマーケットプレイスの別プラグイン(`kjfsm-emdash` / `kjfsm-personal`)として配る — 実体は `skills/<バケット>/` のまま、`plugins/<バケット>/skills/` にシンボリックリンクを1本ずつ張る(検査 4b.)。理由と却下した手は [.agents/adr/0005-ship-buckets-as-side-plugins.md](./.agents/adr/0005-ship-buckets-as-side-plugins.md)。各バケットが何のためにあり、なぜ昇格していないかは、そのバケットの `README.md` の冒頭にある。

このリポジトリ自体が、`kjfsm-skills` を中心とする Claude Code マーケットプレイスでもある。そう決めた理由は [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md) にある。**`version` はどこにも置かない** — `plugin.json`(`plugins/*/` のものを含む)と `marketplace.json` の **両方** から省いてあるあいだだけ、push した内容がインストール済みユーザーへ更新として届く(検査 11. が両方を見る)。マニフェストの他の決まりと、触ったあとに走らせるものは [.agents/adding-a-skill.md](./.agents/adding-a-skill.md) が持つ。

サブエージェントは `agents/` に置く。プラグインはこのディレクトリを **自動で拾う** ので、`plugin.json` には列挙しない — `agents` を列挙すると既定の走査が止まり、列挙し忘れたエージェントが黙って消える。`agents/` に置いたものは全部 `kjfsm-skills` で配られる。まだ配りたくない下書きは `.claude/agents/` に置く(そちらはこのリポジトリでしか見えない)。このリポジトリで "agents" と名の付くものは3つあり、混ぜない — 配るサブエージェントの `agents/`、Codex 向けのメタデータ `skills/**/<スキル>/agents/openai.yaml`、このリポジトリ自身の設計文書 `.agents/`。

**エージェントの依頼内容を、呼ぶスキルの側に書き下さない。** 何を報告するか・語数の上限・モデル階層はエージェントが1部だけ持ち、スキルが渡すのはその実行でしか決まらないもの(差分コマンド、ファイル一覧)に限る。両方に書くと、貼り忘れた日に揃っていない方だけが残り、しかも「レビューは通った」ように見える(検査 18.)。

出力スタイルは `output-styles/` に置き、`plugin.json` の `outputStyles` で指す。**`force-for-plugin` は付けない** — 入れた人の `outputStyle` 設定を黙って上書きする。**`keep-coding-instructions: true` は必須**で、付け忘れるとハーネス組み込みのエンジニアリング指示(変更の切り方、**コメントの書き方**、検証のしかた)ごと外れる — 規律を足すつもりで既存の規律を消すことになる。このリポジトリ自身も `.claude/output-styles/` のシンボリックリンクと `.claude/settings.json` の `outputStyle` で同じスタイルを選んでおり、**出荷と自家用の2本が要る**(検査 15. が両方を見る)。

出力スタイルが入るのはメイン会話のシステムプロンプトだけで、**サブエージェントには届かない**(fork を除く)。届くのは `CLAUDE.md`(このファイルはそこから `@AGENTS.md` で取り込まれる)と `.claude/rules/` の側である(`Explore` / `Plan` と `omitClaudeMd` を付けたエージェントを除く)。だから下のコメントの判定基準は、`output-styles/kjfsm.md`・この `AGENTS.md`・`setup-skills` の `### Conventions` テンプレートの3か所に **本文として** 載る — スキルは呼ばれて初めて読まれるが、コメントを書く場面でモデルは「迷った」と自覚しないので呼ばない。参照 1 行に痩せた瞬間に効かなくなり、しかも症状が出ない。直すときは3か所を揃える(検査 16.)。常駐させるのは4本の柱とコメントの判定に留め、JSDoc・PR・ADR・docs のルーティングはスキル側に残す(規約は行数が増えるほど従われなくなる)。配布先のリポジトリへ届けるのは `setup-skills` の一度きりの書き込みで、こちらを直しても追随はしない。

相談の規律(`## 同意ではなく立場を取る`)を出力スタイルだけに置いてあるのは、その裏返しである — サブエージェントはユーザーに相談しないので、届かなくても穴が空かない。3か所へ同期しない。

その3か所は常に読まれる。それでも守られない。**4か所目を同じ「常に読まれる」層へ足さない** — `SessionStart` フックの標準出力も毎セッション常駐する層に着くので、同期先が1つ増えるだけである。代わりに三層で押さえる: `Edit`/`Write` でコメント行が**増えたときだけ**鳴るフック(`hooks/hooks.json` から出荷)、書かれたものを削る `/kjfsm-skills:prune-comments`、書かれなかった Why not を探す `/kjfsm-skills:two-axis-review` の Standards 軸。理由・分業の境界・却下した手・覆る条件は [.agents/adr/0004-enforce-comment-conventions-in-three-layers.md](./.agents/adr/0004-enforce-comment-conventions-in-three-layers.md) にある。フックについて押さえるのは2点だけである。**4本の柱を復唱させない**(復唱した瞬間に常駐3か所の同期先4つ目になる — 検査 17.)、そして**判定させない**(鳴る条件は機械的、適切かの判断はモデルに残す)。

すべての `SKILL.md` は、ユーザー呼び出し型(`disable-model-invocation: true` に加えて `agents/openai.yaml` で `policy.allow_implicit_invocation: false`、人間だけが到達できる)か、モデル呼び出し型(モデルからもユーザーからも到達できる)のいずれかである — [.agents/invocation.md](./.agents/invocation.md)。スキルを追加・改名・昇格・退役させる手順と、検査に出ない後始末(`ask-kjfsm`、`link-skills.sh`、他のスキルからの文中呼び出し)は [.agents/adding-a-skill.md](./.agents/adding-a-skill.md)。書く・直すときの判断基準は [`writing-great-skills`](./skills/kjfsm-skills/productivity/writing-great-skills/SKILL.md) と、同じフォルダの [`OFFICIAL.md`](./skills/kjfsm-skills/productivity/writing-great-skills/OFFICIAL.md)(公式の数値上限・frontmatter の出自・名指しされたアンチパターン)。メモリファイルに何を書くかの基準(**発見不可能 ∧ グローバルに有用**)と `/init` を出発点にしない理由は [.agents/adr/0003-never-start-from-init-output.md](./.agents/adr/0003-never-start-from-init-output.md) にあり、`tend-memory-files` と `setup-rules` はこの決定に従っているので片方だけ動かさない。本文はこの `AGENTS.md` に置き、`CLAUDE.md` は `@AGENTS.md` の1行に保つ — Claude Code は `CLAUDE.md` があると `AGENTS.md` を直接読まず、直接読めないセッション(v2.1.277 未満、フィーチャーフラグを取得しないセッション、インストール直後の初回)もあるので、import が両方を1部で満たす。配布先に同じ形を敷くのは `setup-skills` の手順4である。

このリポジトリは [mattpocock/skills](https://github.com/mattpocock/skills) の日本語訳から出発した独立フォークで、git 上の共通祖先が無い。本家由来のスキルは `kjfsm-skills` には置かず、依存先の本家 `mattpocock-skills` が配る。理由は [.agents/adr/0006-depend-on-upstream-ship-translation-separately.md](./.agents/adr/0006-depend-on-upstream-ship-translation-separately.md)。本家のどこまでを突き合わせ済みか、何を意図的に取り込んでいないか、差分をどう測るかは [.agents/upstream-sync.md](./.agents/upstream-sync.md) にある — 本家由来のスキルを直すときは、そこを見てから決める。

このリポジトリは自分のスキルを自分自身で使う。`.claude/skills/` に **どのプラグインも配らない** バケット(`in-progress/`)のスキルの実体へのシンボリックリンクがコミットされているので、クローンした誰にでも、`~` を持ち越せないクラウドセッションにも届く。**プラグインで配るもの(昇格済み、`kjfsm-emdash/`、`kjfsm-personal/`)はここに張らない** — 配るのはプラグインの役目で、両方から見えると Claude Code はセッション開始時に同じスキルを2度並べ、name と description のぶんだけ毎セッション二重に払う。張り直すのは `scripts/sync-project-skills.sh`、ずれの検出は検査 14. が行う。`in-progress/` を張るのは意図的である: 下書きは実際に呼んでみて初めて直せる。退役したスキルは移さず削除し、理由と代わりを [.agents/retired-skills.md](./.agents/retired-skills.md) に1行残す。

ユーザーとのやり取りは日本語で行う。コミットメッセージと PR 本文もこのリポジトリの慣習に従って日本語である(識別子とファイル名は英語)。

**コードには How、テストには What、コミットログには Why、コードコメントには Why not。**

コードを読めば分かることは書かない。書いたものを消してコードだけを読み、失われる情報が無ければ、その宛先はコードだった — 命名・関数抽出・型で言い直し、コメントは消す。**周囲に合わせるのは命名とイディオムであって、コメントの密度ではない。**

コメントが運ぶのはコードから読めない情報に限る: 採らなかった素直な書き方とそれがだめな理由、外部の制約(API 仕様・RFC・プラットフォームの上限)、不変条件と順序依存、issue や ADR への参照 1 行。それ以外は宛先が違う — 逐語的な説明(「〜を取得」「〜を更新」)はコード自体へ、変更の経緯はコミットメッセージへ、使わなくなったコードは削除して git 履歴へ。

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は `where-to-write-what` スキルが決める。書く前にそれを読む。
