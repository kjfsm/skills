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

## 準備・設定の参照先

各ツールの init と config は公式手順に従う。固定テンプレは持たず、都度最新を確認する。手元にあれば次のオンデマンドスキルを併用する:
`cloudflare` / `wrangler` / `react-router-framework-mode` / `shadcn` / `durable-objects` / `better-auth-best-practices`。

- スキャフォールドは C3(`pnpm create cloudflare@latest --framework=react-router`)を起点に、各ツールの公式 init(shadcn / oxlint / oxfmt / create-playwright)を実行する。
- **C3 の直後、各ツールの init より前に `pnpm up --latest` を実行する。** テンプレートが固定している版は最新から遅れていることがあり、その上に init を重ねると古い版に合わせた config ができる。範囲を無視してメジャーまで上がるので、テンプレートにある typecheck と build が通るのを確かめ、別コミットにしてから init へ進む — 混ぜると、赤くなったときに上げた依存と足したものの切り分けがつかない。
- **フラグを足すほど候補が減る init がある。** ここで挙げるのは版ではなく、公式手順を読んでも出てこない**黙って外れる挙動**である。止まった日は、この形を疑って `--help` で候補そのものを出す。
  - C3 は `--lang` を渡すと **言語バリアントを持たないフレームワークをテンプレート候補から落とす**。`--platform` も同じで、プラットフォーム別バリアントを持たないものが外れる。どちらも「指定を通す」ではなく `Unsupported framework: <名前>` になるので、フラグが原因だと読めない。フレームワーク名だけを渡すのが確実
  - C3 の `-y`(`--accept-defaults`)は `--framework` より強い。**カテゴリの既定(Hello World)でテンプレートを作り、成功として終わる**。TTY が無くても `-y` は要らない — フレームワークを渡せば残りの問いは既定で進む。生成物の `package.json` に `react-router` があるかで確かめる
  - shadcn の init は **リポジトリルートの `tsconfig.json` しか見ない**。React Router のように import エイリアスを分割 tsconfig 側へ置くテンプレートでは `Could not find valid path aliases` で止まるので、ルートにも `paths` を同値で置く。TTY が無いときは `-t`・`-b` に加えて `-p <プリセット>` も渡す — `-y` はプリセットの選択を飛ばさず、**そこで入力待ちのまま止まる**
  - `react-router-auto-routes` は `app/routes.ts` を `autoRoutes()` の1行にし、URL を `app/routes/` の配置だけで決める。**フォルダは URL セグメントを作るが `<Outlet />` のネストは作らない** — `_layout.tsx` を置いて初めて包まれる。置き忘れても共有 UI が出ないだけでビルドもテストも通るので、生成された表は `react-router routes` で出して確かめる
- **`pnpm up --latest` も `pnpm add` も peer の範囲を見ない。** 後から入れるプラグインが peer で上限を持つと(`@cloudflare/vitest-plugin` と `vitest` など)、先に入った最新が範囲外になる。プラグインを足したら peer を読み、範囲に揃える
- D1/Drizzle・シークレット・E2E などプロジェクト固有の config は、その時点の公式手順で組む。そのうえで公式に書かれていない2つ:
  - シークレットは `wrangler.jsonc` の `secrets.required` に名前を並べる。無いと `wrangler types` が手元の `.dev.vars` から型を拾い、**`.dev.vars` の無い CI でだけ型が変わる**
  - E2E のサーバーを `vite preview` で立てない。ビルドが `.dev.vars` を `build/server/` へ複写し、preview はそれを優先してプロセス環境を見ないので、E2E 用の値が渡らない(`.dev.vars` の無い CI では秘密ごと欠ける)。`wrangler dev -c build/server/wrangler.json --env-file <E2E 用の env> --persist-to <E2E 専用>` で立てる
- C3 テンプレートの `postinstall: wrangler types` は外し、`worker-configuration.d.ts` をコミットして `wrangler types --check` を検証ゲートの先頭に置く。Workers Builds はデプロイのたびに `pnpm install` を走らせるので、残すと本番のビルドに型生成が混ざる
- ⚠️ `worker-configuration.d.ts` は標準ライブラリの型を自前で持つ。tsconfig の `lib` を上げても `toSorted` など ES2023 以降は型に出ない
- DB と better-auth はリクエストごとに組む。`env` は `workers/app.ts` で `RouterContextProvider` に載せて loader / action へ渡し、better-auth の `baseURL` はリクエストのオリジンから取る。モジュールの先頭で `cloudflare:workers` の `env` から組むと `BETTER_AUTH_URL` を固定値で持つことになり、dev・http テスト・E2E でホストやポートが変わるたびに揃え直す。auth の CLI には、同じオプションに空の値を渡すだけのファイルを `--config` で読ませる
- 生成物(`worker-configuration.d.ts`・`.react-router/`・`build/`・better-auth のスキーマ・`migrations/`)と shadcn の `components/ui/` は、oxlint と oxfmt の両方で除外する
- マイグレーションの安全検査(検査スクリプトと再生テスト)を検証ゲートに置く。中身は `/kjfsm-skills:migrate-d1` の「再発を止める」
- テストのタイムゾーンは `/kjfsm-skills:create-tests` のとおり `vitest.config.ts` の先頭で固定する
- React Router + Workers は CJS 依存パッケージで統合上の相性問題が出ることがある([cloudflare/workers-sdk#14555](https://github.com/cloudflare/workers-sdk/issues/14555) など)。重い UI ライブラリを足す前に現状を確認する。

テンプレートのコードには、このスキル群が理由を持っている判断についてコメントを書かない — 同じ Why not が2か所に載り、片方だけ直る日が来る。スキルに無い Why not が見つかったら、テンプレートへのコメントより先にスキルへ足す。

## 完了

- [ ] 標準構成のライブラリが入り、各ツールの公式手順どおりに config が組まれている
- [ ] `pnpm typecheck && pnpm lint && pnpm test` が green で、`pnpm dev` が起動する。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**
