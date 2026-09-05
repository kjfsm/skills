---
name: dev-bypass-sign-in
description: 叩くだけでサインイン済みになる開発・E2E 用の入口(dev bypass)を作る。ログインの要る画面を E2E やエージェントから駆動したいとき、dev サーバーでソーシャルログインやパスワード登録を踏まずに座りたいとき、better-auth の `testUtils` の使いどころを決めるとき、既存の bypass の戸が本番の成果物に残っていないか確かめたいとき、他のスキルが認証済みのセッションを必要とするときに使う。
---

# 開発用のバイパスサインイン

**サインインの要る画面は、人間が居ないと動かせない。** E2E も、ブラウザを持つエージェントも、`curl` も、外部 IdP のリダイレクトの向こうで止まる。バイパスはその往復を URL 1つに畳む。

**代償は「誰にでもなれる口」である。** だからこのスキルの重心は、作り方より **閉じ方** にある。

## 1. 座り方を決める

|                    | testUtils で座る         | 本番の口を通す                             | 手で潜る                                 |
| ------------------ | ------------------------ | ------------------------------------------ | ---------------------------------------- |
| やること           | `test.login({ userId })` | 認証ハンドラを内側から叩き、署名検証を外す | `user` 行を insert + Cookie を自分で署名 |
| 本番の方式への依存 | **無い**                 | ある(social / password で書き分け)         | 無い                                     |
| 踏む経路           | セッション発行だけ       | Account 作成〜Cookie まで本番と同じ        | 何も通らない                             |
| 版への強さ         | 強(公開 API)             | 中                                         | 弱                                       |

**better-auth なら既定は testUtils。** サインイン方式が social でも password でもコードが変わらないので、プロジェクトごとの書き分けが消える。

**本番の口を通す**のは、サインインの経路にしか無い分岐を踏ませたいときだけ —— OAuth の callback、`account` 行の紐付け、方式ごとのプラグインのフック。**手で潜る**のは better-auth ではない認証のとき。

**選んだものが、この先の読み方を決める。** testUtils なら 2. から順に読む。他の2つなら **2. を飛ばし**、3. の `format=json` と 5. の目印を自分の方式へ読み替える —— **4.・6.・7. はどれを選んでも同じ**である。

**完了基準: どれを選んだかと、その理由を1行で言えること。**

## 2. testUtils を敷く

**書き始める前に [`TESTUTILS.md`](TESTUTILS.md) を一度開く。** あそこの落とし穴(`saveUser` は `account` 行を作らない、hooks の第2引数が `undefined` になる)は**設計判断を変える**ので、実装したあとに読むと作り直しになる。API の全面と Cookie の中身も同じファイルが持つ。

### 本番の options を1か所から作る

testUtils が作る Cookie は、本番と**同じ secret で署名され、同じ名前に載る**。ずれた瞬間に本番のインスタンスが受け取らなくなるので、**テスト用インスタンスを別に書き起こさない。**

```ts
// auth-options.ts —— 唯一の正
export function authOptions(env: Env): BetterAuthOptions { … }

// auth.ts
export const createAuth = (env: Env) => betterAuth(authOptions(env));

// auth-dev.ts —— plugins に1つ足すだけ
export const createDevAuth = (env: Env) => {
  const base = authOptions(env);

  return betterAuth({ ...base, plugins: [...(base.plugins ?? []), testUtils()] });
};
```

**条件付きスプレッドにしない。** `plugins: [...base, ...(dev ? [testUtils()] : [])]` は `ctx.test` の型推論を壊すと公式が明記している。分けるのは**インスタンス**であって、プラグインの配列ではない。

### シードは `saveUser` で作る

`saveUser` は `internalAdapter.createUser` を通るので **`databaseHooks.user.create` が走る**(before / after とも)。「初回サインインした人が所有者になる」型のロジックはここで踏める —— 直に `INSERT` すると飛ぶ。

**id を固定する。** 表は1か所に置き、これがそのまま `?as=` の語彙になる。

```ts
export const SEED = {
  owner: { id: "dev-owner", email: "owner@dev.invalid", name: "Dev Owner" },
  member: { id: "dev-member", email: "member@dev.invalid", name: "Dev Member" },
} as const;

export type SeedKey = keyof typeof SEED;
export const isSeedKey = (raw: string): raw is SeedKey => raw in SEED;
```

**見てから書く。** `saveUser` は2度目に重複で落ちるので、`ensureSeed` は**種の1人が居るかを見て、居たら1バイトも書かずに戻る。** 2度目以降が何も書かないことが、テストの中から何度でも叩ける条件である。

### ルート

```ts
if (env.ALLOW_DEV_BYPASS !== "true") return new Response("Not Found", { status: 404 });
console.warn(DEV_BYPASS_WARNING);

const { test } = await createDevAuth(env).$context;
await ensureSeed(test, db);

const as = url.searchParams.get("as") ?? "owner";
if (!isSeedKey(as)) return new Response("Not Found", { status: 404 });

const { user, token, cookies } = await test.login({ userId: SEED[as].id });

if (url.searchParams.get("format") === "json") {
  return Response.json({ userId: user.id, token, cookies });
}

const headers = new Headers({
  Location: landingFrom(url.searchParams.get("redirect"), url.origin),
});
for (const cookie of cookies) headers.append("Set-Cookie", setCookieFrom(cookie));

return new Response(null, { status: 302, headers });
```

