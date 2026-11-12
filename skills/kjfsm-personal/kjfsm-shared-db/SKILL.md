---
name: kjfsm-shared-db
description: 共有 D1(`kjfsm-shared-db`)にすでに相乗りしているリポジトリで、スキーマを変える・共有 D1 から抜けるときの規律。`wrangler.jsonc` が `kjfsm-shared-db` を bind しているリポジトリでマイグレーションを生成・適用するとき、そこで `drizzle-kit push` を叩きそうになったとき、共有 D1 のサービスを専用の D1 へ移す・畳むときに使う。新しいサービスは共有 D1 に入れない(専用の D1 を作る)。
---

# 共有 D1 に相乗りしているリポジトリでスキーマを変える・抜ける

**新しいサービスは共有 D1 に入れない。`wrangler d1 create` で専用の D1 を作る。** 相乗りには、どのプランでも変わらない代償がある。

- bind した Worker は、同じ DB にある他のサービスの全テーブルを読める
- D1 は DB ごとにシングルスレッドで、キューが溢れると **無関係なサービスに `overloaded` が返る**
- Time Travel は DB 単位でしか戻せず、巻き戻すと他のサービスのデータも消える
- `drizzle-kit push` は、スキーマに無い他のサービスのテーブルを削除対象にする

このスキルが扱うのは、`wrangler.jsonc` がもう `kjfsm-shared-db` を bind しているリポジトリだけである。今の形(全テーブルに `<slug>_`、サービスごとの `migrations_table`)を決めた一次情報源は `~/github/kjfsm/circle-scheduler/docs/adr/0025-services-share-one-d1-and-prefix-every-table.md`。参考例は `~/github/kjfsm/live-note`(prefix `livenote_`)。

**共有 D1 の中では、自分のサービスの外にあるものは全部他人のものである。** 以下の規律はすべてこの1文から出ている。

## スキーマを変える

手元(`--local`)は `.wrangler/state` のリポジトリごとの SQLite で、共有されていない。**共有されているのは `--remote` だけである。**

- **新しいテーブルとインデックスにも `<slug>_` を付ける。** インデックス名も DB 内でグローバルである。drizzle ではテーブル名だけに付けて export 名は素のままにする — better-auth の `drizzleAdapter` はスキーマの **キー** でモデルを引くので、アダプタ側の設定は要らない
- **`wrangler.jsonc` の `migrations_table`(`d1_migrations_<slug>`)を消さない・変えない。** 無いと既定の `d1_migrations` を全サービスで取り合い、他のサービスが同じファイル名を適用済みなら、自分のマイグレーションが黙って飛ばされる。サービスごとに分かれる根拠は wrangler の実装であって公式ドキュメントではない(ADR 0025)ので、wrangler を大きく上げたら `wrangler d1 migrations list kjfsm-shared-db --remote` が自分のファイルだけを見ていることを確かめ直す
- **生成は `drizzle-kit generate`、適用は `wrangler d1 migrations apply` に限る。** `push` は散文では守りきれないので、`.claude/settings.json` の `permissions.deny` に `"Bash(*drizzle-kit push*)"` があることを確かめる — 先頭もワイルドカードにするのは `pnpm exec` や `npx` を前置した呼び出しまで塞ぐためである。`package.json` に `push` を叩くスクリプトを作らない(スクリプト名の経由はこの規則をすり抜ける)
- **`--remote` の適用は人間の確認を取ってから。** Workers Builds のデプロイコマンドを `pnpm db:migrate:remote && wrangler deploy` にしているなら、**マージした時点で本番の共有 D1 に当たる** — マイグレーションを含む PR はマージの前に SQL を読む
- **生成された SQL が自分の prefix の外に触れていないか読む。** `CREATE` / `DROP` / `ALTER` / `DELETE` / `UPDATE` の対象がすべて `<slug>_` で始まること(`grep -E 'CREATE (TABLE|INDEX|UNIQUE INDEX)' drizzle/migrations/*.sql` で prefix の無い行が 0)
- **テーブルの作り直し(`PRAGMA foreign_keys=OFF` と `DROP TABLE`)が出たら `/kjfsm-skills:migrate-d1`。** D1 ではその PRAGMA が効かず、参照している側が空になる
- **適用済みのマイグレーションは書き換えない・消さない・改名しない。** wrangler は適用済みをファイル名で照合する。検査を CI に置く例は live-note の `scripts/check-migrations.mjs`
- **`wrangler d1 execute --remote` で DDL を手打ちしない。** 履歴に残らず、次の人が読めない

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

