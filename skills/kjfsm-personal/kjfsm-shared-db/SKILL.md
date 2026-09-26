---
name: kjfsm-shared-db
description: kjfsm のアプリが相乗りする共有 D1(`kjfsm-shared-db`)に入る・その中でスキーマを変える規律。kjfsm の新しいサービスに D1 が要るとき(`wrangler d1 create` を叩く前)、`wrangler.jsonc` が `kjfsm-shared-db` を bind しているリポジトリでマイグレーションを生成・適用するとき、共有 D1 からサービスを抜くときに使う。
---

# kjfsm-shared-db に相乗りする

D1 の Free 枠(アカウントあたり 10 個)は使い切っている。**kjfsm の新しいサービスは D1 を作らず、共有 D1 `kjfsm-shared-db` に相乗りする。** リポジトリは分けたまま、各 Worker が同じ `database_id` を bind する。

なぜこの形か・何を代償にしたかの一次情報源は `~/github/kjfsm/circle-scheduler/docs/adr/0025-services-share-one-d1-and-prefix-only-where-names-collide.md`。ここに無い判断に迫られたら、そこを開く。**ただし ADR の「認証の4テーブルは IdP に寄せれば各アプリから消え、prefix は過渡的な措置」は実態と違う** — better-auth の RP は4テーブルを自分の D1 に持ち続ける(live-note・pensieve)。prefix は恒久の規約として扱う。参考例は `~/github/kjfsm/live-note`(prefix `livenote_`)。

**共有 D1 の中では、自分のサービスの外にあるものは全部他人のものである。** 以下の規律はすべてこの1文から出ている。

## 相乗りしないもの

- **kjfsm-auth(IdP)。** bind した Worker は DB の全テーブルを読めるので、共有した時点で「アプリが漏れても IdP は漏れない」が消える
- **circle・euphotter のような主力、重いクエリを流すもの。** D1 は DB ごとにシングルスレッドで、キューが溢れると **無関係なサービスに `overloaded` が返る**。同時接続の上限 6 も共有する。相乗りしてよいのは、軽く、頻度が低く、道連れになって構わないものだけ

日次のクエリ上限(読み取り 5M・書き込み 10 万、UTC 0 時リセット)は **アカウント単位** なので、共有してもしなくても同じ枠を分け合う。相乗りの可否ではなく、クエリの重さの見積もりに効く

どちらかに当たるなら、専用の D1 を作れるか(枠を空けるか Workers Paid か)を人間に確かめる。**覆る条件**: Workers Paid に上げたなら、そもそも共有をやめて専用の D1 を作る。

## 入る

### 1. 名前を2つ決め、空いていることを確かめる

- **テーブル prefix**: `<slug>_`(例 `livenote_`)。**新しいサービスは全テーブルとインデックスに最初から付ける** — インデックス名も DB 内でグローバルである。better-auth の `user` / `session` / `account` / `verification` は素の名前のままだと次のサービスと確実に衝突する
- **マイグレーション履歴のテーブル**: `d1_migrations_<slug>`

```sh
pnpm exec wrangler d1 execute kjfsm-shared-db --remote --command \
  "select name from sqlite_master where type in ('table','index') and (name like '<slug>\_%' escape '\' or name = 'd1_migrations_<slug>')"
```

本番への読み取りなので、叩く前に人間に一声かける。

完了基準: 上のクエリが 0 行を返した。

### 2. bind する

```jsonc
// kjfsm group。共有 D1 はこのアカウントにあるので、既定のアカウント選びに任せない。
"account_id": "<kjfsm group のアカウント ID>",
// 履歴を他のサービスと分けるため migrations_table を必ず指定する。
"d1_databases": [
  {
    "binding": "DB",
    "database_name": "kjfsm-shared-db",
    "database_id": "<kjfsm-shared-db の UUID>",
    "migrations_dir": "drizzle/migrations",
    "migrations_table": "d1_migrations_<slug>",
  },
],
```

2つの ID はこのファイルに書かない(公開リポジトリである)。既に相乗りしているリポジトリの `wrangler.jsonc` から写す — `account_id` は `~/github/kjfsm/pensieve/wrangler.jsonc`、`database_id` は `~/github/kjfsm/live-note/wrangler.jsonc`。

**`migrations_table` が要である。** これが無いと既定の `d1_migrations` を全サービスで取り合い、他のサービスが同じファイル名を適用済みなら、自分のマイグレーションが黙って飛ばされる。サービスごとに分かれることの根拠は wrangler の実装であって公式ドキュメントではない(ADR 0025)ので、wrangler を大きく上げたら `wrangler d1 migrations list kjfsm-shared-db --remote` が自分のファイルだけを見ていることを確かめ直す。

### 3. スキーマに prefix を付け、`push` を塞ぐ

