# Matt Pocock Skills(日本語訳)

[mattpocock/skills](https://github.com/mattpocock/skills) のうち、**ほぼ訳のまま**のスキルの日本語訳。別プラグイン `matt-skills-jp` で配る:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install matt-skills-jp@kjfsm
```

**`kjfsm-skills` はこれに依存しない。** 依存先は本家の英語版 `mattpocock-skills@mattpocock` で、`kjfsm-skills` を入れると一緒に入る。このバケットは本家と同じ名前のスキルを持つので、本家と併用すると同じ名前が2度並ぶ — 日本語で読みたい人が本家の代わりに入れるものである。理由は [ADR 0006](../../.agents/adr/0006-depend-on-upstream-ship-translation-separately.md)。

本家から大きく離れて自作の流れの中心になったもの(`implement-and-review`・`ask-kjfsm`・`setup-skills`・`writing-great-skills`)は、ここではなく `kjfsm-skills` に残してある。どこまで本家と突き合わせたかは [`.agents/upstream-sync.md`](../../.agents/upstream-sync.md)。

訳は自作スキルへの参照を持たない — 片方だけ入れても壊れないように。docs/agents/ の設定は本家の `/setup-matt-pocock-skills` を指したままで、その訳はこのバケットに無い。

## ユーザー呼び出し型

入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。

- **[grill-with-docs](./grill-with-docs/SKILL.md)** — プロジェクトのドメインモデルも構築するグリリングセッション。用語を研ぎ澄まし、`CONTEXT.md` と ADR をその場で更新する。
- **[triage](./triage/SKILL.md)** — トリアージロールのステートマシンに沿ってイシューを進める。
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — コードベースをスキャンして深化の機会を見つけ、視覚的な HTML レポートとして提示し、選んだものについてグリリングする。
- **[to-spec](./to-spec/SKILL.md)** — 今の会話をスペックに変換し、イシュートラッカーへ公開する。
- **[to-tickets](./to-tickets/SKILL.md)** — どんな計画・スペック・会話も、それぞれがブロッキングエッジを宣言するトレーサーバレット方式のチケットの集合へ分割する — ローカルファイルへのテキストとして、あるいは実際のトラッカー上のネイティブなブロッキングリンクとして。
- **[wayfinder](./wayfinder/SKILL.md)** — 1つのエージェントセッションには収まらない巨大な作業のかたまりを、イシュートラッカー上の意思決定チケットの共有マップとして計画し、目的地までの道が明らかになるまで1つずつ解決していく。
- **[grill-me](./grill-me/SKILL.md)** — 決定木のすべての枝が解決するまで、計画やデザインについて容赦なくインタビューされる。
- **[handoff](./handoff/SKILL.md)** — 今の会話を引き継ぎ用のドキュメントへ圧縮し、別のエージェントが作業を継続できるようにする。
- **[teach](./teach/SKILL.md)** — 現在のディレクトリをステートフルな教育用ワークスペースとして使い、複数セッションにわたってユーザーに新しいスキルや概念を教える。

## モデル呼び出し型

モデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

- **[prototype](./prototype/SKILL.md)** — デザイン上の問いに答えるための使い捨てプロトタイプを作る: 状態/ロジック向けの共有できる単一 HTML ファイル、あるいは切り替え可能な何通りかの UI バリエーション。
- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — 手強いバグやパフォーマンスのリグレッションのための規律ある診断ループ: 再現 → 最小化 → 仮説立て → 計測 → 修正 → リグレッションテスト。
- **[research](./research/SKILL.md)** — 信頼度の高い一次情報源に対してある問いを調査し、その発見を引用付きのマークダウンファイルとしてリポジトリに残す。バックグラウンドエージェントとして実行される。
- **[tdd](./tdd/SKILL.md)** — レッド・グリーン・リファクタリングのループによるテスト駆動開発。機能を作るのもバグを直すのも、一度に1つの垂直スライスずつ進める。
- **[domain-modeling](./domain-modeling/SKILL.md)** — プロジェクトのドメインモデルを能動的に構築し研ぎ澄ます — 用語に異議を唱え、シナリオでストレステストし、`CONTEXT.md` と ADR をその場で更新する。
- **[codebase-design](./codebase-design/SKILL.md)** — 深いモジュールを設計するための共有された規律と語彙: 小さなインターフェース、きれいなシーム、インターフェースを通してテスト可能。
- **[resolving-merge-conflicts](./resolving-merge-conflicts/SKILL.md)** — 進行中の git マージやリベースのコンフリクトを、ハンクごとに、双方の一次情報源にたどれる意図に基づいて解決し、そのうえで操作を完了させる — `--abort` は決して使わない。
- **[grilling](./grilling/SKILL.md)** — 決定木のすべての枝が解決するまで、計画・決定・アイデアについてユーザーに容赦なくインタビューする。