どれも本番の共有 D1 に触る。始める前に、この節の手順と、対象のテーブルの一覧(`<slug>_` の表・インデックスと `d1_migrations_<slug>`)をユーザーに見せ、まとめて確認を取る。

**`wrangler d1 export --remote` は、終わるまで DB をロックする**(公式の D1 のデバッグの節)。共有 D1 では、相乗りしている他のサービスもその間止まる。export は書き込みの少ない時間に行い、そのことも確認に含める。

### 専用の D1 へ移す

1. **専用の D1 を作る。** `CLOUDFLARE_ACCOUNT_ID` を付けて `pnpm exec wrangler d1 create <名前>`。出力の `database_id` を控える
2. **自分のテーブルを取り出す。** 対象は `select name from sqlite_master where type = 'table' and (name like '<slug>\_%' escape '\' or name = 'd1_migrations_<slug>')` を共有 D1 に `--remote` で引いて列挙する — 漏れたテーブルは移した先に無いまま、6 で消える。`pnpm exec wrangler d1 export kjfsm-shared-db --remote --output shared.sql --table <slug>_a --table <slug>_b … --table d1_migrations_<slug>`。**`d1_migrations_<slug>` も一緒に取り出す** — 移した先の履歴が空だと、`migrations apply` が最初のファイルから当て直し、既にあるテーブルで落ちる。**`--table` を付けた export はインデックスを含まない**(wrangler 4.156 で確かめた)ので、`select sql from sqlite_master where type = 'index' and tbl_name like '<slug>\_%' escape '\' and sql is not null` の結果を `indexes.sql` に控える
3. **専用の D1 に入れる。** `pnpm exec wrangler d1 execute <名前> --remote --file shared.sql`、続けて `--file indexes.sql`。テーブルごとの行数と、インデックスの数を元と比べる
4. **`wrangler.jsonc` の `database_name` と `database_id` を替える。** `env` ごとに `d1_databases` を持っているなら、その全部を替える。`migrations_table` は `d1_migrations_<slug>` のまま残す(2 で運んだ履歴がその名前にある)。`package.json` の `db:migrate:*` の DB 名を替え、`wrangler types` で型を作り直す。`database_id` を替えると手元(`--local`)の D1 も別物になるので、`pnpm db:migrate:local` をやり直す。prefix は残してよい — 外すのはスキーマとマイグレーションの作り直しになる
5. **切り替えをデプロイする。** 2 の取り出しからこのデプロイまでの間に共有 D1 へ入った書き込みは、新しい D1 に入らない。アプリに書き込みを止める仕組み(メンテナンス表示・読み取り専用)があれば止めてから、無ければ書き込みの少ない時間を選び、2〜5 を続けて行う
6. **新しい D1 で動くことを見てから、共有 D1 の自分の分を消す**(次の「畳む」)

### 畳む

自分の `<slug>_` テーブル・インデックスと `d1_migrations_<slug>` を消す。残すと、誰も使わなくなったデータが、共有 D1 を bind している他の Worker から読めるまま残る。

bind を外したあとはマイグレーションで消せないので、ここだけは「DDL を手打ちしない」の例外として `wrangler d1 execute --remote` で消す。ユーザーの許可を取ってから、次の順で行う。

1. 消す一覧を `sqlite_master` から引いて見せる(手順 2 のクエリ)
2. 残す控えを取る: 一覧の export と、`pnpm exec wrangler d1 time-travel info kjfsm-shared-db` の bookmark
3. 子(参照している側)のテーブルから先に消す。親を先に `DROP` すると、参照している行が暗黙に `DELETE` される(`/kjfsm-skills:migrate-d1`)

   ```sh
   pnpm exec wrangler d1 execute kjfsm-shared-db --remote --command \
     "DROP TABLE <slug>_child; DROP TABLE <slug>_parent; DROP TABLE d1_migrations_<slug>;"
   ```

   テーブルを消すとそのインデックスも消える。

4. 手順 1 のクエリを取り直し、0 行になったことを確かめる
