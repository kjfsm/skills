---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、いつも使う標準ライブラリ構成で立ち上げる。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# setup-cf-app(Cloudflare フルスタックアプリの標準構成)

新規プロジェクトで **いつも使うライブラリの組み合わせ** を宣言する。**準備手順と各 config は、記憶やこのファイルの固定値ではなく、その都度、各ツールの公式ドキュメント(と下記のオンデマンドスキル)で最新を確認して組む。** バージョン・フラグは陳腐化が速いので、ここには固定しない。

## 標準ライブラリ構成

| 分類            | 採用                                                                      |
| --------------- | ------------------------------------------------------------------------- |
| パッケージ管理  | pnpm                                                                      |
| フレームワーク  | React Router(framework mode / SSR)+ React                                 |
| ルーティング    | `react-router-auto-routes`(`app/routes/` のフォルダ構造がそのまま URL)    |
| ランタイム/配備 | Cloudflare Workers(wrangler + `@cloudflare/vite-plugin`)                  |
| ビルド          | Vite                                                                      |
| DB              | Cloudflare D1 + Drizzle ORM                                               |
| 認証            | better-auth(email/password + `socialProviders`。未対応のみ arctic で補完) |
| UI              | Tailwind CSS + shadcn/ui                                                  |
| 検証            | zod                                                                       |
| ID / 日付       | nanoid / date-fns + `@date-fns/tz`                                        |
| Lint / Format   | oxlint + oxfmt                                                            |
| テスト          | Vitest(+ `@cloudflare/vitest-plugin`)+ Playwright(E2E)                    |
| 型              | `wrangler types` + `react-router typegen` + `tsc -b`                      |

## init の落とし穴

各ツールの init と config は公式手順に従う。固定テンプレは持たず、都度最新を確認する。手元にあれば次のオンデマンドスキルを併用する: `cloudflare` / `wrangler` / `durable-objects`(Cloudflare 公式のプラグイン)、`react-router-framework-mode` / `shadcn`。

- スキャフォールドは C3(`pnpm create cloudflare@latest --framework=react-router`)を起点に、各ツールの公式 init(shadcn / oxlint / oxfmt / create-playwright)を実行する。
- **C3 の直後、各ツールの init より前に `pnpm up --latest` を実行する。** テンプレートが固定している版は最新から遅れていることがあり、その上に init を重ねると古い版に合わせた config ができる。範囲を無視してメジャーまで上がるので、テンプレートにある typecheck と build が通るのを確かめ、別コミットにしてから init へ進む — 混ぜると、赤くなったときに上げた依存と足したものの切り分けがつかない。
- **フラグを足すほど候補が減る init がある。** ここで挙げるのは版ではなく、公式手順を読んでも出てこない**黙って外れる挙動**である。止まった日は、この形を疑って `--help` で候補そのものを出す。
  - C3 は `--lang` を渡すと **言語バリアントを持たないフレームワークをテンプレート候補から落とす**。React Router はバリアントを持たないので、「指定を通す」ではなく `Unsupported framework: react-router` になり、フラグが原因だと読めない。フレームワーク名だけを渡すのが確実
  - C3 の `-y`(`--accept-defaults`)は `--framework` より強い。**カテゴリの既定(Hello World)でテンプレートを作り、成功として終わる**。TTY が無くても `-y` は要らない — フレームワークを渡せば残りの問いは既定で進む。生成物の `package.json` に `react-router` があるかで確かめる
  - shadcn の init は **リポジトリルートの `tsconfig.json` しか見ない**。React Router のように import エイリアスを分割 tsconfig 側へ置くテンプレートでは `Could not find valid path aliases` で止まるので、ルートにも `paths` を同値で置く。TTY が無いときは `-t`・`-b` に加えて `-p <プリセット>` も渡す — `-y` はプリセットの選択を飛ばさず、**そこで入力待ちのまま止まる**
  - `react-router-auto-routes` は `app/routes.ts` を `autoRoutes()` の1行にし、URL を `app/routes/` の配置だけで決める。**フォルダは URL セグメントを作るが `<Outlet />` のネストは作らない** — `_layout.tsx` を置いて初めて包まれる。置き忘れても共有 UI が出ないだけでビルドもテストも通るので、生成された表は `react-router routes` で出して確かめる
