# Engineering

日々のコード作業のために使うスキル。

**ユーザー呼び出し型** は入力したときだけ到達できる(Claude Code: `disable-model-invocation: true`。Codex: `agents/openai.yaml` の `policy.allow_implicit_invocation: false`)。**モデル呼び出し型** はモデルからもユーザーからも到達できる(モデルが自動的に手を伸ばせるよう、豊富なトリガー表現を持つ)。

<!-- catalog:begin -->

**ユーザー呼び出し型**

- **[ask-kjfsm](./ask-kjfsm/SKILL.md)** — どのスキルやフローが自分の状況に合うかを尋ねる。このリポジトリのスキルを案内するルーター。
- **[implement-and-review](./implement-and-review/SKILL.md)** — スペックやチケットが記述する作業を、既定ブランチへの追従からビルド・検証・コメント削り・二軸レビュー・PR まで1本で進める。
- **[setup-repo](./setup-repo/SKILL.md)** — このリポジトリのエージェント向け設定を一括で敷く — 規約とドキュメント配置、パス別ルール、CI、弾く機構。再実行すると現況を読み、足りない工程とずれた箇所だけを当てる。
- **[squash-d1-migrations](./squash-d1-migrations/SKILL.md)** — 積み上がった D1 のマイグレーションを1本に畳み、適用済みの各環境と突き合わせる。
- **[tend-memory-files](./tend-memory-files/SKILL.md)** — AGENTS.md・CLAUDE.md と .claude/rules/ を新規に書く、または既存のものを監査してトリムする — 行数の目安に収め、具体的で矛盾のない指示だけを残す。

**モデル呼び出し型**

