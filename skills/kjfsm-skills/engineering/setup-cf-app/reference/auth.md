# better-auth を Workers で組む

better-auth 一般の組み方(プラグイン、セッション、セキュリティ設定)は、better-auth 公式が GitHub の [better-auth/skills](https://github.com/better-auth/skills) で配っている `better-auth-best-practices` スキルが持つ(`npx skills` で入る)。あちらは `BETTER_AUTH_URL` がある前提で書かれている。ここに置くのは、Workers で組むときにそれと食い違う部分だけである。

## リクエストごとに組み、`baseURL` はオリジンから取る

DB と better-auth はリクエストごとに組む。`env` は route の `context` から受け(→ `react-router-route-module` スキル)、`baseURL` にはリクエストのオリジン(`new URL(request.url).origin`)を渡す。モジュールの先頭で組むと `BETTER_AUTH_URL` を固定値で持つことになり、dev・http テスト・E2E でホストやポートが変わるたびに揃え直す。

## CLI には空の値を渡すだけの設定ファイルを読ませる

スキーマ生成の CLI(`auth generate`)はオプションを読むだけで、DB にもシークレットにも触れない。アプリと同じオプションを組む関数に空の値(`{} as D1Database`・空文字・適当なオリジン)を渡すだけのファイルを置き、`--config` で読ませる。オプションを CLI 用に書き写すと、プラグインを足した日に片方だけが古くなり、生成されるスキーマからテーブルが欠ける。
