---
name: create-tests
description: Cloudflare Workers のプロジェクトで、テストが1本も無いところからテストを作り始めるときの規律。Workers / D1 / Durable Objects / Queues にテストを入れたいとき、@cloudflare/vitest-plugin をどう設定するか決めたいとき、何からテストすればいいか分からないときに使う。
---

# ゼロからテストを作り始める（Cloudflare Workers）

`tdd` が「1 本のテストをどう書くか」、`rebuild-tests` が「壊れたスイートをどう建て直すか」なら、こちらは **最初の 1 本をどこに置くかを決める** ためのものである。

Workers のプロジェクトでゼロから始めると、`@cloudflare/vitest-plugin` が用意した箱にとりあえず全部入れてしまいやすい。すると **すべてのテストが workerd 上で走る** ことになり、実行時間だけが増えて、壊れた場所も特定しにくいスイートができあがる。

## 一次情報の場所

推測で API 名を書かない。この順で当たる。

| 何を知りたいか                        | 見る場所                                                                               |
| ------------------------------------- | -------------------------------------------------------------------------------------- |
| `cloudflare:test` の API 一覧と非推奨 | **インストール済みの型定義**（`@cloudflare/vitest-plugin/types/cloudflare-test.d.ts`） |
| 各バインディングの書き方の実例        | `cloudflare/workers-sdk` の `fixtures/vitest-plugin-examples/<topic>/`                 |
| API の説明・レシピの索引・既知の制約  | https://developers.cloudflare.com/workers/testing/vitest-integration/                  |

fixture はブラウザより `gh` が速い:

```bash
gh api repos/cloudflare/workers-sdk/contents/fixtures/vitest-plugin-examples --jq '.[].name'
gh api repos/cloudflare/workers-sdk/contents/fixtures/vitest-plugin-examples/d1/vitest.config.ts --jq '.content' | base64 -d
```

**型定義とドキュメントが食い違ったら型定義を採る。** 実例: `cloudflare:test` の `env` と `SELF` は v1 の型定義でも `@deprecated`（`cloudflare:workers` の `env` / `exports` へ移行）だが、ドキュメントの API ページには非推奨の記載がない。ドキュメントだけを見ていると、非推奨の API で書き始めてしまう。

## フレームワークからではなく、壊れ方から始める

最初の問いは「この pool で何がテストできるか」ではなく **「何が壊れると困るか」** である。Workers のプロジェクトでは、次の 4 つが上位に来る。

1. **壊れたとき、気づけないもの** — 権限判定、所有権スコープ（他人の id は 404 で返す、など）、署名や暗号の検証。壊れても画面は正常に見える
2. **壊れたとき、取り返しがつかないもの** — 削除の連鎖（FK の cascade）、マイグレーション、課金
3. **過去に実際に壊れたもの** — 同じ事故は繰り返される。issue や修正コミットが一次情報になる
4. **Cloudflare でしか壊れないもの** — D1 の bound parameter 上限、`db.batch()` の原子性、Durable Object の alarm と WebSocket hibernation、Queues の ack/retry、そして **タイムゾーン**（Workers は UTC。開発機が UTC でないと暦日が 1 日ずれるクラスのバグを見逃す）

この 4 つに当たらないものは後回しでよい。テストの本数を目標にしない。

## プロジェクトは 2 つに分ける — それ以上でも以下でもない

Vitest の `projects` を分ける正当な理由は **ランタイムが違うこと** だけである（`environment` / `pool` / `setupFiles` はプロジェクト単位でしか設定できない）。Workers のプロジェクトでは、最初から次の 2 つになる。

| プロジェクト | 対象                                                                               |
| ------------ | ---------------------------------------------------------------------------------- |
| `node`       | 外部 I/O を持たないもの。純粋なルール、判定、変換、引数で env を受け取るモジュール |
| `workerd`    | **Cloudflare でしか壊れないもの**。実 D1、Durable Object、Queues、WebSocket        |

判定ロジックや変換は全部 `node` に置く。workerd に置くと 1 ファイルあたり数秒の起動コストを払うことになり、得るものが無い。

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    projects: [
      { extends: true, test: { name: "node", include: [/* パターンで拾う */] } },
      {
        extends: true,
        plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.toml" } })],
        test: { name: "workerd", include: ["tests/workerd/**/*.test.ts"] },
      },
    ],
  },
});
```

**miniflare の設定を config に書き写さない。** `wrangler.configPath` で本番の設定を参照する。書き写すと本番と二重管理になり、Durable Object の SQLite バックエンド指定（`[[migrations]]` の `new_sqlite_classes`）のような細部がずれる。テスト専用の値を足したいときだけ `miniflare.bindings` を併記する。

**タイムゾーンは config のトップレベルで固定する。**

```ts
process.env.TZ = process.env.TEST_TZ ?? "UTC";
```

`test.env.TZ` では効かない — Node は最初に日時を触った時点でタイムゾーンを確定するため、ワーカー起動後の書き換えは反映されない。config はワーカー起動前に評価されるので、ホストの TZ に関係なく効く。

## SSR フレームワークを載せているなら、エントリを切り出す

React Router などの SSR フレームワークを使っている場合、`workers/app.ts` のようなエントリは仮想モジュール（`virtual:react-router/server-build`）を import しており、**workerd 上では解決できない**（`main` に指定すること自体はできるが、`fetch` を呼んだ瞬間に落ちる）。

fetch/queue/scheduled の実体を、SSR ディスパッチャを引数で受け取る関数として切り出す。テストは最小のエントリからそれを組み立て、SSR だけを fake に差し替える。SSR を実際に通す検証は、本番ビルドを起動する `createTestHarness()` の担当になる。

**切り出しは、エントリに fetch 層のロジックが乗ってからでよい。** 委譲 1 行しかない段階で切ると、空のシームが 1 つ増えるだけである（足場と同じ判定 — 次節）。

ただし **型プロジェクトの側は最初から巻き込まれる**。`wrangler types` が吐く `worker-configuration.d.ts` は `mainModule` を `typeof import("./workers/app")` と型付けするので、このファイルを `include` したテスト用 tsconfig は **エントリごと引き込む**。テストが一度も import していなくても、そのプロジェクトはフレームワークの typegen 出力（`.react-router/types`）と `vite/client` を要求し始める。`Cannot find module 'virtual:…'` がテスト側の tsconfig から出たら、これである。

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

## 最初から入れない設定

`isolate: false` / `maxWorkers` / `fileParallelism` / `sequence.groupOrder` は、**遅くなった・OOM した事実を観測してから**入れる。`isolate: false` はワーカーごとにモジュールグラフを丸ごと保持するので、`maxWorkers` を付けずに入れるとメモリが線形に膨らむ。**入れるときは必ず対で入れる。**

カバレッジは計測して眺めるだけにして、比率を CI のゲートにしない。なお **workers pool は V8 coverage に非対応**で、併用すると `ERR_METHOD_NOT_IMPLEMENTED` で落ちる（公式 Known issues が Istanbul を使えと明記）。coverage を取るなら node プロジェクトだけに絞るか、Istanbul provider に切り替える。

## 書いたら、壊して確かめる

1 本書くごとに **実装を意図的に壊してテストが落ちることを確かめる**。ゼロから作る段階でこれをやると、足場や書き方の癖に問題があったときに 1 本目で気づける。落ちなかったときの読み解き方は `rebuild-tests` を参照。
