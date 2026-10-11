---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、Free プランに収まる標準構成(Vite の React SPA + Hono の API Worker)で立ち上げる。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# setup-cf-app(Cloudflare フルスタックアプリの標準構成)

新規プロジェクトで **いつも使う構成** を宣言する。前提は Workers の **Free プラン**(1 回の実行ごとに CPU 10ms)。**準備手順と各 config は、記憶やこのファイルの固定値ではなく、その都度、各ツールの公式ドキュメントで最新を確認して組む。** バージョン・フラグは陳腐化が速いので、ここには固定しない。

## 標準構成

| 分類           | 採用                                                                           |
| -------------- | ------------------------------------------------------------------------------ |
| 起点           | C3 で生成する公式 `cloudflare/templates` の `vite-react-template`              |
| パッケージ管理 | pnpm                                                                           |
| 画面           | React + Vite の SPA + TanStack Router(ファイルベース)+ TanStack Query          |
| 配信           | Workers Static Assets(画面の要求は Worker を起こさない)                        |
| API            | Hono + Hono RPC(`hc<AppType>`)+ zod                                            |
| DB             | Cloudflare D1 + Drizzle ORM                                                    |
| 認証           | better-auth(認証先はその都度聞く)                                              |
| UI             | Tailwind CSS + shadcn/ui                                                       |
| Lint / Format  | oxlint + oxfmt                                                                 |
| テスト         | Vitest + `@cloudflare/vitest-plugin`(Worker の API)。E2E は `setup-playwright` |
| 型             | `wrangler types` + `tsr generate` + `tsc -b`                                   |

**React Router と TanStack Start は使わない。** どちらも Worker の中で React を動かす。React Router の SSR は HTML の生成だけで 22〜57ms、冷えた isolate でのバンドル評価に 13〜37ms かかり、10ms に収まらなかった。React Router の SPA Mode は SSR を前提にした概念を切って使う形で、Worker 側に React Router が残る。TanStack Start は SPA mode でも `react-dom/server` がサーバーバンドルに残り、Worker が起きるたびに約 13ms の固定費を払う。Vite の SPA + Hono なら起動は 0〜4ms で済む(2026-10 の実測)。

## 1. 決める

組み始める前に、ユーザーに2つだけ聞く。推測で埋めない — どちらもあとから替えると、スキーマとマイグレーションを作り直す。