- **`pnpm up --latest` も `pnpm add` も peer の範囲を見ない。** 後から入れるプラグインが peer で上限を持つと(`@cloudflare/vitest-plugin` と `vitest` など)、先に入った最新が範囲外になる。プラグインを足したら peer を読み、範囲に揃える
- 重い UI ライブラリを足したら、まず `pnpm dev` で読み込めるかを見る。dev サーバーは workerd の中で動くので、CJS の依存は `require is not defined` で落ちることがある。`noExternal` で束ねて逃げると `react-router` が2重に載り、`RouterContextProvider` の検査が外れるという報告もある([cloudflare/workers-sdk#14555](https://github.com/cloudflare/workers-sdk/issues/14555))

## 型・lint・シークレット

- C3 テンプレートの `postinstall: wrangler types` は外し、`worker-configuration.d.ts` をコミットして `wrangler types --check` を検証ゲートの先頭に置く。Workers Builds はデプロイのたびに `pnpm install` を走らせるので、残すと本番のビルドに型生成が混ざる
- シークレットは公式どおり `wrangler.jsonc` の `secrets.required` に並べる。**並べたキーしか `.dev.vars` / `.env` から読まれない** ので、開発用のフラグのように秘密でない値をそこに置くなら、それも並べる — 漏れると警告も出ずに `undefined` になる
- 生成物(`worker-configuration.d.ts`・`.react-router/`・`build/`・better-auth のスキーマ・`migrations/`)と shadcn の `components/ui/` は、oxlint と oxfmt の **両方** で除外する。設定ファイルが別々なので、片方にだけ足すと、もう片方が生成物を直そうとする

## better-auth

better-auth 一般の組み方は、better-auth 公式の [better-auth/skills](https://github.com/better-auth/skills) にある `better-auth-best-practices` スキルが持つ(Claude Code のマーケットプレイスとしても、`npx skills` でも入る)。あちらは `BETTER_AUTH_URL` を env に置く前提で書かれているので、Workers では次の2点を優先する。

- DB と better-auth はリクエストごとに組み、`baseURL` にはリクエストのオリジン(`new URL(request.url).origin`)を渡す。`env` は route の `context` から受ける(→ `react-router-route-module` スキル)。モジュールの先頭で組むと `BETTER_AUTH_URL` を固定値で持つことになり、dev・http テスト・E2E でホストやポートが変わるたびに揃え直す
- スキーマ生成の CLI(`auth generate`)はオプションを読むだけで、DB にもシークレットにも触れない。アプリと同じオプションを組む関数に空の値(`{} as D1Database`・空文字・適当なオリジン)を渡すだけのファイルを置き、`--config` で読ませる。オプションを CLI 用に書き写すと、プラグインを足した日に片方だけが古くなり、生成されるスキーマからテーブルが欠ける

## ほかのスキルが持つもの

組むときに呼ぶ。

- Worker の `env` を loader / action へ渡す → `react-router-route-module` スキル
- E2E のサーバー → `setup-playwright` スキル
- マイグレーションの安全検査(検査スクリプトと再生テスト)を検証ゲートに置く → `migrate-d1` スキルの「再発を止める」
- テストのタイムゾーンの固定 → `create-tests` スキル

テンプレートのコードには、このスキル群が理由を持っている判断についてコメントを書かない — 同じ Why not が2か所に載り、片方だけ直る日が来る。スキルに無い Why not が見つかったら、テンプレートへのコメントより先にスキルへ足す。

## 完了

- [ ] 標準構成のライブラリが入り、各ツールの公式手順どおりに config が組まれている
- [ ] 上の「ほかのスキルが持つもの」を呼び、当てはまるものを組んだ
- [ ] `pnpm typecheck && pnpm lint && pnpm test` が green で、`pnpm dev` が起動する。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**
