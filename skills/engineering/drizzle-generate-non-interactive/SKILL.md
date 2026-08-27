---
name: drizzle-generate-non-interactive
description: TTY の無いところで `drizzle-kit generate` を完走させる。エージェント・フック・CI から generate を回すとき、`Interactive prompts require a TTY terminal` で落ちたとき、`missing_hints` で exit 2 したとき、rename を含むスキーマ変更のマイグレーションを生成するときに使う。
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/pty-generate.py *)
---

# TTY の無いところで drizzle generate を完走させる

**drizzle-kit が止まるのは、消えた実体と現れた実体の対応づけを決められないときだけである。** 公式が generate の工程として挙げる4項目のうち、人間を要求するのは "prompt developer for renames if necessary" の1つだけで、残り(スキーマの読み取り、スナップショットの比較、SQL の生成)は誰にも尋ねない — [kg]。

だから正しい形は「generate は非対話にできない」ではなく、**その1問だけ答えを外から渡す** である。

**既定でハイライトされている選択肢は `create`、つまりデータが消える側である。** 答えを渡さずに済ませることと、何も考えずに Enter を押すことは、同じ結果を生む。

## 手順

### 1. 公式の非対話モードがあるかを、バージョン表ではなく実行で決める

```
npx drizzle-kit generate --output json
```

- **通る** → 公式が非対話を持っている。**このスキルはここで終わり。** 未解決の判断の返り方と答え方(`--hints`)、その型は公式スキルが持っているので、`npx drizzle-kit skills` で入れてそちらに従う — [ks]
- **`Unrecognized options` で落ちる** → 公式の非対話モードは無い。2 へ

バージョン番号で分岐しない。**どちらの経路かは、そのプロジェクトが解決した drizzle-kit 自身が答える。**

**非対話モードが無いのは、機能の欠如ではなくバージョンの問題である。** 公式が非対話を持つ系列が stable で出ているなら、**上げることがこのスキルより正しい解決** で、手順2以降は要らなくなる。判断はレジストリに訊く:

```
npm view drizzle-kit dist-tags
```

`latest` が非対話モードを持つ系列に乗っていれば、上げて 1 をやり直す。prerelease(`beta` / `rc`)にしか無いなら、それを入れるかどうかは prerelease を本番の DB に向ける判断であり、このスキルとは別の話である — 見送るなら 2 へ。

**drizzle-kit だけを上げることはできない。** drizzle-orm と組でしか動かず、古い orm に新しい kit を載せると `ERR_PACKAGE_PATH_NOT_EXPORTED` で起動しない(実測)。上げるならアプリのランタイムごとであり、生成物の配置も変わりうる(→ D1 / wrangler と組み合わせるとき)。

**完了基準: 上のコマンドの実際の出力を根拠に、どちらの経路かを言えること。**

### 2. まず素で回す

```
npx drizzle-kit generate
```

**大半の差分はこれで通る。** 通ったら終わり。

`Interactive prompts require a TTY terminal` で落ちたときだけ 3 へ。config が見つからない・schema のパスが違うといった他のエラーは、TTY とは無関係の別問題である。

### 3. 答えずにプロンプトを読む

```
python3 ${CLAUDE_SKILL_DIR}/scripts/pty-generate.py -- <generate に渡す引数>
```

pty を割り当てて generate を起動し、最初のプロンプトで止め、質問と選択肢を出して exit 2 する。マイグレーションは書かれない。

```
unanswered_prompt: Is name column in users table created or renamed from another column?
  ❯ + name             create column
  ~ full_name › name rename column
```

**推測で答えない。** どの旧実体と対応づくかは選択肢の側に書いてある(`full_name › name`)。それが意図した対応でないなら、答えるのではなくスキーマを直す — 対応づけを歪めて通した migration は、意図と違う列のデータを運ぶ。

### 4. 答えを1つずつ足して再実行する

`--answer` は選択肢の行に対する部分一致で、**プロンプトの出る順に1つずつ** 並べる。

