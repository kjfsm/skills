---
name: migrate-d1
description: Cloudflare D1 のスキーマを変えるときの規律。drizzle-kit などが `PRAGMA foreign_keys=OFF` と `DROP TABLE` を含むマイグレーションを生成したとき、列を NOT NULL にしたいとき、CHECK 制約や複合ユニークを足したいとき、本番に `--remote` でマイグレーションを当てる前に使う。**D1 では `PRAGMA foreign_keys=OFF` が効かないので、生成物をそのまま流すと参照している側のテーブルが空になる。**
---

# D1 のスキーマを移行する

SQLite は列の制約を後から変えられないので、`NOT NULL` 化・`CHECK` の追加・型変更はどれもテーブルの作り直しになる。マイグレーションの生成器はそのための SQL を出すが、**その SQL は D1 では安全でない。**

## 生成器が出すもの

```sql
PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_member` ( ... );--> statement-breakpoint
INSERT INTO `__new_member`(...) SELECT ... FROM `member`;--> statement-breakpoint
DROP TABLE `member`;--> statement-breakpoint
ALTER TABLE `__new_member` RENAME TO `member`;--> statement-breakpoint
PRAGMA foreign_keys=ON;
```

`member` を参照する表が `ON DELETE CASCADE` を持っていると、**4行目でその表のデータが消える。** 1行目がそれを防ぐはずだが、D1 では防がない。

## なぜ効かないか

SQLite の仕様である。

> **This pragma is a no-op within a transaction** — [PRAGMA foreign_keys](https://www.sqlite.org/pragma.html#pragma_foreign_keys)

D1 は必ず暗黙のトランザクションを張る。Cloudflare 自身が「D1 runs queries within implicit transactions, **preventing users from toggling `PRAGMA foreign_keys` directly**」と書いている([Foreign keys](https://developers.cloudflare.com/d1/sql-api/foreign-keys/))。**この1行は D1 では一度も効かない。**

`--> statement-breakpoint` は関係ない。`--` 始まりなので SQLite にはただの行コメントで、`wrangler d1 migrations apply` は**1ファイルを1つの文字列にまとめて1回の API 呼び出しで送る**。つまり1ファイル = 1トランザクションであり、途中で落ちれば全部ロールバックされる。

## `defer_foreign_keys` でも止まらない

Cloudflare のマイグレーション文書は `PRAGMA defer_foreign_keys = true` を案内するが、**この用途には効かない。**

遅延されるのは制約**違反の検査**であって、`ON DELETE CASCADE` は**アクション**である。`DROP TABLE` は「performs an implicit DELETE … **may invoke foreign key actions**」([Foreign Keys §5](https://www.sqlite.org/foreignkeys.html))。検査を後回しにしても、削除そのものは起きる。

生成そのものが `Interactive prompts require a TTY terminal` で止まるなら、それは別の問題である — `drizzle-generate-non-interactive` スキルを呼ぶ。**既定でハイライトされているのは `create`、つまりデータが消える側**なので、rename を create として通すとここで扱う CASCADE より手前で列ごと失う。

## 判定

**その表を参照している `ON DELETE CASCADE` / `SET NULL` の外部キーがあるか。**

```sh
git grep -n "references(() => <表>" -- '*/schema/*'
```

無ければ生成物をそのまま流してよい。**あるなら以下の手順で書き直す。**

索引や複合ユニークを足すだけなら再構築は要らない — `CREATE INDEX` / `CREATE UNIQUE INDEX` 単体で足りる。生成器が再構築を出してきても、**目的が索引だけなら書き直して捨てる。**

## 子退避レシピ

消える側を先に別表へ写し、再構築のあとで戻す。

```sql
-- D1 では PRAGMA foreign_keys=OFF が no-op で、defer_foreign_keys も cascade を
-- 止めない。DROP TABLE で消える子を退避して戻す。
PRAGMA defer_foreign_keys=on;--> statement-breakpoint
CREATE TABLE `__bak_post` AS SELECT * FROM `post`;--> statement-breakpoint
CREATE TABLE `__bak_favorite` AS SELECT * FROM `favorite`;--> statement-breakpoint