- **[ai-efficiency](./ai-efficiency/SKILL.md)** — 大量のファイル移動・リネーム・import 付け替えを、1ファイルずつ読み書きせずシェルで機械的に処理する戦略。「大量リネーム」「一括置換」「ディレクトリ再編」「import パスの一括付け替え」などで参照する。
- **[d1-bound-parameters](./d1-bound-parameters/SKILL.md)** — Cloudflare D1 へ多数の値を渡すクエリの規律 — bound parameter は1文あたり100個まで。`D1_ERROR: too many SQL variables` が出たとき、D1 へ大量の行を INSERT するとき、`inArray` / `IN (...)` に長い ID の列を渡すとき、`db.batch()` で分割するときに使う。
- **[delegation](./delegation/SKILL.md)** — 作業をサブエージェントの子コンテキストへ押し出し、タスクに見合ったモデル階層に回す判断。サブエージェントを起動するとき、大量の出力を伴う作業を始めるとき、他のスキルが委譲の語彙を必要とするときに使う。
- **[dev-bypass-sign-in](./dev-bypass-sign-in/SKILL.md)** — 叩くだけでサインイン済みになる開発・E2E 用の入口(dev bypass)を作る。ログインの要る画面を E2E やエージェントから駆動したいとき、dev サーバーでソーシャルログインやパスワード登録を踏まずに座りたいとき、better-auth の `testUtils` の使いどころを決めるとき、既存の bypass の戸が本番の成果物に残っていないか確かめたいとき、他のスキルが認証済みのセッションを必要とするときに使う。
- **[drizzle-generate-non-interactive](./drizzle-generate-non-interactive/SKILL.md)** — TTY の無いところで `drizzle-kit generate` を完走させる。エージェント・フック・CI から generate を回すとき、`Interactive prompts require a TTY terminal` で落ちたとき、`missing_hints` で exit 2 したとき、rename を含むスキーマ変更のマイグレーションを生成するときに使う。
- **[migrate-d1](./migrate-d1/SKILL.md)** — Cloudflare D1 のスキーマを変えるときの規律。drizzle-kit などが `PRAGMA foreign_keys=OFF` と `DROP TABLE` を含むマイグレーションを生成したとき、列を NOT NULL にしたいとき、CHECK 制約や複合ユニークを足したいとき、本番に `--remote` でマイグレーションを当てる前に使う。**D1 では `PRAGMA foreign_keys=OFF` が効かないので、生成物をそのまま流すと参照している側のテーブルが空になる。**
- **[partyserver-on-durable-objects](./partyserver-on-durable-objects/SKILL.md)** — partyserver(`Server`)を Durable Object の上に載せるときの、公式ドキュメントに載っていない挙動。stub の取り方でリクエスト数が2倍になるとき、`onStart` に初期化や移行を置くとき、WebSocket のハイバネーションと keepalive を組むとき、RPC メソッドを足すか `onRequest` のままにするか決めるときに使う。素の Durable Objects の API は公式の `durable-objects` スキルが持つ。
- **[prune-comments](./prune-comments/SKILL.md)** — 書かれてしまったコメントを1パスで削る。コミットや PR を出す直前、コメントが冗長・AI が書いたように見える・整理したいとき、他のスキルがコメントの掃除を必要とするときに使う。順序の決まった6段のルールと非対称の残す基準を当て、実行ごとのばらつきを潰す。
- **[prune-tests](./prune-tests/SKILL.md)** — 既存のテストを全部読み、削除・統合できるものを「消すと、どんな現実的な不具合を見逃すか」で洗い出す。テストが多すぎる・遅い・振る舞いを変えない変更のたびに大量に落ちるとき、テストを整理したい・減らしたいとき、他のスキルが削れるテストの判定を必要とするときに使う。
- **[react-router-route-module](./react-router-route-module/SKILL.md)** — React Router（framework mode）の route module に何をどの export へ置くかの規律。認可ガードを足すとき、loader と action に同じチェックを書いているとき、レイアウトが持つ値を配下のコンポーネントへ渡したいとき、`useRouteLoaderData` と `<Outlet context>` のどちらを使うか迷ったとき、Cloudflare Workers の `env` を loader / action へ渡すときに使う。
- **[setup-cf-access](./setup-cf-access/SKILL.md)** — Cloudflare Access を Worker・ホスト名・パスに、いつもの3層ルール(人間=指定メール / 機械=サービストークン / アプリ側に認証があるパス=bypass)で掛ける。「Access を掛ける」「認証を必要にする」「workers.dev が素通り」「Zero Trust のアプリを作る」で参照する。
- **[setup-cf-app](./setup-cf-app/SKILL.md)** — 新規の Cloudflare Workers フルスタックアプリを、いつも使う標準ライブラリ構成で立ち上げる。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
- **[setup-ci](./setup-ci/SKILL.md)** — 記録された検証ゲートを CI に敷き、ローカルの規律を機構に変える。ゲートを強制する仕組みがまだ無いとき（CI が無い、あるいは誰も走らせていない）、CI が `docs/agents/verification.md` とずれてきたとき、`/kjfsm-skills:setup-repo` の工程 C として使う。
- **[setup-hooks](./setup-hooks/SKILL.md)** — 散文のルールでは守られないものを機構へ落とし、決定的に弾く — `permissions.deny`、git hook と CI が同じ述語を呼ぶ検査スクリプト、Claude Code のフックの3層。書いてある規約が実際には破られ続けているとき（生成物の手編集、シークレットのコミット）、フックにだけ存在する検査が CI やクローンをすり抜けているとき、セッション開始時に環境を用意させたいとき、`/kjfsm-skills:setup-repo` の工程 D として使う。
- **[setup-playwright](./setup-playwright/SKILL.md)** — Playwright の E2E を入れ、ブラウザをどの層で用意するか決める。E2E をこれから入れるとき、`Executable doesn't exist` や `Missing system dependencies` が出たとき、コンテナやクラウドのサンドボックスに置いてあるブラウザと Playwright が要求するビルド番号がずれたとき、CI でだけブラウザの取得に失敗するとき、`playwright install` をセットアップスクリプト・SessionStart フック・CI のどこに置くか決めるときに使う。
- **[setup-rules](./setup-rules/SKILL.md)** — このリポジトリのルールを `.claude/rules/` と `AGENTS.md` の2層に敷く — パスに応じて自動注入されるパス別ルールと、全セッションに効く絶対ルール。Claude Code を使うリポジトリを初めて設定するとき、`.claude/rules/` がまだ無いとき、同じ指摘を2回以上受けてルールに落としたいとき、`/kjfsm-skills:setup-repo` の工程 B として使う。
- **[setup-skills](./setup-skills/SKILL.md)** — このリポジトリをエンジニアリング系スキル向けに設定する — イシュートラッカー、トリアージラベルの語彙、ドメインドキュメントの配置、検証ゲート、応答と記述の規約。`docs/agents/` がまだ無いとき、他のエンジニアリング系スキルを初めて使う前、`/kjfsm-skills:setup-repo` の工程 A として使う。
- **[two-axis-review](./two-axis-review/SKILL.md)** — まだコミットしていない編集と新規ファイルまで含めて、差分を kjfsm のレビュアー2体で並列にレビューする — Standards(明文化された標準、Fowler のスメル、書かれなかった Why not)と Spec(元のイシュー/PRD)。範囲は固定した基点(コミット、ブランチ、タグ)とのマージベースから作業ツリーまで。コミット前の作業をレビューしたいとき、ブランチ・PR・進行中の変更をレビューしたいとき、「X 以降をレビューして」と求めたとき、他のスキルが差分のレビューを必要とするときに使う。
- **[verification-loop](./verification-loop/SKILL.md)** — 変更が本当に動くことを、記録された検証ゲートのクリーンラン — 型チェック、lint、テスト、ビルド、そして実際に動かしての観測 — で確かめる。ユーザーが動作確認や検証を求めたとき、変更を完了と宣言する前(コミットや PR を出す直前)、他のスキルが作業の検証を必要とするときに使う。
- **[where-to-write-what](./where-to-write-what/SKILL.md)** — コード・テスト・コメント・JSDoc・コミットメッセージ・PR 本文・ADR・docs のどこに何を書くかを決めるルーティング規律 — コードには How、テストには What、コミットログには Why、コメントには Why not。コメントを書くか消すか判断するとき、JSDoc に何を載せるか決めるとき、コミットメッセージや PR 本文を書くとき、README を足すか迷ったとき、実装の背景や設計判断をどこに残すか迷ったときに使う。
- **[workers-tests](./workers-tests/SKILL.md)** — Cloudflare Workers のプロジェクトでテストスイートを作る・立て直すときの規律。テストが1本も無いところから始めるとき、vitest.config が複雑すぎる・テストが遅い・OOM する・vi.mock だらけで信用できないとき、@cloudflare/vitest-plugin(旧 @cloudflare/vitest-pool-workers)を上げたら壊れたとき、React Router などの SSR を `main` に載せていて1ファイルに十数秒かかる・`applyD1Migrations` が遅い・`createTestHarness` で HTTP の層を作るとき、Workers / D1 / Durable Objects / Queues にテストを入れたいときに使う。

<!-- catalog:end -->
