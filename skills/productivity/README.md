# Productivity

コードに限らない、一般的なワークフローツール。

## ユーザー呼び出し型

入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。

- **[grill-me](./grill-me/SKILL.md)** — 決定木のすべての枝が解決するまで、計画やデザインについて容赦なくインタビューされる。
- **[handoff](./handoff/SKILL.md)** — 今の会話を引き継ぎ用のドキュメントへ圧縮し、別のエージェントが作業を継続できるようにする。
- **[teach](./teach/SKILL.md)** — 現在のディレクトリをステートフルな教育用ワークスペースとして使い、複数セッションにわたってユーザーに新しいスキルや概念を教える。
- **[writing-great-skills](./writing-great-skills/SKILL.md)** — スキルをうまく書き、編集するためのリファレンス: スキルを予測可能にする語彙と原則。

## モデル呼び出し型

モデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

- **[grilling](./grilling/SKILL.md)** — 決定木のすべての枝が解決するまで、計画・決定・アイデアについてユーザーに容赦なくインタビューする。
