---
name: squash-d1-migrations
description: 積み上がった D1 のマイグレーションを1本に畳み、適用済みの各環境と突き合わせる。
disable-model-invocation: true
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/d1-fingerprint.py *)
---

# D1 のマイグレーションを squash する

**squash はファイルをまとめる作業ではない。適用済みの DB が覚えている履歴を書き換える作業である。** wrangler は適用したマイグレーションの **名前** を `d1_migrations` に記録する — [d1]。ファイル名を差し替えた瞬間、既存の DB から見れば「未適用のマイグレーションが1本現れた」ことになり、次の apply がそれを実行して `table ... already exists` で落ちる。

だから合格条件は「ファイルが減ったか」ではなく1つだけである: **空の DB に適用した結果が、旧チェーンを適用した結果と一致するか。**

`drizzle-kit` に squash コマンドは無い。取れる形は **全削除 → 再生成** だけである。

## 始める前に止まる条件

1つでも真なら、squash しない。

- **未適用のマイグレーションを持つ環境がある。** squash は全環境が同じ地点にいることを前提にする。local / preview / production のそれぞれで `wrangler d1 migrations apply <db> --dry-run` を実行し、**すべてが「未適用なし」** になるまで進まない
- **その DB に対して自分が書き込み権限を持っていない。** 「各環境の `d1_migrations` を突き合わせる」は各環境の DB を書き換える。書き換えられない環境が残るなら、その環境は次の apply で壊れる
- **畳もうとしている範囲に、まだ意味のある履歴がある。** 「どの列がいつ入ったか」を git log ではなくマイグレーションの並びで読んでいるなら、それは畳んだ瞬間に失われる

## 手順

### 1. 本番を手元に再現する

**squash が保存しようとしている相手は、マイグレーションの並びではなく本番の DB そのものである。** 本番が手で当てた `ALTER` や途中で失敗したマイグレーションでずれていれば、そのずれは squash が固定化する — そして後続の手順はチェーンどうしを比べるだけなので、ずれには一生気づかない。

まず本番の実スキーマを取る。

```
wrangler d1 export <db> --remote --no-data --output /tmp/prod-schema.sql
```

つぎにフルダンプを取り、まっさらなローカル D1 へ流し込む。

```
wrangler d1 export <db> --remote --output /tmp/prod-full.sql
wrangler d1 execute <db> --local --file /tmp/prod-full.sql
```

**ダンプには `d1_migrations` も含まれる。** つまり手元に、本番と同じスキーマ・同じデータ・**同じ追跡状態** の DB ができる。「各環境の `d1_migrations` を突き合わせる」は、本番に触る前にここで一度通す。

`d1 export` は `--persist-to` を受け付けない — 既定の `.wrangler` を読み書きする(実測)。

**完了基準: 本番のスキーマが手元にあり、旧チェーンを空 DB へ流した結果と突き合わせて、説明のつかない差が無いこと。** 差があるなら、それは squash の問題ではない。先にそれを片付ける。

### 2. 消えるものを数え、シードとバックフィルに分ける

**`generate` が再生成できるのは DDL だけである。** `ALTER TABLE users ADD email text` はスキーマ定義の言い換えにすぎないので同じものが出る。DML(`INSERT` / `UPDATE` / `DELETE`)は **その時点の DB に何が入っていたか** の話であってスキーマの形ではないため、スキーマのどこを読んでも復元できない。畳めば消える。

```
grep -liE '^\s*(UPDATE|INSERT|DELETE)\b' <migrations_dir>/*.sql
```

出たファイルを2つに分ける。**分類が決定を決める。**

- **バックフィル** — 既存の行を直す `UPDATE` / `DELETE`(「NOT NULL 化の前に NULL を埋める」など)。**空の DB では対象行が無く、実行しても何も起きない。** 畳んで消しても損失は無い
- **シード** — 行そのものを入れる `INSERT`(初期ロール、既定の権限、マスタデータ)。**消えると、squash 後に作った環境だけがその行を持たない DB になる。** 本番は既に持っているので気づかず、テーブルはあるのに中身が違うという最も見つけにくいずれになる

シードが1件でもあるなら、**扱いを決めるまで先へ進まない。**

- **squash の範囲から外す** — そのファイルより手前だけを畳む。いちばん安全
- **書き直して残す** — 畳んだ init の後ろに独立したマイグレーションとして置き直す。**元のファイルをそのまま持ち越さない** — 当時のスキーマに対して書かれているので、畳んだ後の最終スキーマでは動かないことがある
- **捨てる** — そのデータが本番にしか無く、新しい環境では要らないと **確認できた** ときだけ

**完了基準: 該当ファイルを一覧し、1つずつシードかバックフィルかを言い、シードの扱いを決めたこと。**

### 3. 旧チェーンの指紋を取る

畳む前の姿を記録する。これが後で比べる相手になる。

```
python3 ${CLAUDE_SKILL_DIR}/scripts/d1-fingerprint.py \
  --database <database_name> --state /tmp/fp-before > /tmp/fp-before.txt
```

使い捨てのローカル D1 に旧チェーンを流し、スキーマオブジェクトと各テーブルの行数を出す。引用符と句読点の空白は正規化される — drizzle-kit はバッククォート付きの DDL を書き、手書きの SQL は書かないので、そこは差分として読まない。**列の並びは正規化しない**(意味を持つ差分だからである。「差分を1行ずつ分類する」を見よ)。

