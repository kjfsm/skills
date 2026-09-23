---
name: workers-tests
description: Cloudflare Workers のプロジェクトでテストスイートを作る・立て直すときの規律。テストが1本も無いところから始めるとき、vitest.config が複雑すぎる・テストが遅い・OOM する・vi.mock だらけで信用できないとき、@cloudflare/vitest-plugin(旧 @cloudflare/vitest-pool-workers)を上げたら壊れたとき、React Router などの SSR を `main` に載せていて1ファイルに十数秒かかる・`applyD1Migrations` が遅い・`createTestHarness` で HTTP の層を作るとき、Workers / D1 / Durable Objects / Queues にテストを入れたいときに使う。
---

# Cloudflare Workers のテスト

`tdd` が「1 本のテストをどう書くか」なら、こちらは **スイートの土台をどこに置くか** — プロジェクトの分け方、置き場、足場 — を決める。

## 状況で読むもの

- **テストが1本も無い** → [START.md](START.md) — 何から書くか、置き場、書かないもの
- **既存のスイートが重い・複雑・信用できない、版を上げて壊れた** → [REBUILD.md](REBUILD.md) — `vi.mock` の本数を減らす方向、棚卸し、履歴からの復元、版移行、実 D1 の足場
- **`main` が SSR アプリ(`virtual:react-router/server-build` を import するエントリ)** → [SSR.md](SSR.md) — 費用の測り方、3層への割り方、`createTestHarness` の実務。上の2つと併せて読む

以下は、どの状況でも当てる。

## 一次情報の順序

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

## プロジェクトはランタイムでだけ分ける

Vitest の `projects` を分ける正当な理由は **ランタイムが違うこと** だけである（`environment` / `pool` / `setupFiles` はプロジェクト単位でしか設定できない）。Workers のプロジェクトなら次の 2 つ、DOM が要るなら 3 つ。**SSR を `main` に載せているなら、workerd 側をさらに2つに割る**(→ [SSR.md](SSR.md))。

| プロジェクト | 対象                                                                               |
| ------------ | ---------------------------------------------------------------------------------- |
| `node`       | 外部 I/O を持たないもの。純粋なルール、判定、変換、引数で env を受け取るモジュール |
| `workerd`    | **Cloudflare でしか壊れないもの**。実 D1、Durable Object、Queues、WebSocket        |

判定ロジックや変換は全部 `node` に置く。workerd に置くと 1 ファイルあたり数秒の起動コストを払うことになり、得るものが無い。

正当でない理由は **モックの都合** である。「このファイル群は先に `vi.mock` を効かせたいから別プロジェクト」は、設定の問題ではなく、そのモジュールが引数や context で渡されていないというシグナルである(→ [REBUILD.md](REBUILD.md))。

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

## 観測してから入れる設定

`isolate: false` / `maxWorkers` / `fileParallelism` / `sequence.groupOrder` は、**遅くなった・OOM した事実を観測してから**入れる。`isolate: false` はワーカーごとにモジュールグラフを丸ごと保持するので、`maxWorkers` を付けずに入れるとメモリが線形に膨らむ。**入れるときは必ず対で入れる。**

**速くする手の効果は、CI の run の数字で判定する。** 手元のマシンを `taskset` で CI と同じコア数に縛っても、CI の向きは再現しない — 実例では、`isolate: false` は手元でほぼ効かず CI で半分に縮み、`maxWorkers` の引き上げは手元で大きく効いて CI の 2 vCPU では誤差だった。ファイルごとの import の費用とワーカーを増やす利得が、環境で違うからである。手元の計測は仮説づくりまでに使い、採否と PR 本文に載せる数字は `gh run view <id> --log` の `Duration` から取る。

## カバレッジ比率をゲートにしない

カバレッジは計測して眺めるものであって、閾値で CI を止めるものではない。比率は無関係な変更で動く — `--project` の指定漏れで分母が変わる、リファクタで行数が変わる。閾値で落ちた回数のうち、コードの正しさに関係していたものが何回あったかを数えてみるとよい。

**workers pool は V8 coverage に非対応**で、併用すると `ERR_METHOD_NOT_IMPLEMENTED` で exit 1 になる（公式 Known issues が Istanbul を使えと明記）。`--project` で node に絞るか、Istanbul provider に切り替える。

## 書いたテストは、壊して確かめる

1 本書くごとに **実装を意図的に壊して、テストが落ちることを確かめる。** 通るだけのテストは、書いた本人に「守られている」という誤解だけを残す。ゼロから作る段階でやれば、足場や書き方の癖の問題に1本目で気づける。壊し方は検証したい主張に合わせる — 境界の `>` と `>=`、分岐の順序、早期 return の削除、定数の値。

落ちなかったときが本番である。原因は 3 つのどれかで、対応が違う。

| 落ちない理由                                                 | 対応                                                     |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| その分岐が冗長（他の判定と等価で、外しても挙動が変わらない） | テストではなくコードの事実。コメントで残すか、分岐を消す |
| アサーションが弱い                                           | テストを強くする                                         |
| 主張そのものが実態と違う                                     | テストの主張を実態に合わせて書き直す                     |

アサーションが弱い例は見つけにくい。オブジェクト全体を緩く比較する検証は、意図した変換が起きていなくても偶然通ることがある — 構造化ログの検証で `Error` を展開しているかを見たいなら、entry を直接見ずに **`JSON.stringify` を通した後**を見る、といった具合に、主張が成立しない形を具体的に潰す。
