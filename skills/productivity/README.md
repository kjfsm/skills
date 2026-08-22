# Productivity

コードに限らない、一般的なワークフローツール。

## ユーザー呼び出し型

入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。

- **[help-skills](./help-skills/SKILL.md)** — kjfsm のスキル一覧を README で開く。名前を思い出したいだけのときに、一覧をコンテキストへ持ち込まずに済ませる。
- **[grill-me](./grill-me/SKILL.md)** — 決定木のすべての枝が解決するまで、計画やデザインについて容赦なくインタビューされる。
- **[handoff](./handoff/SKILL.md)** — 今の会話を引き継ぎ用のドキュメントへ圧縮し、別のエージェントが作業を継続できるようにする。
- **[teach](./teach/SKILL.md)** — 現在のディレクトリをステートフルな教育用ワークスペースとして使い、複数セッションにわたってユーザーに新しいスキルや概念を教える。

## モデル呼び出し型

モデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

- **[writing-great-skills](./writing-great-skills/SKILL.md)** — スキルを書く・直すための判断基準と、公式が定める仕様: 予測可能性・情報階層・段階的開示・先導語・失敗モードの語彙に、公式の数値上限と frontmatter の規則をまとめた `OFFICIAL.md` が付く。
- **[grilling](./grilling/SKILL.md)** — 決定木のすべての枝が解決するまで、計画・決定・アイデアについてユーザーに容赦なくインタビューする。
