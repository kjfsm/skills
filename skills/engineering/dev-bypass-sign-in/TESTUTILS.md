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

**`cookieCache` の `session_data` Cookie を出さない。** [issue #9271](https://github.com/better-auth/better-auth/issues/9271) が未解決。**致命的なのはアダプタ無しの完全ステートレス(JWE)構成だけ**で、DB アダプタがあれば最初の1リクエストが DB を引いてキャッシュを張り直すだけである。

**hooks の第2引数(エンドポイント文脈)が `undefined` になる。** `tryGetCurrentAuthEndpointContext()` は HTTP エンドポイントの外では空。`user.create.after` でリクエストを読んでいるなら、シードのときだけ挙動が変わる。

**`saveUser` は `account` 行を作らない。** シードした人は「メールアドレスはあるが資格情報が無い」状態になるので、**あとで同じメールで本物のソーシャルログインを試すと、紐付けか衝突かで挙動が変わりうる。** dev で実物のサインインも試すなら、そのアカウントだけシードから外す。

**`createUser` の既定は `emailVerified: true`、email はランダム。** 固定したい値は必ず overrides で渡す。

## ソースを読む場所

`node_modules/better-auth/dist/` 配下。**版ごとに動く挙動は、ドキュメントではなく解決済みの実体に訊く。**

| 確かめたいこと                         | ファイル                                        |
| -------------------------------------- | ----------------------------------------------- |
| helpers の実装と `ctx.test` の組み立て | `plugins/test-utils/index.mjs`                  |
| Cookie の署名と属性                    | `plugins/test-utils/cookie-builder.mjs`         |
| `saveUser` が何を通るか                | `plugins/test-utils/db-helpers.mjs`             |
| hooks が本当に走るか                   | `db/internal-adapter.mjs` → `db/with-hooks.mjs` |
| 型の全面                               | `plugins/test-utils/types.d.mts`                |
