# better-auth の `testUtils`

**1.5.0 で入った。** 1.4.x には無い。`TestHelpers` の型は 1.5.0 と 1.7.2 で1文字も変わっていないので、**版に強い部類**である。公式ドキュメントは [Test Utils](https://better-auth.com/docs/plugins/test-utils)。

```ts
import { testUtils } from "better-auth/plugins";

const ctx = await auth.$context;
const test = ctx.test;
```

**HTTP ルートを1本も生やさない。** helpers は `ctx.test` にしか出ないので、プラグインを入れただけでは外向きの穴は開かない —— 開くのは、それを叩くルートを自分で置いたときだけである。

## 生えるもの

| ヘルパー                                                                       | 返すもの / やること                          |
| ------------------------------------------------------------------------------ | -------------------------------------------- |
| `login({ userId })`                                                            | `{ session, user, headers, cookies, token }` |
| `getAuthHeaders({ userId })`                                                   | `Headers`(`cookie: <name>=<signed>`)         |
| `getCookies({ userId, domain? })`                                              | `TestCookie[]`                               |
| `createUser(overrides?)`                                                       | メモリ上の user オブジェクト(DB は触らない)  |
| `saveUser(user)`                                                               | `internalAdapter.createUser` で保存          |
| `deleteUser(id)`                                                               |                                              |
| `createOrganization` / `saveOrganization` / `addMember` / `deleteOrganization` | organization プラグインが居るときだけ生える  |
| `getOTP(identifier)` / `clearOTPs()`                                           | `captureOTP: true` のときだけ                |

## Cookie の中身

`createTestCookie` / `createCookieHeaders` が組むのは1つだけ:

```
<ctx.authCookies.sessionToken.name> = <token>.<HMAC-SHA256(token, ctx.secret)>
```

属性(`path` / `httpOnly` / `secure` / `sameSite` / `maxAge`)は `ctx.authCookies.sessionToken.attributes` から来る。**だから `cookiePrefix` も `secure` も本番の設定がそのまま効き、本番のインスタンスが受け取れる** —— 逆に、secret か Cookie 設定がずれた別インスタンスで作ると受け取られない。

`TestCookie` の形は **Playwright の `browserContext.addCookies()` の入力と一致する**:

```ts
{ name, value, domain, path, httpOnly, secure, sameSite: "Lax" | "Strict" | "None", expires }
```

## 落とし穴

**`login()` は `Set-Cookie` を作らない。** 返る `headers` はリクエスト用の `cookie:` である。302 に載せるなら `cookies` から自分で組む。

**`cookieCache` の `session_data` Cookie を出さない。** [issue #9271](https://github.com/better-auth/better-auth/issues/9271) が未解決。**致命的なのはアダプタ無しの完全ステートレス(JWE)構成だけ**で、DB アダプタがあれば `getSession` は写しが無いと DB を引く。ただしサーバー側で `auth.api.getSession` を呼ぶだけの経路は `Set-Cookie` を返さないので、**この Cookie で始めたテストは写しの経路を一度も通らない**(実測、1.7.14)。「失効が写しの寿命ぶん遅れる」ことを試すなら、本物のサインインの応答で始める。

**hooks の第2引数(エンドポイント文脈)が `undefined` になる。** `tryGetCurrentAuthEndpointContext()` は HTTP エンドポイントの外では空。`user.create.after` でリクエストを読んでいるなら、シードのときだけ挙動が変わる。**`ctx === null` で分岐しているフックは `undefined` を素通りし**、`getSessionFromCtx(undefined)` で `TypeError` を投げる —— `internalAdapter.createAccount` が `account.create.after` で落ちたのがこれである。`ctx == null` で見るか、`account` 行は drizzle で直に入れる。

**`saveUser` は `account` 行を作らない。** シードした人は「メールアドレスはあるが資格情報が無い」状態になるので、**あとで同じメールで本物のソーシャルログインを試すと、紐付けか衝突かで挙動が変わりうる。** dev で実物のサインインも試すなら、そのアカウントだけシードから外す。

**`createUser` の既定は `emailVerified: true`、email はランダム。** 固定したい値は必ず overrides で渡す。

## 成果物の外(Node)から使う

Worker に1行も足さずに座る形。テストや手元のスクリプトの Node プロセスに `testUtils()` 入りのインスタンスを立て、Worker と同じ保存先に `login()` する。発行した Cookie を Worker はそのまま受け取る(実測、better-auth 1.7.14 + `createTestHarness`。戸を閉じた成果物に対して 200)。

```ts
const base = authOptions({ db: createDb(env.DB), baseURL: workerOrigin, secret: SAME_SECRET, … });
const auth = betterAuth({ ...base, plugins: [...base.plugins, testUtils()] });
const test = (await auth.$context).test;

const user = await test.saveUser(test.createUser({ … }));
const { headers } = await test.login({ userId: user.id });
await fetch(`${workerOrigin}/api/…`, { headers: { cookie: headers.get("cookie") ?? "" } });
```

- **options は本番の関数から作る。** 書き起こすと `databaseHooks` が走らず、Cookie の設定もずれる。`saveUser` は `user.create` の、`login` は `session.create` のフックを before → 書き込み → after の順で通す。
- **`baseURL` は Worker が見ている origin と同じ値にする。** Cookie 名の `__Secure-` 接頭辞は、`useSecureCookies` → 要求の protocol → 静的 `baseURL` が `https://` か → `isProduction` の順で決まる。Node 側だけ https を渡すと名前が食い違い、Worker が拾わずに 401 になる。
- **Node 側が本番の設定とずれた瞬間に、黙って 401 になる。** 本番に `cookiePrefix`・`advanced.cookies`・`useSecureCookies`・`secondaryStorage` を足したら、Node 側にも同じ値が要る。
- **vitest の中では `import.meta.env.PROD` が偽になる。** `PROD` で畳んだ分岐を options に持っていれば、Node 側のインスタンスにはそれが載る。
- **ログインの記録は Worker 経由と同じ形にならない。** フックの文脈が無いのでプロバイダは分からず、`createSession` はヘッダが無いと IP と User-Agent に `null` ではなく空文字を入れる。
- **保存先の掴み方:** テストなら `createTestHarness` の `worker.getEnv()`。手元の dev サーバーなら `getPlatformProxy()` で、既定の保存先は Vite plugin と同じ `.wrangler/state` である。dev サーバーを動かしたまま同じ D1 に書けるかは確かめていない。

## ソースを読む場所

`node_modules/better-auth/dist/` 配下。**版ごとに動く挙動は、ドキュメントではなく解決済みの実体に訊く。**

| 確かめたいこと                         | ファイル                                        |
| -------------------------------------- | ----------------------------------------------- |
| helpers の実装と `ctx.test` の組み立て | `plugins/test-utils/index.mjs`                  |
| Cookie の署名と属性                    | `plugins/test-utils/cookie-builder.mjs`         |
| `saveUser` が何を通るか                | `plugins/test-utils/db-helpers.mjs`             |
| hooks が本当に走るか                   | `db/internal-adapter.mjs` → `db/with-hooks.mjs` |
| 型の全面                               | `plugins/test-utils/types.d.mts`                |