- **認証先** — Google などの social、email/password、`kjfsm-personal` プラグインが入っていれば kjfsm の共通 IdP(→ `/kjfsm-personal:connect-kjfsm-auth`)。**email/password は CPU を食う。** パスワードのハッシュ化(scrypt)が予算ぎりぎりで動く(better-auth#8860)ので、選んだら登録とログインの経路を本番で別に測る
- **DB** — このアプリだけの D1 を作るか、`kjfsm-personal` プラグインが入っていれば共有 D1 に相乗りするか(→ `/kjfsm-personal:kjfsm-shared-db`)

完了基準: 2つの答えが出ている。

## 2. 雛形を作る

- `pnpm create cloudflare@latest <名前> --template=cloudflare/templates/vite-react-template` に、git 初期化・デプロイ・ブラウザ起動を抑えるフラグを付ける(`--help` で確かめる)。`cf init` は使わない — hello-world の Worker か既存ディレクトリの autoconfig しか作らず、公式テンプレートを起点にできない(2026-10、v1.0.0-beta.5。この構成では `cf build` も `Hono cannot be automatically configured` で落ちた)。**生成物を、手を入れずに最初のコミットにする。** 公式との差分が `git diff <起点>` でいつでも読め、公式の更新を取り込むときの比較元になる
- **生成直後、各ツールの init より前に `pnpm up --latest` を実行する。** テンプレートが固定している版は遅れていることがあり、その上に init を重ねると古い版に合わせた config ができる。typecheck と build が通るのを確かめ、別コミットにする — 混ぜると、赤くなったときに上げた依存と足したものの切り分けがつかない
- C3 は **フラグを足すほど候補が減る。** `--lang` は言語バリアントを持たないテンプレートを候補から落とし、`-y` はカテゴリの既定(Hello World)で作って成功として終わる。生成物の `package.json` に `hono` と `@cloudflare/vite-plugin` があるかで確かめる
- **公式の構成を保つ**(`src/react-app/` に画面、`src/worker/` に Worker、tsconfig の分割、`wrangler.json`)。寄せ替えると差分が全ファイルの書き換えになり、起点を公式にした意味が消える

手元に `kjfsm/cf-workers-free-template`(非公開)があれば、それが同じ起点から差分を層ごとに積んだ履歴である。最初のコミット(C3 の生成物そのまま)から `main` までの層を順に写してよい。ただし認証は kjfsm-auth、DB は共有 D1 に固定されているので、手順 1 で別の答えなら、同リポジトリの README の「フォークしたら」「新規 D1 に切り替える」に沿って差し替える。

## 3. 差分を積む(層ごとにコミット)

順に、lint(ESLint → oxlint + oxfmt)→ Tailwind / shadcn → D1 + Drizzle → better-auth と軽いセッション検証 → Hono の API → TanStack Router / Query の画面 → テスト。各ツールの init と config は公式手順に従い、ここに書くのは公式に無い不変条件と、黙って外れる挙動だけである。

### 配信

- `wrangler.json` の `assets` は `not_found_handling: "single-page-application"`、`run_worker_first: ["/api/*"]`。**OAuth のコールバックは画面遷移の要求**なので、これが無いと SPA のフォールバックに吸われて `index.html` が返り、ログインが終わらない。開発用の入口(`/kjfsm-skills:dev-bypass-sign-in`)も `/api/` の下に置く
- `run_worker_first` を配列で書くと、アセットに無い要求は JS の要求でも `index.html` の 200 になる。デプロイの前に開いていたタブが消えた分割 JS を読みに行くと壊れるので、`vite:preloadError` を受けて1回だけ読み直す

### API(Worker)

- **better-auth は `/api/auth/*` のハンドラの中でだけ動的 import する**(`await import("./auth")`)。静的 import が1本でも入ると、全要求の起動時評価に better-auth(数百 KB)が乗る。`better-auth/minimal` から import し、adapter は `better-auth/adapters/drizzle` — 素の `better-auth` は drizzle を使っていても kysely(約 430KB)を取り込む
- **ほかの `/api/*` は better-auth を import しない。** session Cookie の HMAC 署名を Web Crypto で検証し、D1 の session 表を token で1回引く。Cookie の名前と署名方式は推測せず、入っている better-auth / better-call の実装を読んで合わせ、**本物の better-auth が発行した Cookie を軽い検証が受け入れるテスト**で固定する(版を上げたらここが落ちる)。`cookieCache` は使わない — 復号に zod が走る
- 軽い検証は期限を延ばさない。画面が、ログイン済みのルートに入った文書ごとに1回だけ `/api/auth/get-session` を呼び、延長を better-auth に任せる。遷移ごとに呼ぶと、そのたびに better-auth を評価する Worker を起こす
- better-auth はリクエストごとに組み、`baseURL` にはリクエストのオリジンを渡す。`BETTER_AUTH_URL` を env に置くと、dev・テスト・E2E でホストやポートが変わるたびに揃え直す。Cookie の接頭辞(`advanced.cookiePrefix`)はアプリごとに変える — 手元では IdP や他のアプリと同じ localhost に同居し、Cookie はポートを区別しないので互いに上書きする
- スキーマ生成の CLI(`auth generate`)はオプションを読むだけで、DB にもシークレットにも触れない。アプリと同じオプションを組む関数に空の値を渡すファイルを置き、`--config` で読ませる。オプションを CLI 用に書き写すと、プラグインを足した日に片方だけ古くなり、テーブルが欠ける
- **`drizzle(env.DB)` に schema を渡さない**(relational query を使わない)。渡すと `extractTablesRelationalConfig` が要求ごとに走る。本番の CPU プロファイルでは Drizzle が約 46% を占め、better-auth(約 13%)より重かった
- **Worker では日付ライブラリを使わない。** API は ISO 文字列か epoch で話し、整形とタイムゾーンは画面で扱う。冷えた isolate での初回評価だけで数 ms かかる
- Worker が import するものはすべて起動に乗る。依存を足したら `wrangler check startup` で測る(zod と `@hono/zod-validator` だけで約 2ms)

### 画面

- データの取得は1エンドポイント = 1 `queryOptions`。loader は値を返さず `queryClient.query({ ...options, staleTime: "static" })` で待ち、コンポーネントは `useSuspenseQuery` で読む。loader の戻り値を `useLoaderData` で読む形にしないのは、戻り値が Query のキャッシュの外にあり、書き込みのあとの invalidate で取り直されないから。`ensureQueryData` / `prefetchQuery` は非推奨で、`queryClient.query` に置き換わった
- ログインが要るルートは `beforeLoad` で振り分ける。**表示の振り分けで、認可ではない** — 認可は API の middleware が強制する
- 画面が Worker から import するのは `AppType` の型だけにする(`import type`)。値を import すると、Worker 側の依存(Drizzle・better-auth)がクライアントのバンドルに入る

### init の落とし穴

- shadcn の init は **リポジトリルートの `tsconfig.json` しか見ない**。公式テンプレートのように tsconfig を分割していると `Could not find valid path aliases` で止まるので、ルートにも `paths` を同値で置く。TTY が無いときは `-t`・`-b` に加えて `-p <プリセット>` も渡す — `-y` はプリセットの選択を飛ばさず、そこで入力待ちのまま止まる
- **`pnpm up --latest` も `pnpm add` も peer の範囲を見ない。** 後から入れるプラグインが peer で上限を持つと(`@cloudflare/vitest-plugin` と `vitest` など)、先に入った最新が範囲外になる。プラグインを足したら peer を読み、範囲に揃える
- 重い依存を足したら、まず `pnpm dev` で読み込めるかを見る。dev サーバーは workerd の中で動くので、事前バンドルから漏れた CJS の依存は `require is not defined` で落ちる

## 型・lint・シークレット

- `worker-configuration.d.ts` はコミットし、`wrangler types --check` を検証の先頭に置く。`postinstall` で生成させると、Workers Builds のデプロイのたびに型生成が混ざる
- `typecheck` は `wrangler types && tsr generate && tsc -b`。`routeTree.gen.ts` は Vite のプラグインが dev で作るので、dev を立てない CI では `tsr generate` が無いと型が古いまま通る
- シークレットは `wrangler.json` の `secrets.required` に並べる。**並べたキーしか `.dev.vars` から読まれない** — 秘密でない開発用のフラグも、ここに置くなら並べる。漏れると警告も出ずに `undefined` になる
- 生成物(`worker-configuration.d.ts`・`routeTree.gen.ts`・better-auth のスキーマ・`migrations/`・`dist/`)と shadcn の `components/ui/` は、oxlint と oxfmt の **両方** で除外する。設定ファイルが別々なので、片方にだけ足すと、もう片方が生成物を直そうとする

## ほかのスキルが持つもの

- 規約・rules・フック・worktree の設定 → `/kjfsm-skills:setup-repo`(このスキルの次に呼ぶ)
- マイグレーションの書き直しと安全検査 → `/kjfsm-skills:migrate-d1`
- テストの組み方 → `/kjfsm-skills:workers-tests`、E2E → `/kjfsm-skills:setup-playwright`
- ログイン無しで座る入口 → `/kjfsm-skills:dev-bypass-sign-in`

テンプレートのコードには、このスキル群が理由を持っている判断についてコメントを書かない — 同じ Why not が2か所に載り、片方だけ直る日が来る。スキルに無い Why not が見つかったら、テンプレートへのコメントより先にスキルへ足す。

## 完了

- [ ] 手順 1 の2つの答えに沿って、認証先と DB が組まれている
- [ ] 起点が C3 の生成物そのままのコミットで、その上に層ごとのコミットが積まれている
- [ ] `/api/auth/*` 以外から better-auth が静的 import されていない(ビルド成果物の Worker の入口を辿って確かめる)
- [ ] 本物の better-auth の Cookie を軽い検証が受け入れるテストがあり、型チェック・lint・テスト・ビルドが green
- [ ] `pnpm dev` でログインから1つの機能までを画面で通した。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**
- [ ] `/kjfsm-skills:setup-repo` へ進んだ
