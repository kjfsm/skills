このリポジトリは Claude Code のマーケットプレイスで、スキルを `skills/<バケット>/<名前>/` に置く。下のルールは機械的なものほど `scripts/check-invariants.sh` が弾くので、触ったら走らせ、落ちた項目を直す。ルールを変える・例外を作る・検査の除外に当たる前に、その理由と却下した手を [.agents/design-notes.md](./.agents/design-notes.md) で読む。追加・改名・昇格・退役の手順は [.agents/adding-a-skill.md](./.agents/adding-a-skill.md)。

- **昇格済み**(`skills/kjfsm-skills/{engineering,productivity}/`)だけがトップの `README.md` と `plugin.json` の `skills` に載る。`kjfsm-emdash/`・`kjfsm-personal/` は `plugins/<バケット>/skills/` へのシンボリックリンクで別プラグインとして配り、`in-progress/` は配らない(検査 4. / 4b.、[ADR 0005](./.agents/adr/0005-ship-buckets-as-side-plugins.md))。
- `version` は `plugin.json`(`plugins/*/` を含む)にも `marketplace.json` にも置かない(検査 11.)。
- サブエージェントは `agents/` に置き、`plugin.json` に列挙しない。下書きは `.claude/agents/`。`agents/`(配るエージェント)と `.agents/`(設計文書)を混ぜない。組み込みの `Explore` を上書きするエージェントはここに置けない(プラグイン経由だと別名になる)。
- エージェントの依頼内容(何を報告するか・形・モデル階層)をスキル側に書き下さない。スキルが渡すのはその実行でしか決まらないもの(差分コマンド、ファイル一覧)だけ(検査 18.)。
- 出力スタイルは `output-styles/` に置き、`force-for-plugin` は付けず、`keep-coding-instructions: true` は必須。自家用の `.claude/output-styles/` と `.claude/settings.json` の2本も要る(検査 15.)。
- コメントの判定基準(下の4段落)は、この `AGENTS.md`・`output-styles/kjfsm.md`・`setup-skills` の `### Conventions` の3か所に本文で載せる。直すのはここだけで、残りは `scripts/render.py` が写す(検査 4. / 16.)。4か所目を常駐層(`SessionStart` フックなど)に足さない。コメント行が増えたときに鳴るフックに、4本の柱を復唱させず、判定もさせない(検査 17.、[ADR 0004](./.agents/adr/0004-enforce-comment-conventions-in-three-layers.md))。
- `SKILL.md` はユーザー呼び出し型かモデル呼び出し型のどちらか([.agents/invocation.md](./.agents/invocation.md))。書く・直す基準は [`writing-great-skills`](./skills/kjfsm-skills/productivity/writing-great-skills/SKILL.md)。
- `CLAUDE.md` も `CLAUDE.local.md` も置かない — 1つでもあると `AGENTS.md` が読まれなくなる(検査 19.、[ADR 0007](./.agents/adr/0007-agents-md-only-and-global-conventions.md))。
- 本家由来のスキルを直す前に [.agents/upstream-sync.md](./.agents/upstream-sync.md) を見る([ADR 0006](./.agents/adr/0006-depend-on-upstream-ship-translation-separately.md))。
- `.claude/skills/` には `in-progress/` のスキルへのシンボリックリンクだけを張る。張り直しは `scripts/sync-project-skills.sh`(検査 14.)。退役したスキルは削除し、[.agents/retired-skills.md](./.agents/retired-skills.md) に1行残す。

ユーザーとのやり取りは日本語で行う。コミットメッセージと PR 本文もこのリポジトリの慣習に従って日本語である(識別子とファイル名は英語)。

**コードには How、テストには What、コミットログには Why、コードコメントには Why not。**

コードを読めば分かることは書かない。書いたものを消してコードだけを読み、失われる情報が無ければ、その宛先はコードだった — 命名・関数抽出・型で言い直し、コメントは消す。**周囲に合わせるのは命名とイディオムであって、コメントの密度ではない。**

コメントが運ぶのはコードから読めない情報に限る: 採らなかった素直な書き方とそれがだめな理由、外部の制約(API 仕様・RFC・プラットフォームの上限)、不変条件と順序依存、issue や ADR への参照 1 行。それ以外は宛先が違う — 逐語的な説明(「〜を取得」「〜を更新」)はコード自体へ、変更の経緯はコミットメッセージへ、使わなくなったコードは削除して git 履歴へ。

JSDoc・コミットメッセージ・PR 本文・ADR・docs の宛先は `where-to-write-what` スキルが決める。書く前にそれを読む。
