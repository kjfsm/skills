# Engineering

日々のコード作業のために使うスキル。

## ユーザー呼び出し型

入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。

- **[ask-kjfsm](./ask-kjfsm/SKILL.md)** — どのスキルやフローが自分の状況に合うかを尋ねる。このリポジトリのスキルを案内するルーター。
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — プロジェクトのドメインモデルも構築するグリリングセッション。用語を研ぎ澄まし、`CONTEXT.md` と ADR をその場で更新する。
- **[triage](./triage/SKILL.md)** — トリアージロールのステートマシンに沿ってイシューを進める。
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — コードベースをスキャンして深化の機会を見つけ、視覚的な HTML レポートとして提示し、選んだものについてグリリングする。
- **[setup-repo](./setup-repo/SKILL.md)** — setup 系4工程(規約とドキュメント配置・パス別ルール・CI・フック)の入口。順序と依存はこのスキルが持つ。再実行すると現況を読み、足りない工程と**ずれた箇所だけ**を当てる。
- **[tend-memory-files](./tend-memory-files/SKILL.md)** — `CLAUDE.md` と `.claude/rules/` を新規に書く、または監査してトリムする。行数の目安に収め、具体的で矛盾のない指示だけを残す。
- **[to-spec](./to-spec/SKILL.md)** — 今の会話をスペックに変換し、イシュートラッカーへ公開する。
- **[to-tickets](./to-tickets/SKILL.md)** — どんな計画・スペック・会話も、それぞれがブロッキングエッジを宣言するトレーサーバレット方式のチケットの集合へ分割する — ローカルファイルへのテキストとして、あるいは実際のトラッカー上のネイティブなブロッキングリンクとして。
- **[implement](./implement/SKILL.md)** — スペックやチケットの集合が記述する作業をビルドする。事前に合意したシームで `/tdd` を駆動し、`/verification-loop` でクリーンランを取り、コミット前に `/two-axis-review` で締めくくる。
- **[wayfinder](./wayfinder/SKILL.md)** — 1つのエージェントセッションには収まらない巨大な作業のかたまりを、イシュートラッカー上の意思決定チケットの共有マップとして計画し、目的地までの道が明らかになるまで1つずつ解決していく。
- **[squash-d1-migrations](./squash-d1-migrations/SKILL.md)** — 積み上がった D1 のマイグレーションを1本に畳む。合格条件はファイルが減ったことではなく、空の DB に適用した結果が旧チェーンと一致すること。`d1_migrations` は名前を記録しているので、各環境と突き合わせるまでが作業である。

## モデル呼び出し型

モデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

- **[prototype](./prototype/SKILL.md)** — デザイン上の問いに答えるための使い捨てプロトタイプを作る: 状態/ロジック向けの共有できる単一 HTML ファイル、あるいは切り替え可能な何通りかの UI バリエーション。

- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — 手強いバグやパフォーマンスのリグレッションのための規律ある診断ループ: 再現 → 最小化 → 仮説立て → 計測 → 修正 → リグレッションテスト。
- **[research](./research/SKILL.md)** — 信頼度の高い一次情報源に対してある問いを調査し、その発見を引用付きのマークダウンファイルとしてリポジトリに残す。バックグラウンドエージェントとして実行される。
- **[tdd](./tdd/SKILL.md)** — レッド・グリーン・リファクタリングのループによるテスト駆動開発。機能を作るのもバグを直すのも、一度に1つの垂直スライスずつ進める。
- **[create-tests](./create-tests/SKILL.md)** — Cloudflare Workers のプロジェクトで、テストが 1 本も無いところから作り始める。何が壊れると困るかから始め、node と workerd の 2 プロジェクトに分けて、依存の内側から積む。
- **[rebuild-tests](./rebuild-tests/SKILL.md)** — Cloudflare Workers のテストスイートを立て直す。vitest.config の複雑さを `vi.mock` の本数の問題として読み替え、消す前に棚卸しし、履歴から復元し、書いたテストは壊して実効性を確かめる。
- **[migrate-d1](./migrate-d1/SKILL.md)** — Cloudflare D1 のスキーマを移行する。生成されたテーブル再構築の SQL は D1 では子テーブルを空にするので、消える側を退避して戻す形に書き直し、当てる前に復元点を控える。
- **[domain-modeling](./domain-modeling/SKILL.md)** — プロジェクトのドメインモデルを能動的に構築し研ぎ澄ます — 用語に異議を唱え、シナリオでストレステストし、`CONTEXT.md` と ADR をその場で更新する。
- **[codebase-design](./codebase-design/SKILL.md)** — 深いモジュールを設計するための共有された規律と語彙: 小さなインターフェース、きれいなシーム、インターフェースを通してテスト可能。
- **[delegation](./delegation/SKILL.md)** — 作業をどこで走らせるかの共有された語彙: 大量の出力を子コンテキストへ押し出し、タスクに見合ったモデル階層に回す。
- **[verification-loop](./verification-loop/SKILL.md)** — 変更が本当に動くことを **クリーンラン** で確かめる: 記録された検証ゲートを中断なく1回で通し、そのうえで変更した経路を実際に駆動して観測の証拠を残す。
- **[two-axis-review](./two-axis-review/SKILL.md)** — 固定した基点からの差分に対する二軸レビュー: **Standards**(リポジトリのコーディング標準に従っているか、加えて Fowler のコードスメルの基準を満たしているか)と **Spec**(元になったイシュー/PRD を忠実に実装しているか)。並列のサブエージェントとして実行する。
- **[prune-comments](./prune-comments/SKILL.md)** — 書かれてしまったコメントを1パスで削る。順序の決まった6段を汚れていないコンテキストで当て、迷ったら Why を残し How を消す非対称の基準で倒す。
- **[resolving-merge-conflicts](./resolving-merge-conflicts/SKILL.md)** — 進行中の git マージやリベースのコンフリクトを、ハンクごとに、双方の一次情報源にたどれる意図に基づいて解決し、そのうえで操作を完了させる — `--abort` は決して使わない。
- **[ai-efficiency](./ai-efficiency/SKILL.md)** — 大量のファイル移動・リネーム・import 付け替えを、1ファイルずつ読み書きせずシェルで機械的に処理する: `git mv` で履歴を保ち、相対 import を絶対へ正規化してから一括置換し、抜けの検出は typecheck に委ねる。
- **[react-router-route-module](./react-router-route-module/SKILL.md)** — React Router（framework mode）の route module に何をどの export へ置くかの規律: 認可の強制点は `middleware`（loader と action の両方の手前を通る）、レイアウトが持つ値は `<Outlet context>` で配る。
- **[react-router-worker-tests](./react-router-worker-tests/SKILL.md)** — SSR フレームワークを `main` に載せた Cloudflare Worker のテストを組む。`applyD1Migrations` が `main` を立ち上げる事実から層を3つに割り、Worker を HTTP で叩く側は `createTestHarness` に渡す。
- **[drizzle-generate-non-interactive](./drizzle-generate-non-interactive/SKILL.md)** — TTY の無いところで `drizzle-kit generate` を完走させる。止まるのは rename の判定だけなので、その1問だけ pty 越しに答えを渡す。既定でハイライトされているのはデータが消える側である。
- **[where-to-write-what](./where-to-write-what/SKILL.md)** — コード・テスト・コメント・JSDoc・コミットメッセージ・PR 本文・ADR・docs のどこに何を書くかのルーティング規律: コードには How、テストには What、コミットログには Why、コメントには Why not。
- **[setup-rules](./setup-rules/SKILL.md)** — このリポジトリのルールを2層に敷く: `paths:` を持つ rule はその glob を編集するときだけ注入され、スタックに依存しない絶対ルールと追記先の優先順位は毎セッション読まれる側に置く。`/setup-skills` から引き継がれる。
- **[setup-skills](./setup-skills/SKILL.md)** — このリポジトリをエンジニアリング系スキル向けに設定する(イシュートラッカー、トリアージラベル、ドメインドキュメントの配置、検証ゲート、応答と記述の規約)。`/setup-repo` の工程 A。
- **[setup-ci](./setup-ci/SKILL.md)** — 記録された検証ゲートを CI に敷き、ローカルの規律を機構に変える。CI に載らない行(観測・シークレットを要る経路)を分け、必須チェックの設定はユーザーの手に残す。
- **[setup-hooks](./setup-hooks/SKILL.md)** — 散文では守られないルールを Claude Code のフックへ落として決定的に弾く。落とすのは3条件(すでに破られた・破られても気づけない・入力だけで機械的に判定できる)を満たすものだけ。
- **[setup-cf-app](./setup-cf-app/SKILL.md)** — 新規の Cloudflare Workers フルスタックアプリを、いつも使う標準ライブラリ構成で立ち上げる。バージョンやフラグは固定せず、各ツールの公式手順で都度組む。
- **[setup-cf-access](./setup-cf-access/SKILL.md)** — Cloudflare Access を Worker・ホスト名・パスに3層ルール(人間 / 機械 / 自前認証パス)で掛ける。書き込み権限を先に確かめ、不足していれば具体名で指示して止まる。
- **[setup-playwright](./setup-playwright/SKILL.md)** — Playwright の E2E を入れ、ブラウザを3つの層(VM のプロビジョニング・プロジェクトの用意・CI)のどこで用意するか決める。版の正は lockfile 側に置き、`executablePath` で実体を名指しする逃げ道を作らない。