-- ここから生成物のまま。ただし PRAGMA foreign_keys の2行は消す
CREATE TABLE `__new_member` ( ... );--> statement-breakpoint
INSERT INTO `__new_member`(...) SELECT ... FROM `member`;--> statement-breakpoint
DROP TABLE `member`;--> statement-breakpoint
ALTER TABLE `__new_member` RENAME TO `member`;--> statement-breakpoint
CREATE INDEX ... ;--> statement-breakpoint

-- 戻す。親から子の順に
DELETE FROM `post`;--> statement-breakpoint
INSERT INTO `post` (`id`, `organization_id`, ...) SELECT `id`, `organization_id`, ... FROM `__bak_post`;--> statement-breakpoint
DELETE FROM `favorite`;--> statement-breakpoint
INSERT INTO `favorite` (...) SELECT ... FROM `__bak_favorite`;--> statement-breakpoint
DROP TABLE `__bak_post`;--> statement-breakpoint
DROP TABLE `__bak_favorite`;
```

- **孫まで追う。** `member` を消すと `post` が消え、`post` が消えると `post_revision` が消える。退避が要るのは直接の子だけではない
- **復元の `INSERT` は列名を明示する。** `SELECT *` でも通るが、あとで列が増えた日に黙って壊れる
- **索引の再作成は `RENAME TO` の直後に置く。** 再構築で消えている
- 1ファイル1トランザクションなので、**途中で落ちれば何も適用されない**

## 先に旧表をリネームする形は採らない

「`ALTER TABLE x RENAME TO x_old` してから新表を作る」は SQLite 公式が明示的に退けている:

> the initial rename of the table to a temporary name might **corrupt references to that table in triggers, views, and foreign key constraints** — [ALTER TABLE](https://www.sqlite.org/lang_altertable.html)

実際に他の表の `REFERENCES` 句が `x_old` を指すように書き換わる。`PRAGMA legacy_alter_table=ON` でも止まらない。

## 本番に当てる前に

1. **復元点を控える。** `wrangler d1 time-travel info <db>` の bookmark を記録する。Time Travel は有料 30 日・無料 7 日で、**fork や clone はできない**(戻すことしかできない)
2. **本番データでリハーサルする。** `wrangler d1 export <db> --remote --output=dump.sql` を取り、まっさらなローカル D1 へ流してからマイグレーションを当てる。ダンプには `d1_migrations` も入るので、追跡状態ごと本番と同じものが手元にできる。**退避した表の件数を前後で数える** — 画面には出ないので、数える以外に気づく方法が無い
3. **デプロイより先にマイグレーションを当てる。** 新しいコードが古いスキーマを読むより、古いコードが新しいスキーマを読むほうが壊れ方が浅い

事故が起きたら `wrangler d1 time-travel restore <db> --bookmark=<控えた値>` で戻す。restore すると `d1_migrations` も巻き戻るので、直したマイグレーションを流し直せる。**restore の前に現在の状態を `export` しておく** — 巻き戻すと、事故のあとに書き込まれた分が消える。

## 再発を止める

判定は毎回できるとは限らない。生成物をコミットする瞬間に止めるフックを置く。

```sh
# .claude/hooks/block-generated-migration-cascade.sh
# PRAGMA foreign_keys=OFF と DROP TABLE が同居するマイグレーションを弾く
for f in $(git diff --cached --name-only --diff-filter=A | grep 'migrations/.*\.sql$'); do
  if grep -q 'PRAGMA foreign_keys=OFF' "$f" && grep -q 'DROP TABLE' "$f"; then
    echo "$f: 生成物のまま。子退避レシピで書き直す(→ migrate-d1)" >&2
    exit 2
  fi
done
```

**これが唯一の決定的な防止策である。** 手順を文書に書いても、生成器は次も同じ SQL を出す。