- **`login()` は `Set-Cookie` を作らない。** 返る `headers` は**リクエスト用の `cookie:`** である。`cookies`(`TestCookie[]`)から自分で組む —— この構成で書く唯一の接着剤。
- **`Domain` を載せない。** 同一オリジンへ返すので host-only にする。
- **`Response.redirect` を使わない。** ヘッダを変えられないので `Set-Cookie` を載せる先が無い。

## 3. 使う側 3つ

| 使う側              | 叩き方                                                      |
| ------------------- | ----------------------------------------------------------- |
| ブラウザ・手作業    | `?as=owner&redirect=/orgs` → 302                            |
| Playwright の setup | `?as=owner&format=json` → `context.addCookies(res.cookies)` |
| HTTP 統合テスト     | 302 を `fetch` して `set-cookie` を拾う                     |

**`TestCookie` は `addCookies()` の入力と同じ形をしている。** `format=json` を足すのはそのためで、Playwright 側に変換コードが要らなくなる(他の2つを選んだなら、返す形は自分で決める)。

統合テストは**この URL を叩く**。入口そのものがテストで踏まれるので、腐ったまま気づかない状態にならない。**戸の開閉はハーネスを立てるときに決まるので、開いた側と閉じた側は必ずファイルが分かれる。**

## 4. 戸を閉じる

**実行時の環境変数1つで開く形にしない。** 開いた先が「誰にでもなれる」ので、デプロイ先の設定ミス1回と釣り合わない。

| 戸       | 何で閉じるか                        | どこに書くか                             |
| -------- | ----------------------------------- | ---------------------------------------- |
| ビルド時 | `import.meta.env.PROD` / `NODE_ENV` | **呼び出し側(ルーター)の import を畳む** |
| 実行時   | 環境変数(`ALLOW_DEV_BYPASS` など)   | ハンドラの先頭                           |

**ビルド時の戸をハンドラの中に書かない。** そこで分岐しても、そのモジュールは束に残る —— 畳みたいのは `auth-dev.ts` と testUtils そのものである。

**閉じているときは 404 を返す。403 は「その場は在る」と教えてしまう。**

## 5. 閉まっていることを検査する

**ソースではなく成果物を見る。** テストは「戸の開いたビルド」を一度作るので、ソースを見る検査は何も守らない。デプロイの手前に `build → 出力の .js を全部 grep` を挟む。

- **testUtils なら目印は `"test-utils"`。** プラグイン id が文字列としてそのまま束に残るので、自前のマーカーを用意しなくていい。
- **他の2つなら目印を自分で置く。** `const WARNING = "…"` をソースに置き、**検査側はその値をソースから読み出す** —— 検査に同じ文字列を書くと、文言を変えた日に黙って必ず緑になる。
- **1ファイルではなく出力を全部見る。** 束は分割されうる。
- **「在ること」も見る。** 目印が無いことだけを見る検査は、成果物が空でも認証ごと落ちても緑になる。本番の入口を示す文字列が在ることを同時に確かめる。

**完了基準: 素のビルドで検査が緑、戸を開けたビルドで赤になることを、両方走らせて確かめたこと。**

## 6. 着地先を検証する — 先頭2文字では足りない

`?redirect=` を素通しすればオープンリダイレクトになる。**そして素直な検査は破れる。**

```ts
// これは通ってしまう
url.startsWith("/") && !url.startsWith("//") && !url.includes("\\");
```

`?redirect=/%09/evil.example` は `/\t/evil.example` に復号され、上の3条件すべてを満たす。**URL パーサはタブ・LF・CR を位置に関わらず取り除く**ので、解決すると `http://evil.example/` になる。

解決してから origin を比べ、**組み立て直したものを返す**:

```ts
function landingFrom(raw: string | null, origin: string) {
  if (raw === null) return "/";
  let resolved: URL;
  try {
    resolved = new URL(raw, origin);
  } catch {
    return "/";
  }
  if (resolved.origin !== origin) return "/";

  return `${resolved.pathname}${resolved.search}${resolved.hash}`;
}
```

## 7. 見つけられるようにする

**どこからもリンクしない。** アドレスバーに打てることが存在理由で、UI に出すと本番で消し忘れる面が増える。代わりに **dev サーバーの起動バナーに1行出す。** バナーは値を出さず、**開いているか閉じているかだけ**を出す。

## 先行例

**手が止まったとき**に [`PRIOR-ART.md`](PRIOR-ART.md) を開く —— 戸の閉じ方、シードの持たせ方、着地先の検証を、動いている実装2つで見られる。**どちらも testUtils を使っていない**ので、2. の代わりにはならない。
