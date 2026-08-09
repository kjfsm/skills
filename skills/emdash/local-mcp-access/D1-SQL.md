# `wrangler d1 execute` で直接SQLを読む

MCPのコアツールでも Block Kit の `/admin` ルートでも届かないもの — 生のテーブル構造、
`ctx.kv` / `ctx.storage` の実体、複数テーブルを跨いだ突き合わせ — を見るときに開く。
devサーバーも PAT も要らない。

## 目次

- [読み方と `--remote` / `--local` の違い](#mcpと併用する-wrangler-d1-execute-での直接sql読み取り)
- [主なテーブル種別](#主なテーブル種別)
- [重要な注意: シークレットはここでは一切マスクされない](#重要な注意-シークレットはここでは一切マスクされない)

## MCPと併用する: `wrangler d1 execute` での直接SQL読み取り

MCPのコアツール(`content_*`/`schema_*`/`settings_*`など)とBlock Kitの
`/admin`ルート(プラグイン自身の設定)で読める範囲は決まっている。それ以外
——生のテーブル構造そのもの、プラグインの `ctx.kv`/`ctx.storage` が実際に
どのテーブル・どのキー名で保存されているか、複数テーブルを跨いだ突き合わせ
など——を確認したいときは、`wrangler d1 execute` で直接SQLを読みに行くのが
最短ルートになる。devサーバーを起動する必要も、`dev-bypass`でPATを発行する
必要も、`wrangler.jsonc`を書き換える必要もない。

```bash
# データベース名は wrangler.jsonc の d1_databases[].database_name
# (binding名の "DB" ではない。database_id をそのまま渡しても動く)
npx wrangler d1 execute <database_name> --remote \
  --command "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
```

- `--remote` を付けると、デプロイ済みのWorkerが実際に使っている**本番のD1
  そのもの**に直接クエリが飛ぶ(コピーではない)。`wrangler whoami` で
  ログイン済みかつそのアカウントに対象D1への権限があれば、それだけで動く
  ——`dev-bypass`もPATも一切不要。
- `--remote` を外す(または `--local` を付ける)と、`npx emdash dev` /
  `astro dev` が使っているのと**同じローカルのMiniflareエミュレートD1**
  (`.wrangler/state` 以下)を読む。devサーバーを起動していなくても読める。
- **`--remote` に対しては、ユーザーの明示的な許可なしにSELECT以外の文を
  実行しないこと。** UPDATE/DELETE/INSERTを`--remote`に対して実行するのは
  本番データへの直接書き込みそのものであり、取り消せない。MCPの
  `content_update`/`content_delete`などタイプ付きのツールがある操作は、
  生SQLではなくそちら経由で行うこと——生SQLの書き込みは、それらのツールが
  届かない範囲(スキーマ移行の手直しなど)に限り、かつ都度ユーザーに確認を
  取った上でのみ行う。

### 主なテーブル種別

- `ec_<collection>`(例: `ec_blog`、`ec_works`) — 各コレクションの
  コンテンツ本体。
- `options` — サイト設定(`site:`プレフィックス)**に加えて**、in-process
  (native)としてロードされているプラグインの `ctx.kv` の実体もここに入る
  ——キー名は `plugin:<plugin-id>:settings:<key>` の形。sandboxed前提の
  ドキュメント(Settings/KV store)には「プラグインごとに隔離されたKV」と
  書かれているが、in-process読み込みの場合は物理的にはこの共有テーブルに
  プレフィックス付きで乗っているだけ、という点に注意。
- `_plugin_storage`(`plugin_id`, `collection`, `id`, `data`, ...) —
  sandboxedプラグインの `ctx.storage`(インデックス付きコレクション)に
  相当するテーブル。
- `_plugin_state`(`plugin_id`, `version`, `status`, ...) — プラグインの
  インストール/有効化状態を持つテーブル。ただしnative(in-process)実行の
  プラグインは行を持たないことがある——sandboxed想定のテーブルがnative実行時に
  使われないケースがあるため、空だったことをすぐに「未設定」と誤読しないこと。

### 重要な注意: シークレットはここでは一切マスクされない

Block Kitの`/admin`ルートは`secret_input`フィールドの値を絶対に返さない
仕様だが、それはアプリ層(admin UI/APIレスポンス)だけの話であり、D1の
生の行には**平文でそのまま**入っている。プラグインがトークン類を
`ctx.kv` に保存していれば、`options` テーブルの
`plugin:<plugin-id>:settings:<key>` にそのまま平文で載る。

生SQLでこの種のキー(`*secret*`/`*token*`/`*key*` などを含む名前)を
`SELECT`し、その`value`をそのまま出力・会話に貼り付けることは、実在する
シークレットの漏洩になる。テーブル名やキー名の**存在確認**
(`SELECT name FROM options WHERE name LIKE '%token%'`)までは安全だが、
値そのもの(`SELECT value FROM ...`)を取得・表示するのは避けること。
