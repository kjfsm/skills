---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、いつも使う標準ライブラリ構成で立ち上げる。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# setup-cf-app(Cloudflare フルスタックアプリの標準構成)

新規プロジェクトで **いつも使うライブラリの組み合わせ** を宣言する。**準備手順と各 config は、記憶やこのファイルの固定値ではなく、その都度、各ツールの公式ドキュメント(と下記のオンデマンドスキル)で最新を確認して組む。** バージョン・フラグは陳腐化が速いので、ここには固定しない。

## 標準ライブラリ構成

| 分類 | 採用 |
| --- | --- |
| パッケージ管理 | pnpm |
| フレームワーク | React Router(framework mode / SSR)+ React |
| ランタイム/配備 | Cloudflare Workers(wrangler + `@cloudflare/vite-plugin`) |
| ビルド | Vite |
| DB | Cloudflare D1 + Drizzle ORM |
| 認証 | better-auth(email/password + `socialProviders`。未対応のみ arctic で補完) |
| UI | Tailwind CSS + shadcn/ui |
| 検証 | zod |
| ID / 日付 | nanoid / date-fns + `@date-fns/tz` |
| Lint / Format | oxlint + oxfmt |
| テスト | Vitest(+ `@cloudflare/vitest-pool-workers`)+ Playwright(E2E) |
| 型 | `wrangler types` + `react-router typegen` + `tsc -b` |

## 準備・設定の参照先

各ツールの init と config は公式手順に従う。固定テンプレは持たず、都度最新を確認する。手元にあれば次のオンデマンドスキルを併用する:
`cloudflare` / `wrangler` / `react-router-framework-mode` / `shadcn` / `durable-objects` / `better-auth-best-practices`。

- スキャフォールドは C3(`pnpm create cloudflare@latest --framework=react-router`)を起点に、各ツールの公式 init(shadcn / oxlint / oxfmt / create-playwright)を実行する。
- D1/Drizzle・シークレット・E2E などプロジェクト固有の config は、その時点の公式手順で組む。
- React Router + Workers は CJS 依存パッケージで統合上の相性問題が出ることがある([cloudflare/workers-sdk#14555](https://github.com/cloudflare/workers-sdk/issues/14555) など)。重い UI ライブラリを足す前に現状を確認する。

## 完了

- [ ] 標準構成のライブラリが入り、各ツールの公式手順どおりに config が組まれている
- [ ] `pnpm typecheck && pnpm lint && pnpm test` が green で、`pnpm dev` が起動する
