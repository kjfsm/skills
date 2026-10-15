# API(Worker)の層

`SKILL.md` の手順3で D1 + Drizzle・better-auth・Hono の層に入ったら読む。

- **better-auth は `/api/auth/*` のハンドラの中でだけ動的 import する**(`await import("./auth")`)。静的 import が1本でも入ると、全要求の起動時評価に better-auth(数百 KB)が乗る。`better-auth/minimal` から import し、adapter は `better-auth/adapters/drizzle` — 素の `better-auth` は drizzle を使っていても kysely(約 430KB)を取り込む
- **ほかの `/api/*` は better-auth を import しない。** session Cookie の HMAC 署名を Web Crypto で検証し、D1 の session 表を token で1回引く。Cookie の名前と署名方式は推測せず、入っている better-auth / better-call の実装を読んで合わせ、**本物の better-auth が発行した Cookie を軽い検証が受け入れるテスト**で固定する(版を上げたらここが落ちる)。`cookieCache` は使わない — 復号に zod が走る
- 軽い検証は期限を延ばさない。画面が、ログイン済みのルートに入った文書ごとに1回だけ `/api/auth/get-session` を呼び、延長を better-auth に任せる。遷移ごとに呼ぶと、そのたびに better-auth を評価する Worker を起こす
- better-auth はリクエストごとに組み、`baseURL` にはリクエストのオリジンを渡す。`BETTER_AUTH_URL` を env に置くと、dev・テスト・E2E でホストやポートが変わるたびに揃え直す。Cookie の接頭辞(`advanced.cookiePrefix`)はアプリごとに変える — 手元では IdP や他のアプリと同じ localhost に同居し、Cookie はポートを区別しないので互いに上書きする
- スキーマ生成の CLI(`auth generate`)はオプションを読むだけで、DB にもシークレットにも触れない。アプリと同じオプションを組む関数に空の値を渡すファイルを置き、`--config` で読ませる。オプションを CLI 用に書き写すと、プラグインを足した日に片方だけ古くなり、テーブルが欠ける
- **`drizzle(env.DB)` に schema を渡さない**(relational query を使わない)。渡すと `extractTablesRelationalConfig` が要求ごとに走る。本番の CPU プロファイルでは Drizzle が約 46% を占め、better-auth(約 13%)より重かった
- **Worker では日付ライブラリを使わない。** API は ISO 文字列か epoch で話し、整形とタイムゾーンは画面で扱う。冷えた isolate での初回評価だけで数 ms かかる
- Worker が import するものはすべて起動に乗る。依存を足したら `wrangler check startup` で測る(zod と `@hono/zod-validator` だけで約 2ms)
