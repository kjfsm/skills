# 本番のD1から`seed.json`を作り直す

`seed/seed.json`を本番のスキーマへ揃え直すときに開く。公式の
[deployment/schema-evolution](https://docs.emdashcms.com/deployment/schema-evolution/)は次を載せている:

```bash
npx wrangler d1 export <db> --remote --output=./prod.sql
sqlite3 prod.db < prod.sql
npx emdash export-seed --database prod.db
```

## 1行目が通らない

EmDashは全文検索にFTS5の仮想テーブル(`_emdash_fts_<collection>`とそのshadowテーブル)を作るので、
`wrangler d1 export`は`D1 Export error: cannot export databases with Virtual Tables (fts5)`で落ちる
(観測)。`--table`で絞る手もあるが、exportは実行中のDBを一時的にクエリ不能にすると警告しているので、
本番では読み取りクエリだけで組み立てる。

## 読み取りだけで組み立てる

`sqlite3` CLIは要らない —— Node 22以降の`node:sqlite`(`DatabaseSync`)で足りる。

1. `sqlite_master`から`type='table'`だけでCREATE文を取る(FTSのトリガーは付いてこない)。
   `export-seed`が読むのは`options` / `_emdash_collections` / `_emdash_fields` / `_emdash_taxonomy_defs` /
   `taxonomies` / `_emdash_menus` / `_emdash_menu_items` / `_emdash_widget_areas` / `_emdash_widgets` /
   `_emdash_bylines`系 / `_emdash_seo` / `content_taxonomies` / `_emdash_content_bylines`。
   **`_emdash_migrations`と`_emdash_migrations_lock`も必ず入れる** —— `export-seed`は起動時に
   マイグレーションを走らせるので、これが無いと既存テーブルを作り直そうとして
   `table "_emdash_collections" already exists`で落ちる
2. 各テーブルを`SELECT *`で吸い出す。`wrangler d1 execute --file`に複数のSELECTを並べても結果セットは
   1つしか返らない(観測)ので、テーブルごとに`--command`で1回ずつ叩く
3. `node:sqlite`でCREATEとINSERTを流す(`PRAGMA foreign_keys = OFF`)。`ec_*`は作らなくてよい
4. `npx emdash export-seed --database <組み立てたDB>`

## 出力はそのまま採用しない

差分を読んで、要る分だけ手で`seed.json`へ取り込む。

| 取りこぼし   | 中身                                                                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| 先頭のログ行 | `ℹ Database: ...`が標準出力に出るので、`> seed.json`するとJSONとして読めない。`{`以降を切り出す                                                  |
| `has_seo`    | `supports`列の生値しか書き出さない。`has_seo = 1`でも`supports`に`"seo"`が無いコレクションはSEOを失う。シードでは`supports`に`"seo"`を書いて表す |
| 本番のID     | `settings`は生値のままなので、ロゴ・favicon・既定OG画像に本番の`mediaId`が入る。メニュー項目の`ref`も本番エントリのULIDになる                    |
| `meta`       | `"Exported Seed"`で上書きされる                                                                                                                  |

`routable: false`は正しく書き出される。

## 検証

空のDBに適用して本番と突き合わせる:

```bash
npx emdash seed seed/seed.json --database /tmp/verify.db --uploads-dir /tmp/uploads
```

`_emdash_collections`の`supports` / `has_seo` / `routable` / `url_pattern` / `hidden` / `title_field` /
`date_field`を本番と比べる。
