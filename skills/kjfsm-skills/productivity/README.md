# Productivity

コードに限らない、一般的なワークフローツール。

**ユーザー呼び出し型** は入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。**モデル呼び出し型** はモデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

<!-- catalog:begin -->

**モデル呼び出し型**

- **[sharpen-request](./sharpen-request/SKILL.md)** — 曖昧な改善・整理の依頼を、1項目ずつ判定できる問いと止まる地点を持った指示に研ぐ。「〜を整理したい」「〜を改善したい」のように、既にあるものを良くしたい依頼が何をもって良いかを言わずに来たとき、同じ指示を複数のリポジトリやセッションに配りたいときに使う。
- **[writing-great-skills](./writing-great-skills/SKILL.md)** — スキルを書く・直すための判断基準と、公式が定める仕様。SKILL.md を新規に書くとき、既存のスキルを編集・分割・刈り込むとき、description のトリガーを調整するとき、name や description の文字数上限・frontmatter の書き方を確かめるとき、スキルが発火しない・実行ごとに動きがばらつく原因を診断するときに使う。

<!-- catalog:end -->