**完了基準: 出力が空でなく、テーブル数が実際のスキーマと一致していること。**

### 4. 全削除 → 再生成

```
rm -rf <migrations_dir>
npx drizzle-kit generate --name init
```

**`meta/` ごと消す。** SQL ファイルだけ消してスナップショットを残すと、再生成が「差分なし」と判断して何も出ない。`generate` は SQL と `meta/`(スナップショット + `_journal.json`)の両方を作り直す。

`drizzle-kit export` は現在のスキーマの DDL を吐くが `meta/` を作らない — [ke]。畳んだ後も `generate` を使い続けるなら、この経路は選ばない。

**完了基準: `<migrations_dir>` に SQL が1本と、`meta/` に対応するスナップショット1つだけがあること。**

### 5. 新チェーンの指紋を取り、差分を1行ずつ分類する

```
python3 ${CLAUDE_SKILL_DIR}/scripts/d1-fingerprint.py \
  --database <database_name> --state /tmp/fp-after > /tmp/fp-after.txt
diff /tmp/fp-before.txt /tmp/fp-after.txt
```

**差分ゼロにはならない。** 再生成された DDL は元の履歴と次の点で必ずずれる:

- **列の並び** — `ALTER TABLE ADD COLUMN` で足した列は末尾にあるが、再生成すると宣言順に入る
- **型の表記** — 手書きの `TEXT` が `text` になる
- **制約の順序** — `INTEGER NOT NULL DEFAULT 0` が `integer DEFAULT 0 NOT NULL` になる

これらは SQLite では等価である。**問題は等価でない差分が同じリストに紛れることで、見分けるのは人間しかいない。** 消えたインデックス、変わった `NOT NULL`、消えたテーブル、`rows` 行の数値の変化 — これらは squash が壊した証拠である。

**完了基準: 差分の全行を読み、1行ずつ「無害である理由」を言えること。「たぶん大丈夫」で通さない。**

### 6. 各環境の `d1_migrations` を突き合わせる

畳んだ結果を、すでに適用済みの各 DB に「適用済み」として教える。

```
wrangler d1 execute <db> --remote --command \
  "DELETE FROM d1_migrations; INSERT INTO d1_migrations (name) VALUES ('<新しいファイル名>');"
```

**名前は wrangler が記録するのと完全に同じ文字列にする。** 既定は `migrations_dir` 直下のファイル名で、**拡張子 `.sql` を含む**。`migrations_pattern` を使っているなら `migrations_dir` からの相対パス(`0001_init/migration.sql` など)になる — [d1]。

**1文字でも違えば未適用扱いになり、次の apply が `table ... already exists` で落ちる。** 拡張子の脱落がいちばん多い。

書き換えたら、その環境で確かめる:

```
wrangler d1 migrations apply <db> --remote --dry-run
```

**完了基準: 始める前に数え上げたすべての環境で「未適用なし」が出ること。1つでも残っていれば、その環境は次のデプロイで壊れる。**

## 気をつけること

- **`DELETE FROM d1_migrations` の前に中身を控える。** `--remote` に対する DELETE は取り消せない。`SELECT * FROM d1_migrations` の出力を手元に保存してから実行する
- **リセットとデプロイの順序を決めてから始める。** squash した変更がマージされ、CI/CD が `migrations apply` を走らせると、リセット前なら `already exists` で落ちる。「マージ → リセット」なら一度落ちる前提で、「リセット → マージ」なら畳む前のチェーンが未適用扱いになる前提で組む。どちらを取るにせよ、**落ちる窓を無人にしない**
- **壊れない環境ほど危ない。** 既存の DB は `already exists` で派手に落ちるので必ず気づく。fresh な環境(E2E、CI、新しい preview)は畳んだ init が普通に通るので **何も起きない** — シードが消えていても、そこで初めて気づくことはない。「シードとバックフィルに分ける」を飛ばした代償はこちら側に出る
- **環境を数え上げてから始める。** local / preview / production だけとは限らない。E2E が作る使い捨ての DB、`wrangler.*.toml` を分けた別環境、他人の手元。`d1_migrations` を書き換えられない環境が1つでも残るなら、そこは次の apply で止まる
- **`d1_migrations` という名前を決め打ちしない。** `migrations_table` で変更できる — [d1]。wrangler 設定を読んでから SQL を書く
- **畳んだ結果を1度は本番以外の実環境に当てる。** ローカルのリハーサルは `--local` の SQLite であって D1 ではない。preview があるなら、本番の前にそこを通す

## 参照

| キー | ソース                           | 何が書いてあるか                                                              |
| ---- | -------------------------------- | ----------------------------------------------------------------------------- |
| `d1` | [Cloudflare D1 — Migrations][d1] | `d1_migrations` が名前を記録すること、`migrations_dir` / `migrations_pattern` |
| `ke` | [drizzle-kit export][ke]         | 現在のスキーマから DDL を吐く。squash コマンドは公式に存在しない              |

[d1]: https://developers.cloudflare.com/d1/reference/migrations/
[ke]: https://orm.drizzle.team/docs/drizzle-kit-export

**引用は取得時点のものである。** 「必ずずれる3点」は公式ではなく実測なので、drizzle-kit の生成器が変われば変わる — 食い違ったら、正しいのは目の前の diff である。
