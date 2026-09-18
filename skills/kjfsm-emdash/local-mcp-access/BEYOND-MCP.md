# MCPで届かない操作

コアMCPのツールでは足りないときに開く。手順2で発行したBearer PATは、MCPだけでなく
`/_emdash/api/*`のRESTにもそのまま効く。本番に対しては正規に発行したPATを使う(SKILL.mdの
「本番に対してこれを使わないこと」)。

## ツールが無いのでRESTを叩くもの

- **ウィジェット** — `menu_*`はあるが`widget_*`は無い。
  `GET` / `DELETE /_emdash/api/widget-areas/<name>`、`POST .../<name>/widgets`、
  `PUT` / `DELETE .../<name>/widgets/<id>`、`POST .../<name>/reorder`
- **`repeater`フィールドの作成** — `schema_create_field`が受け付けない。
  `POST /_emdash/api/schema/collections/<collection>/fields`。本文の形と落とし穴は
  `building-emdash-site`の`references/schema-and-seed.md`「MCPで作れないフィールド、付けられない属性」

## PATでは通らないもの

- **`GET /_emdash/api/snapshot`はPATで401になる。** このルートは認証ミドルウェアの対象外で、自前で解決するのは
  セッションCookieとプレビュー署名だけ。バックアップが要るなら管理画面のSettings → Backupsか、D1から
  対象テーブルを退避する([`D1-SQL.md`](D1-SQL.md))

## 書いたのにサイトに出ない: `content_update`は下書き止まり

`supports`に`revisions`を持つコレクションでは、`content_update`は下書きリビジョンを作るだけで、公開中の
行(`ec_*`の列)は変わらない。CLIの`update`が自動公開するのと挙動が違う。

- 同じ呼び出しで公開するなら`status: "published"`を添える。後からなら`content_publish`
- 反映の確認はMCPの応答ではなくD1で行う: 対象行の`draft_revision_id IS NULL`と、書き換えた列の値
