# SSR を `main` に載せた Worker

[SKILL.md](SKILL.md) の共通の規律に加えて、**`main` に SSR アプリが載っているときにだけ起きること**。

素の Worker では出てこない。`wrangler.jsonc` の `main` が `workers/app.ts` で、それが `virtual:react-router/server-build` を import している構成でだけ、テストの値段が桁で変わる。

## 目次

- 費用は「実行」ではなく `main` が決める
- 層は3つになる
- エントリを切り出す
- `createTestHarness` の実務
- アプリ側に1つだけ手が要る
- 公式が引いている線(React Router)
- 自分の環境で測り直す

## 費用は「実行」ではなく `main` が決める

空のテスト2本のファイルで、`main` だけを替えて測った実測(4コア、euphotter)。

| `main`              | setup の中身        | transform | setup(2ファイル合計) |
| ------------------- | ------------------- | --------- | -------------------- |
| React Router アプリ | `applyD1Migrations` | 10.79s    | **23.96s**           |
| React Router アプリ | `SELECT 1` だけ     | 0.03s     | 0.06s                |
| 極小 Worker         | `applyD1Migrations` | 0.08s     | **0.24s**            |
| ビルド済みバンドル  | `applyD1Migrations` | 1.90s     | 5.09s                |

読み方は3つ。

- **マイグレーションは安い。** 16本 94 文で 0.12 秒。遅いのは `applyD1Migrations` が `main` の Worker を立ち上げること
- **バインディングに触るだけなら `main` は載らない。** `SELECT 1` は 0.06 秒で終わる。ここが非対称なので「D1 が遅い」と読み違えやすい
- **費用の8割は Vite の変換側にある。** ビルド済みバンドルを指すと 24s → 5s。残る 2.5 秒/file が workerd がアプリを評価する分

**遅延 import では消えない。** `createRequestHandler(() => import("virtual:react-router/server-build"))` は既に動的 import だが、1度も fetch していないファイルでも満額かかる。費用が居るのは実行時ではなくモジュールグラフの解決・変換で、コード側のリファクタでは動かない。

## 層は3つになる

[SKILL.md](SKILL.md) の「node と workerd の2つ」は `main` が軽いときの話である。SSR を載せると、**Worker を HTTP で叩く層**と**バインディングに直に触る層**を分ける価値が出る。

| 層         | 何に話しかけるか                      | ランタイム                       | 固定費/file |
| ---------- | ------------------------------------- | -------------------------------- | ----------- |
| `node`     | [SKILL.md](SKILL.md) の `node` と同じ | Node                             | ~0          |
| `bindings` | 実 D1・実 R2 に直に。route は通らない | workerd(極小 `main`)             | **0.12s**   |
| `http`     | Worker 丸ごと。本物の HTTP で         | 本番ビルド + `createTestHarness` | **2.6s**    |

