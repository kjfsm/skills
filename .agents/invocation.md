# モデル呼び出し型 と ユーザー呼び出し型

このリポジトリの `SKILL.md` はすべてスキルである。それらを分ける唯一の軸が **呼び出し方式** — 誰がそれに到達できるか、である:

- **ユーザー呼び出し型** — **人間がその名前を入力したときだけ**到達できる。frontmatter で `disable-model-invocation: true`(Claude Code)、`agents/openai.yaml` で `policy.allow_implicit_invocation: false`(Codex)を設定する。`description` は **人間向け**: スラッシュコマンドを眺める人が読む1行の要約。トリガー文のリスト("Use when the user says…")は取り除く。
- **モデル呼び出し型** — **モデルからもユーザーからも**到達できる。デフォルトはこちら: `disable-model-invocation` と `agents/openai.yaml` の `policy` ブロックを省略する。`description` は **モデル向け** であり、自動呼び出しが働くよう豊富なトリガー表現("Use when the user wants…, mentions…, asks for…")を保つ。あるスキルをモデル呼び出し型のままにすべきかどうかの判定基準は: _モデルがこれを自律的に使いこなせるか?_ である(再利用性はスキルを切り出す理由ではあっても、この判定基準ではない)。

各ハーネスはそれぞれ独自のやり方でユーザー呼び出し型のスキルをモデルの到達範囲から除外するので、人間以外にはそれを発火できない — 他のどのスキルにもできない。ユーザー呼び出し型のスキルはモデル呼び出し型のスキルを呼び出せるが、別のユーザー呼び出し型のスキルには決して到達できない。

すべてのスキルは、その `SKILL.md` のそばに `agents/openai.yaml` も持つ。そこには Codex の UI メタデータ — スキルピッカー用の `interface.display_name` と `interface.short_description` — と、ユーザー呼び出し型のスキルについては `disable-model-invocation` と対になる `policy.allow_implicit_invocation: false` が入る。この2つは同期させておくこと: あるスキルは両方のハーネスでユーザー呼び出し型か、どちらでもないかのいずれかである。

バケットの `README.md` とトップレベルの `README.md` は、エントリを **ユーザー呼び出し型** と **モデル呼び出し型** にグループ分けする。

## それらの間の依存関係

依存関係は **`/skill` 形式の文中呼び出し**("Run the `/grilling` skill")として表現され、`../other-skill/FILE.md` のような深いクロスリファレンスでは表現しない。共有される参考資料は、それを所有するスキルの中に置く。他のスキルはフォルダをまたいでリンクするのではなく、そのスキルを呼び出すことでその内容にアクセスする。

## 受動的なドメイン作業と能動的なドメイン作業

語彙を調べるために `CONTEXT.md` を単に _読む_ ことは、1行の文中ポインタであって `domain-modeling` スキルではない。能動的な構築・研ぎ澄まし規律(用語に異議を唱える、エッジケースのシナリオを検討する、ADR を書く、`CONTEXT.md` をその場で更新する)だけが `domain-modeling` である。
