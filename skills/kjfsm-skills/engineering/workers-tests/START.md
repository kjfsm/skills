# ゼロから始める

[SKILL.md](SKILL.md) の共通の規律(一次情報の順序、プロジェクトの分け方、壊して確かめる)に加えて、テストが1本も無いところで決めること。

Workers のプロジェクトでゼロから始めると、`@cloudflare/vitest-plugin` が用意した箱にとりあえず全部入れてしまいやすい。すると **すべてのテストが workerd 上で走る** ことになり、実行時間だけが増えて、壊れた場所も特定しにくいスイートができあがる。

## フレームワークからではなく、壊れ方から始める

最初の問いは「この pool で何がテストできるか」ではなく **「何が壊れると困るか」** である。Workers のプロジェクトでは、次の 4 つが上位に来る。

1. **壊れたとき、気づけないもの** — 権限判定、所有権スコープ（他人の id は 404 で返す、など）、署名や暗号の検証。壊れても画面は正常に見える
2. **壊れたとき、取り返しがつかないもの** — 削除の連鎖（FK の cascade）、マイグレーション、課金
3. **過去に実際に壊れたもの** — 同じ事故は繰り返される。issue や修正コミットが一次情報になる
4. **Cloudflare でしか壊れないもの** — D1 の bound parameter 上限（→ `/kjfsm-skills:d1-bound-parameters`）、`db.batch()` の原子性、Durable Object の alarm と WebSocket hibernation、Queues の ack/retry、そして **タイムゾーン**（Workers は UTC。開発機が UTC でないと暦日が 1 日ずれるクラスのバグを見逃す）

この 4 つに当たらないものは後回しでよい。テストの本数を目標にしない。

## 最初の 1 本は、足場ゼロで書けるものにする

足場（D1 のマイグレーション適用、テストデータの生成、fake の仕組み）を先に作りたくなるが、**足場は 2 本目以降の重複を見てから作る**。1 本目は `node` プロジェクトで、何も用意せずに `import` して呼べる関数から始める。

これには副作用がある — **足場なしで書けないなら、それはプロダクション側が依存を内部で作っているというシグナル**である。Workers で最も多い形は、モジュールのどこからでも `env` を取れるグローバルアクセサと、`cloudflare:workers` からの直 import である。これがアプリ層にあると、そのモジュールを触るテストはすべて workerd を要求する。ゼロの段階で気づけば、env を引数・context で渡す形に倒すのは安い。

## unit と integration を書き分ける

公式ドキュメントが最初に立てる区別はこれである。ファイル名に出しておくと、後から読む人が迷わない。

| スタイル    | 呼び方                                              | import                                                                            |
| ----------- | --------------------------------------------------- | --------------------------------------------------------------------------------- |
| unit        | worker を import して `worker.fetch(req, env, ctx)` | `env` from `cloudflare:workers` + `createExecutionContext` from `cloudflare:test` |
| integration | `exports.default.fetch(...)`                        | `exports` from `cloudflare:workers`                                               |

```ts
const ctx = createExecutionContext();
const response = await worker.fetch(request, env, ctx);
await waitOnExecutionContext(ctx); // waitUntil() された promise を待ってから assert
```

`SELF` は使わない（`exports.default` に置き換わっている）。`exports` 経由でも Worker はテストと同じ isolate で動くので、グローバルモックはそのまま効く。

## 置き場所を先に決める

- **単一モジュールに対するテストは、対象の隣に置く**（`foo.ts` の隣に `foo.test.ts`）
- **複数モジュールにまたがるもの・workerd が要るものは、専用のディレクトリに置く**
- `tests/workerd/` の中は公式 fixture と同じく **トピック × スタイル**（`fetch-unit` / `fetch-integration-self` / `queue-consumer-unit` / `durable-objects-websockets`）

**対象ファイルの一覧を設定に個別列挙しない。** 列挙は必ず漏れる — 新しく足したパッケージのテストが無言でスキップされ、緑のまま守られていない状態になる。`packages/*/src/**/*.test.ts` のようにパターンでまとめて拾う。

## 書かないものを、先に決めておく

- **静的な文言の写し取り** — 文言を変えるたびにテストを直すだけで、何も守らない
- **同じ判定の多層検証** — 判定は最も内側で 1 回。外側が見るのは「その判定が呼ばれること」と「偽のとき副作用が無いこと」だけ。ここを守らないと、権限を 1 つ足すたびに何十本も落ちるスイートになる
- **総当たりの展開** — 権限行列のような入力空間の広い判定を全組み合わせに展開しない。落ちたときにどのルールが壊れたか分からない。代表値 × 境界で足りる
- **実装をなぞったアサーション** — 期待値をコードと同じ手順で計算しているものは、構造上必ず通る