drizzle では、テーブル名だけに prefix を付けて export 名は素のままにする — better-auth の `drizzleAdapter` はスキーマの **キー** でモデルを引くので、アダプタ側の設定は要らない。

```ts
// 共有 D1(kjfsm-shared-db)に相乗りするので、テーブルとインデックスには必ず `<slug>_` を付ける。
export const user = sqliteTable("<slug>_user", { ... });
export const session = sqliteTable("<slug>_session", { ... },
  (t) => [index("<slug>_session_user_id_idx").on(t.userId)]);
```

**`drizzle-kit push` は他のサービスのテーブルを消す** — DB 全体を見て、スキーマに無いテーブルを削除対象にする。生成は `drizzle-kit generate`(スナップショット比較で DB を見ない)、適用は `wrangler d1 migrations apply` に限る。散文では守りきれないので、`.claude/settings.json` の `permissions.deny` に `"Bash(*drizzle-kit push*)"` を足す — 先頭もワイルドカードにするのは `pnpm exec` や `npx` を前置した呼び出しまで塞ぐためである。`package.json` に `push` を叩くスクリプトは作らない(スクリプト名の経由はこの規則をすり抜ける)。`drizzle.config.ts` にも1行残す。

```ts
// `drizzle-kit push` は使わない。共有 D1 にある他のサービスのテーブルを消す。
```

`package.json` のスクリプトは DB 名で書く。

```json
"db:generate": "drizzle-kit generate",
"db:migrate:local": "wrangler d1 migrations apply kjfsm-shared-db --local",
"db:migrate:remote": "wrangler d1 migrations apply kjfsm-shared-db --remote"
```

完了基準: 生成された最初のマイグレーションの `CREATE TABLE` と `CREATE INDEX` が全部 `<slug>_` で始まる(`grep -E 'CREATE (TABLE|INDEX|UNIQUE INDEX)' drizzle/migrations/*.sql` で prefix の無い行が 0)。

## スキーマを変える

手元(`--local`)は `.wrangler/state` のリポジトリごとの SQLite で、共有されていない。**共有されているのは `--remote` だけである。**

- **`--remote` の適用は人間の確認を取ってから。** Workers Builds のデプロイコマンドを `pnpm db:migrate:remote && wrangler deploy` にしているなら、**マージした時点で本番の共有 D1 に当たる** — マイグレーションを含む PR はマージの前に SQL を読む
- **生成された SQL が自分の prefix の外に触れていないか読む。** `DROP` / `ALTER` / `DELETE` / `UPDATE` の対象がすべて `<slug>_` で始まること
- **テーブルの作り直し(`PRAGMA foreign_keys=OFF` と `DROP TABLE`)が出たら `/kjfsm-skills:migrate-d1`。** D1 ではその PRAGMA が効かず、参照している側が空になる
- **適用済みのマイグレーションは書き換えない・消さない・改名しない。** wrangler は適用済みをファイル名で照合する。検査を CI に置く例は live-note の `scripts/check-migrations.mjs`
- **`wrangler d1 execute --remote` で DDL を手打ちしない。** 履歴に残らず、次のサービスが読めない

`--remote` を当てる直前に、戻り先と比較の基準を控える(pensieve の `docs/setup.md` の手順)。

```sh
pnpm exec wrangler d1 time-travel info kjfsm-shared-db   # 戻り先の bookmark
pnpm exec wrangler d1 execute kjfsm-shared-db --remote --command \
  "select type, name, sql from sqlite_master where tbl_name not like '<slug>\_%' escape '\' and tbl_name != 'd1_migrations_<slug>' order by name" --json | jq '.[0].results' > before.json
```

`name` ではなく `tbl_name` で絞る。`name` だと、SQLite が自分のテーブルに付ける自動インデックス(`sqlite_autoindex_<slug>_…`)が外側に数えられ、適用後の diff に出る。

完了基準: 適用前に、生成された SQL の全文を読み、触れるテーブルが全部 `<slug>_` で始まると言える。適用後に同じクエリを取り直し、`before.json` と `diff` して差分が無い(自分の prefix の外が1つも変わっていない)。

## 壊したとき

**Time Travel は DB 単位でしか戻せない。** 巻き戻すと、同じ時間に書かれた **他のサービスのデータも一緒に消える。** 自分のテーブルだけを直すなら、前向きのマイグレーションか、自分の `<slug>_` テーブルだけを `wrangler d1 export kjfsm-shared-db --remote --table <slug>_...` で取り出して戻す。Time Travel を使うのは、相乗りしている全サービスの持ち主(=人間)が合意したときだけ。

## 抜ける

サービスを畳むときは、自分の `<slug>_` テーブル・インデックスと `d1_migrations_<slug>` を消す。残すと、次に同じ slug を選んだサービスが手順1で止まる — 止まれば良い方で、止まらなければ古い履歴を自分のものとして読む。消す前に一覧を人間に見せる。
