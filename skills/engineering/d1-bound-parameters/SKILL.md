---
name: d1-bound-parameters
description: Cloudflare D1 へ多数の値を渡すクエリの規律 — bound parameter は1文あたり100個まで。`D1_ERROR: too many SQL variables` が出たとき、D1 へ大量の行を INSERT するとき、`inArray` / `IN (...)` に長い ID の列を渡すとき、`db.batch()` で分割するときに使う。
---

# D1 に多数の値を渡す

D1 は **1文あたりの bound parameter を 100 個まで** に制限する([D1 limits](https://developers.cloudflare.com/d1/platform/limits/))。SQLite の既定よりずっと小さいので、SQLite の感覚で書いたバルク INSERT や `IN (...)` は、行数が育った日に本番でだけ `D1_ERROR: too many SQL variables` で落ちる。

判断の順は1つに決まっている: **まず SQL の中に閉じ、閉じられないものだけを分割する。**

## 1. SQL の中に閉じる

bound parameter を消費するのは、JS が持っている値を SQL へ渡すときだけである。元データが DB の中にあるなら、JS へ持ち帰らない — 行数に依存しなくなり、分割そのものが要らなくなる。

- **読み取り** — 別のクエリで取った ID の列を `inArray(col, ids)` に渡さず、サブクエリを渡す: `inArray(col, db.select({ id: t.id }).from(t).where(...))`
- **書き込み** — `db.insert(t).select((qb) => ...)` の `INSERT ... SELECT` にする

**完了基準:** 値を JS から SQL へ渡しているすべての INSERT と `IN` について、元データが DB の中にあるものはサブクエリか `INSERT ... SELECT` に置き換わっている。

## 2. JS にしか無い値は分割して、1つの batch に入れる

ユーザー入力・Queue のメッセージ・外部 API の同期対象など、元データが JS 側にしか無いときだけ分割する。

**列数は、渡したキーの数ではなくテーブルの列数で数える。** Drizzle は INSERT で値を省いた列のうち、`.default(値)`・`$defaultFn` を持つものを `DEFAULT` キーワードではなく bound parameter として出す。`{ pollId, date }` の2キーしか渡していなくても、id・createdAt・updatedAt などが既定値を持っていれば文には7個並ぶ。1チャンクの行数は `Math.floor(100 / Object.keys(getTableColumns(table)).length)` で決めると安全側に倒れる。

分割したチャンクは **1つの `db.batch()` にまとめる**。

- 上限は batch の合計ではなく **batch 内の各文に個別に** かかる — 公式: "Limits for individual queries (listed above) apply to each individual statement contained within a batch statement"。100 以下に分けた文をいくつ並べても通る
- batch は1回の呼び出しで送られるので、チャンクを別々に `await` するより往復が少ない
- batch は SQL トランザクションである — 1文でも失敗すれば全体がロールバックされる。delete + insert の入れ替えのように原子性が要る組は、分割してもこの中に入れておく

1起動あたりのクエリ数の上限を根拠に設計するときは、2つのページを両方開く。D1 の limits ページは Free を 50 と書くが、Workers の [subrequest limits](https://developers.cloudflare.com/workers/platform/limits/) は D1 を含む内部サービスへの subrequest を Free で 1,000 としており、食い違っている。

**完了基準:** 残った分割はすべてテーブルの列数から行数を決めていて、bound parameter が 100 を超える文が1つも無い。