これは Cloudflare が [`/workers/testing/`](https://developers.cloudflare.com/workers/testing/) で挙げる2つの道具([ユニット](https://developers.cloudflare.com/workers/testing/#unit-tests) = Vitest 統合、[統合](https://developers.cloudflare.com/workers/testing/#integration-tests) = テストハーネス)にそのまま対応する。

3層に割っても `node` は狭めない。`bindings` が 0.12s/file と安くても、依存を引数で受け取るモジュールを実物で試すために移さない — 偽物なら「R2 の `put` が失敗する」「レート制限に掛かる」「`waitUntil` に積んだ処理が失敗する」を1行で作れるが、実物ではその状態へ持ち込むのが難しい。

`bindings` の `main` は自分で書く。**アプリを載せないことがこの層の全部である。**

```ts
// tests/bindings/worker.ts
export default {
  fetch: () => new Response("bindings project: no app here", { status: 501 }),
} satisfies ExportedHandler;
```

501 を返すのは、この層から route を叩いたら間違いだと実行時にも言わせるため。空の 200 だと、間違えたテストが静かに通る。

**Durable Object を足したら、極小 `main` からも export する。** `class_name` に `script_name` を添えていない DO は `main` から解決されるので、export が無いと `TypeError: … does not export a Live Durable Object` が全ファイルで出る。誰も `env.LIVE` を触っていないうちは緑のままなので、触った日に初めて落ちる。

```ts
export { Live } from "../../workers/live";
```

**置き場は [START.md](START.md) の規定をそのまま当て、workerd 側だけを `tests/bindings/`・`tests/http/` に分ける。** 2層に割る前の `tests/workerd/` は `tests/bindings/` に改名する — HTTP で叩くものが `http` へ抜けると、残るのはバインディングに直に触るものだけになる。トピック × スタイルの分け方も `tests/bindings/` で続けるが、`fetch-integration-self` のように Worker の `fetch` を通すスタイルは `http` へ移る(ここの `main` は 501 しか返さない)。

**middleware や loader を関数として実 D1 で呼ぶテストは `bindings` に置く。** `getLoadContext` と同じく `new RouterContextProvider()` で context を組み([Middleware | React Router](https://reactrouter.com/how-to/middleware))、直接呼べば route は通らない。Vitest 統合のテストは Workers ランタイムの中で走ってバインディングに直に触れ([Unit tests](https://developers.cloudflare.com/workers/testing/#unit-tests))、数える側のモジュールもテストが import したものなのでその値をそのまま読める。ハーネスがテストに渡すのはバインディング・ストレージ・ログで、Worker のモジュールの中の値は含まれない([`getEnv()`](https://developers.cloudflare.com/workers/testing/test-harness/prepare-test-state/#access-configured-bindings)・[`getLogs()`](https://developers.cloudflare.com/workers/testing/test-harness/interact-with-workers/#assert-logged-behavior))。だから発行ステートメント数に上限を置くテストのようにモジュールの中の値を読むものは、`bindings` でしか書けない。認可を本物のルート越しに通す確認だけを `http` に数本足す([Integration tests](https://developers.cloudflare.com/workers/testing/#integration-tests) が挙げる「設定した HTTP ルートを通す網羅」がこれに当たる) — 判定を検証するのは内側の1回である([START.md](START.md) の「書かないもの」)。

**ブラウザを操作しない E2E は `http` へ移す。** ステータスと HTML しか見ない Playwright のテスト(拒否が 404 になりアプリへ戻るリンクがある、不正なクエリでも 200)は、クリック・入力・クライアント JS の実行を待つ手順が無い。それなら `createTestHarness` で足り、ブラウザを起こす分だけ高い。Cloudflare もハーネスと Playwright を組む理由を「実ブラウザでユーザーの操作の流れを確かめるため」に置いている([Integrations](https://developers.cloudflare.com/workers/testing/test-harness/integrations/#playwright))。

## エントリを切り出す

React Router などの SSR フレームワークを使っている場合、`workers/app.ts` のようなエントリは仮想モジュール（`virtual:react-router/server-build`）を import している。**フレームワークの Vite プラグインを vitest の config にも載せれば解決はする** — ただしそのとき、SSR のモジュールグラフが **テストファイルごとに** 変換・評価される（実測 15.2 秒/file）。載せなければ `main` に指定した時点で解決に失敗する。どちらに転んでも、この `main` を全テストの土台にはしない(→ 上の表)。

fetch/queue/scheduled の実体を、SSR ディスパッチャを引数で受け取る関数(`createWorkerHandlers` など)として切り出す。**`bindings` の `main` は上の 501 を返す極小 Worker のまま変えない。** 配線のテストはその関数を import し、SSR だけを fake にして直接呼ぶ — 組み立てたものを `main` に据えると、上の 501 が効かなくなる。SSR を実際に通す検証は、本番ビルドを起動する `createTestHarness()` の担当になる。

**切り出しは、エントリに fetch 層のロジックが乗ってからでよい。** 委譲 1 行しかない段階で切ると、空のシームが 1 つ増えるだけである（足場と同じ判定 — [START.md](START.md) の「最初の 1 本」）。

ただし **型プロジェクトの側は最初から巻き込まれる**。`wrangler types` が吐く `worker-configuration.d.ts` は `mainModule` を `typeof import("./workers/app")` と型付けするので、このファイルを `include` したテスト用 tsconfig は **エントリごと引き込む**。テストが一度も import していなくても、そのプロジェクトはフレームワークの typegen 出力（`.react-router/types`）と `vite/client` を要求し始める。`Cannot find module 'virtual:…'` がテスト側の tsconfig から出たら、これである。

## `createTestHarness` の実務

公式の入門に書かれていない、実際にぶつかる7つ。

- **ビルドは globalSetup で毎回作り直す。** ハーネスが叩くのはビルド成果物で、`build/` は前に何を走らせたかで中身が変わる。古いものが残ると、直したはずの経路を検査しないまま緑になる
- **ハーネスはテストファイルごとに1つ。** ストレージもそこで閉じるので、どのファイルも空の DB から始まり、同じ handle を同時に使える。公式の入門は `afterEach(server.reset)` を見せるが、`beforeAll` で状態を積むテストではその `beforeAll` をテストの数だけ繰り返すことになる
- **応答は本体まで読んでから返す。** 読み残した応答が接続を掴んだままになり、続けて投げたリクエストが `Network connection lost` で 500 になる。応答コードしか見ないテストが必ずこれを踏む
- **`FormData` をそのまま渡さない。** ハーネスの `fetch` は境界を含む `Content-Type` を組み立てないので、Worker 側の `request.formData()` が「知らない MIME だ」と投げて 500 になる。`new Response(formData)` に一度通し、ヘッダとバイト列の両方を自分で取り出す
- **better-auth は `Content-Type: application/json` を要求する。** JSON を名乗らない POST に 415 を返す。`SELF` 越しの素の POST では通っていたので、移してから気づく
- **`env` を直に書き換えても届かない。** Worker は別プロセスに居て、こちらが持っているのは写しである。値を差し替えるなら `secrets`(テスト専用の上書き)で Worker を起こし直す
- **落ちたテストには `server.debug()` を添える**(`afterEach` で `task.result?.state === "fail"` を見る)。これが無いと応答の 500 だけが残り、サーバー側で何が投げられたのかが消える

**一度に投げすぎない。** 100本同時の POST は次のリクエストの接続ごと落とす(60本までは通る)。20本ずつの束に割る。同時に投げること自体が主題のテストは、まず無い。

## アプリ側に1つだけ手が要る

**認可で弾く POST は本体を読まずに応答を作る。** `notFound()` が `request.formData()` の手前に居る形である。読み残されたリクエスト本体を手元の runtime は引きずり、**数リクエスト後に無関係な要求が `Network connection lost` で 500 になる**。12回投げると4回目以降が全部落ちる、という形で決定的に再現する。

`SELF` は HTTP を通らないので踏まない。**`wrangler dev` は同じ経路なので、テストだけの都合ではない。**

```ts
const response = await requestHandler(request, context);
if (request.body !== null && !request.bodyUsed) {
  await request.arrayBuffer().catch(() => undefined);
}
return response;
```

## 公式が引いている線(React Router)

[Testing | React Router](https://reactrouter.com/start/framework/testing) は `createRoutesStub` を **router のフックに依存する再利用コンポーネント**に限定し、**route module 自体を stub で試すことを明確に外している** — `Route.*` の型は実アプリの loader/action と route tree から導かれるので噛み合わず、`matches` も実行時と違うものが入る。

route を丸ごと試すなら「**動いているアプリに対する統合/E2E テスト**」で見ろ、というのがその代わりに置かれている指針である。上の表の `http` 層がそれに当たる。**コンポーネントだけを試す層を作らないことは、公式の立場と矛盾しない。** 公式が外しているのは stub 越しの route コンポーネントであって、middleware や loader を関数として直に呼ぶこと(上の `bindings`)には触れていない — stub を組まないので、型が噛み合わない問題も起きない。

## 自分の環境で測り直す

数字を信じる前に、同じ形で1度測る。空のテスト2本と、`main` を替えた config が2つあればよい。

```bash
# 1) main = 本番の SSR エントリ  2) main = 極小 Worker
pnpm exec vitest run --config vitest.bench1.config.ts 2>&1 | grep Duration
pnpm exec vitest run --config vitest.bench2.config.ts 2>&1 | grep Duration
```

見るのは `Duration` の内訳の **setup** である。テスト本体(`tests`)ではなく、そこが1ファイルあたりの固定費になっている。差が桁で出ないなら、その構成に SSR は載っていない — この規律は要らない。
