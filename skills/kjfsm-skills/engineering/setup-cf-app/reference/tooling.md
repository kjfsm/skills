# 型・lint・シークレット

## `worker-configuration.d.ts` はコミットして `--check` で見る

C3 テンプレートの `postinstall: wrangler types` は外し、`worker-configuration.d.ts` をコミットして `wrangler types --check` を検証ゲートの先頭に置く。Workers Builds はデプロイのたびに `pnpm install` を走らせるので、残すと本番のビルドに型生成が混ざる。

⚠️ `worker-configuration.d.ts` は標準ライブラリの型を自前で持つ。tsconfig の `lib` を上げても `toSorted` など ES2023 以降は型に出ない。コピーしてから `sort()` するなど、ES2022 までの書き方で済ませる。

## シークレットは `secrets.required` に名前を並べる

`wrangler.jsonc` の `secrets.required` にシークレットの名前を並べる。無いと `wrangler types` が手元の `.dev.vars` から型を拾い、**`.dev.vars` の無い CI でだけ型が変わる**。

## 生成物は oxlint と oxfmt の両方で除外する

生成物(`worker-configuration.d.ts`・`.react-router/`・`build/`・better-auth のスキーマ・`migrations/`)と shadcn の `components/ui/` は、oxlint と oxfmt の **両方** で除外する。設定ファイルは別々なので、片方にだけ足すと、もう片方が生成物を直そうとする。