```
python3 ${CLAUDE_SKILL_DIR}/scripts/pty-generate.py --answer "rename column" -- --name rename_full_name
```

**1つ答えるまで次のプロンプトは見えない。** exit 0 になるまで「読む → `--answer` を1つ足す → 再実行」を繰り返す。テーブル改名とカラム改名が同時にあるなら:

```
python3 ${CLAUDE_SKILL_DIR}/scripts/pty-generate.py \
  --answer "rename table" --answer "rename column" -- --name rename_users
```

index ではなく文字列で当てるのは、選択肢の並び順が公式の契約ではないからである。当たらなければ `matched 0 options` で止まる — 黙って隣を選ばない。

**完了基準: exit 0 で、マイグレーションファイルのパスが出ていること。**

### 5. 生成物を2つの目で確かめる

- **SQL が rename になっているか。** `ALTER TABLE ... RENAME` であること。`DROP COLUMN` + `ADD COLUMN` が出ていたら答えを間違えており、そのまま適用するとデータが消える
- **もう一度 `npx drizzle-kit generate` して `No schema changes` が出るか。** 公式が挙げる工程の2つ目は「直近のスナップショットとの比較」なので、ここが緑になることだけが、スナップショットの正しく進んだ証拠である — [kg]

**完了基準: 2つとも実行し、その出力を報告に含めること。**

## 逃げ道を作らない

3つとも generate を通すが、通した意味を壊す。

- **rename を避けるために `--custom` を使う。** プロンプトは出ないが、書かれるスナップショットは **前のもののコピー** である。差分は解消せず、次の generate で同じプロンプトが出る(`--custom` 自体は、データのバックフィルなど差分から出ない SQL を書くための正当な道具である。rename の回避に使うのが誤りである)
- **スナップショット JSON を手で書き換える。** 生成物であり、次の generate が上書きする前提のものを、人間の記憶で埋めることになる
- **rename をやめて drop + add に倒す。** プロンプトは消え、データも消える。「回避できた」は「捨てた」と同義である

## D1 / wrangler と組み合わせるとき

適用が `wrangler d1 migrations apply` なら、**wrangler が探すファイル配置と drizzle-kit の出力配置を一致させる。** wrangler 側の既定と逃がし方は公式が定めている — [d1]:

> A glob pattern (relative to the Wrangler config file) used to discover migration files for this D1 database. Defaults to `${migrations_dir}/*.sql` if not specified.
>
> Use this to opt in to nested layouts such as `migrations/*/migration.sql` (as produced by some ORMs).
>
> When `migrations_pattern` is set, `migrations_dir` must also be set, and `migrations_pattern` must start with `${migrations_dir}/`.

つまり drizzle-kit の出力がフラットな `.sql` でも入れ子でも、wrangler 側の設定1つで受けられる。**配置の非互換は、drizzle-kit のバージョンを選ぶ理由にはならない。**

## 参照

| キー | ソース                                     | 何が書いてあるか                                                         |
| ---- | ------------------------------------------ | ------------------------------------------------------------------------ |
| `kg` | [drizzle-kit generate][kg]                 | generate の4工程と、rename でのみ人間に尋ねるという記述                  |
| `ks` | `npx drizzle-kit skills`(drizzle-kit 同梱) | 公式の非対話手順。`drizzle-generate` と `drizzle-hints` がこの経路を持つ |
| `d1` | [Cloudflare D1 — Migrations][d1]           | `migrations_dir` / `migrations_pattern` と、wrangler が拾う既定の配置    |

[kg]: https://orm.drizzle.team/docs/drizzle-kit-generate
[d1]: https://developers.cloudflare.com/d1/reference/migrations/

**引用は取得時点のものである。** フラグ名も設定キーも公式が動かす。ここの記述に従って判断を確定させる前に、リンク先で裏を取る。手順2〜5の挙動(エラー文言、プロンプトの形)は公式ドキュメントではなく実測なので、なおさら食い違いうる — 食い違ったら、正しいのは目の前の出力である。
