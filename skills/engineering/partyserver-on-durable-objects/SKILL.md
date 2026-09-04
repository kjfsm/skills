---
name: partyserver-on-durable-objects
description: partyserver(`Server`)を Durable Object の上に載せるときの、公式ドキュメントに載っていない挙動。stub の取り方でリクエスト数が2倍になるとき、`onStart` に初期化や移行を置くとき、WebSocket のハイバネーションと keepalive を組むとき、RPC メソッドを足すか `onRequest` のままにするか決めるときに使う。素の Durable Objects の API は公式の `durable-objects` スキルが持つ。
---

# partyserver を Durable Object に載せる

**素の DO の API はここに書かない。** ストレージ・並行性・alarm・`blockConcurrencyWhile`
そのものは Cloudflare 公式の `durable-objects` スキルと
[公式ドキュメント](https://developers.cloudflare.com/durable-objects/)が正である。
ここが持つのは **partyserver が間に入ることで変わる4点** だけで、どれも公式には載らない。

確認したのは `partyserver@0.5.10` の `dist/index.js`。**版が上がったら読み直す** ——
ここに書いてあるのは仕様ではなく実装の観測である。

## 1. stub の取り方が、そのままリクエスト数になる

`getServerByName()` は **`setName` を DO への RPC として呼んでから** stub を返す。

```js
async function getServerByName(serverNamespace, name, options) {
  const id = serverNamespace.idFromName(name);
  await retryDurableObjectOperation(() => serverNamespace.get(id, ...).setName(name, ...));
  return serverNamespace.get(id, getOptions);
}
```

RPC は1リクエストとして課金される。**続く `fetch()` でもう1つ**なので、`getServerByName` で
取った stub を1回叩くと **2リクエスト**になる。

判断はこの1問で決まる —— **その stub で何を呼ぶか。**

| 呼ぶもの | 取り方 | 理由 |
| --- | --- | --- |
| `fetch()` / WebSocket の Upgrade | `env.NS.getByName(name)` | `Server.fetch()` が自分で `#ensureInitialized()` を呼ぶ |
| 自前の RPC メソッド | `await getServerByName(env.NS, name)` | **RPC は初期化を通らない**(→ 2.) |

`setName` の JSDoc 自身が「**`@deprecated` for callers that address DOs via `idFromName()` /
`getByName()`**」「calling `setName()` is redundant — `this.name` is available automatically
from `ctx.id.name`」と書いている。`getByName` で取った DO では `this.name` は埋まっている。

**この違いは、RPC 化を「面積が減るから」で選べないことを意味する。** `onRequest` を
やめて RPC メソッドにすると、呼び出しごとに `getServerByName` が要り、**消したはずの
1リクエストが戻る。** 熱い経路(1件ごとに叩くもの)では `fetch` のほうが安い。

## 2. `onStart` は `blockConcurrencyWhile` の中で走り、失敗しても DO はリセットされない

partyserver は `onStart()` を `ctx.blockConcurrencyWhile()` の中で呼ぶ。だから
**`onStart` が終わるまで、どの要求も届かない** —— 初期化と移行をここへ置けば、
「半分だけ初期化された状態で誰かが繋いだ」が構造的に起きない。

対価が2つある。

**30秒を超えると DO がリセットされる**(公式)。`onStart` の中で外部 I/O(D1・R2・fetch)を
回すなら、**その往復の総量が上限**である。件数に比例する処理を置くときは、そこを見積もる。

**例外を投げても、公式が言う「callback が throw したら DO を終了してリセット」には
ならない。** partyserver が callback の**中で** catch し、`#status` を `"zero"` に戻して、
ブロックの**外**で投げ直すためである。

```js
await this.ctx.blockConcurrencyWhile(async () => {
  this.#status = "starting";
  try { await this.onStart(this.#_props); this.#status = "started"; }
  catch (e) { this.#status = "zero"; error = e; }
});
if (error) throw error;
```

結果として **DO は生きたまま、次の要求が `onStart` を最初からやり直す。**
**途中まで書いた分は残っているので、`onStart` は冪等に書く** ——
`CREATE TABLE IF NOT EXISTS` と `INSERT OR IGNORE`、そして
**「済んだ」印は最後の1本で書く**(先に書くと、欠けたまま済んだことになる)。

`fetch` / `webSocketMessage` / `webSocketClose` / `alarm` はどれも入口で
`#ensureInitialized()` を通るので、**ハイバネーションから起き直した回も `onStart` を通る。**
毎回走ってよい形にしておく。

## 3. ハイバネーションで消えるものと、消えないもの

`static options = { hibernate: true }` を付けたら、次の2つを守る。

**接続ごとの値は `connection.setState()` に置く。** partyserver はこれを
`ws.serializeAttachment()` へ落とすので、ハイバネーションを越えて `connection.state` で
読み直せる。**インスタンスのフィールドに置いたものは消える** —— 起き直しは新しい
インスタンスである。

**keepalive で起こさない。** アイドルで切られないための ping を素の `onMessage` で
受けると、**その1往復ごとに DO が起きて課金される。** 起こさずに応えるのはこれ1つ。

```ts
constructor(ctx: DurableObjectState, env: Env) {
  super(ctx, env);
  this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
}
```

## 4. WebSocket のメッセージ上限は 32 MiB

2025-10-31 に **1 MiB から 32 MiB へ上がった**([changelog](https://developers.cloudflare.com/changelog/post/2025-10-31-increased-websocket-message-size-limit/))。
繋いだ相手へ手元の状態を丸ごと1本で配る形(`durable-chat-template` と同じ形)は、
**サイズでは当分詰まらない。**

先に痛むのは **接続ごとに全件を読んで JSON にする CPU** のほうである。
Workers Free の CPU 上限は 10ms なので、配る件数が伸びる設計では、
**サイズではなく組み立ての時間を見る。**

## 読む順

1. 素の DO の API・ストレージ・テスト → 公式の `durable-objects` スキル
2. その上で partyserver を挟むときの差分 → この文書
3. 実装の観測が必要になったら → `node_modules/partyserver/dist/index.js` を直接読む
