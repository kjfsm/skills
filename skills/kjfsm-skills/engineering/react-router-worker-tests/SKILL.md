---
name: react-router-worker-tests
description: SSR フレームワーク(React Router など)を `main` に載せた Cloudflare Worker のテストを組む規律。テストが1ファイルあたり十数秒かかるとき、`applyD1Migrations` が遅いとき、Worker を HTTP から叩く層を `createTestHarness` で作るとき、`main` に何を指すか決めるとき、SSR を載せた構成でテスト層を分け直すときに使う。
---

# React Router を載せた Worker のテスト

`create-tests` が「ゼロから何をどこに置くか」、`rebuild-tests` が「壊れたスイートをどう建て直すか」なら、ここが持つのは **`main` に SSR アプリが載っているときにだけ起きること** である。

素の Worker では出てこない。`wrangler.jsonc` の `main` が `workers/app.ts` で、それが `virtual:react-router/server-build` を import している構成でだけ、テストの値段が桁で変わる。

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

`create-tests` の「node と workerd の2つ」は `main` が軽いときの話である。SSR を載せると、**Worker を HTTP で叩く層**と**バインディングに直に触る層**を分ける価値が出る。

| 層         | 何に話しかけるか                      | ランタイム                       | 固定費/file |
| ---------- | ------------------------------------- | -------------------------------- | ----------- |
| `node`     | 何にも触らない — 判定・解析・変換     | Node                             | ~0          |
| `bindings` | 実 D1・実 R2 に直に。route は通らない | workerd(極小 `main`)             | **0.12s**   |
| `http`     | Worker 丸ごと。本物の HTTP で         | 本番ビルド + `createTestHarness` | **2.6s**    |

これは Cloudflare が [`/workers/testing/`](https://developers.cloudflare.com/workers/testing/) で挙げる2つの道具(ユニット = Vitest 統合、統合 = テストハーネス)にそのまま対応する。

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

route・loader/action・サーバー側のコードは「**動いているアプリに対する統合テスト**」で見ろ、というのがその代わりに置かれている指針である。上の表の `http` 層がそれに当たる。**コンポーネントだけを試す層を作らないことは、公式の立場と矛盾しない。**

## 自分の環境で測り直す

数字を信じる前に、同じ形で1度測る。空のテスト2本と、`main` を替えた config が2つあればよい。

```bash
# 1) main = 本番の SSR エントリ  2) main = 極小 Worker
pnpm exec vitest run --config vitest.bench1.config.ts 2>&1 | grep Duration
pnpm exec vitest run --config vitest.bench2.config.ts 2>&1 | grep Duration
```

見るのは `Duration` の内訳の **setup** である。テスト本体(`tests`)ではなく、そこが1ファイルあたりの固定費になっている。差が桁で出ないなら、その構成に SSR は載っていない — この規律は要らない。
