---
name: dev-bypass-sign-in
description: 叩くだけでサインイン済みになる開発・E2E 用の入口(dev bypass)を作る。better-auth や自前の認証を入れたアプリで、ログインの要る画面をエージェントやブラウザ自動化から駆動したいとき、E2E のセットアップでサインインを済ませたいとき、既存の bypass の戸が本番の成果物に残っていないか確かめたいとき、`?redirect=` のオープンリダイレクトを塞ぐときに使う。
---

# 開発用のバイパスサインイン

**サインインの要る画面は、人間が居ないと動かせない。** E2E も、ブラウザを持つエージェントも、`curl` も、外部 IdP のリダイレクトの向こうで止まる。バイパスはその往復を URL 1つに畳む。

**代償は「誰にでもなれる口」である。** だからこのスキルの重心は、作り方より **閉じ方** にある。

## 1. 経路を決める — 本番の口を通すか、下に潜るか

|          | 本番の口を通す                                              | 下に潜る                                        |
| -------- | ----------------------------------------------------------- | ----------------------------------------------- |
| やること | 認証ハンドラを内側から叩き、**署名の検証だけ**を外す        | `user` 行を直に insert し、セッションを直に張る |
| 通る経路 | Account 作成・セッション発行・Cookie の組み立ては本番と同じ | 認証ライブラリを一切通らない                    |

判定: **サインインの経路の中に、自分のロジックが載っているか。** 初回サインインで所有者を決める、招待を紐づける、匿名アカウントを繋ぎ替える —— 載っているなら通す。バイパスで通ったことが本番でも通る証拠になり、E2E がその分岐を踏める。

載っていない(認証はライブラリ任せで、目的は初期セットアップを飛ばすこと)なら潜ってよい。ただし **潜った入口が通っても、本番のサインインについては何も言えない。**

**完了基準: どちらを選んだかと、その理由を1行で言えること。**

## 2. better-auth で本番の口を通す

better-auth の social provider には id token での直サインインがある —— **ブラウザのリダイレクトが要らない唯一の口**である。

### 署名の検証だけを外す

```ts
socialProviders: {
  google: {
    clientId, clientSecret,
    ...(TRUSTS_UNSIGNED_ID_TOKEN ? { verifyIdToken: async () => true } : {}),
  },
}
```

`@better-auth/core` の `oauth2/verify-id-token.ts` が **provider の `verifyIdToken` をいちばん先に見る**ので、これがあると jwks も iss/aud も見に行かない。

### 署名の無い id token を組む

```ts
const header = base64url(JSON.stringify({ alg: "none", typ: "JWT" }));
const payload = base64url(
  JSON.stringify({
    iss: "https://accounts.google.com",
    aud: clientId,
    sub,
    email,
    email_verified: true,
    name,
  }),
);
const token = `${header}.${payload}.`; // 署名は空
```

**ピリオドで3つに割れる形は要る** —— 検証を外しても `provider.getUserInfo` がこのペイロードを読んで `user` を組む。`sub` が Account の同一性を決めるので、**固定すれば何度叩いても Account は1つ**である。

### 内側から叩く

```ts
const response = await auth.handler(
  new Request(`${origin}/api/auth/sign-in/social`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: origin },
    body: JSON.stringify({ provider: "google", idToken: { token } }),
  }),
);
const setCookies = response.headers.getSetCookie();
```

- **HTTP で自分自身へ往復させない。** 通る経路は変わらず、待ち時間だけが増える。
- **`Origin` を自分で付ける。** origin / CSRF の判定は Cookie ヘッダの有無や `Sec-Fetch-*` の有無で分岐し、版ごとに動く(`api/middlewares/origin-check.ts`)。付けておけば `INVALID_ORIGIN` も `MISSING_OR_NULL_ORIGIN` も踏まない。
- **応答の本文を JSON として読まない。** 貰った Cookie で `auth.api.getSession({ headers: { Cookie } })` をもう一往復するほうが版に強い。
- **`Response.redirect` を使わない。** あちらはヘッダを変えられないので `Set-Cookie` を載せる先が無い。`new Response(null, { status: 302, headers })` を組み、`headers.append("Set-Cookie", …)` する。

### `auth.api.*` はルーターを通らない

外向きの `/api/auth/sign-in/anonymous` をアプリ側で 404 に落としても、`auth.api.signInAnonymous()` は呼べる。**外から塞いだ口を内側からだけ使う**のはこの性質に乗っている。

## 3. 戸を閉じる

**実行時の環境変数1つで開く形にしない。** 開いた先が「誰にでもなれる」なので、デプロイ先の設定ミス1回と釣り合わない。

| 戸       | 何で閉じるか                        | 何が起きるか                          |
| -------- | ----------------------------------- | ------------------------------------- |
| ビルド時 | `import.meta.env.PROD` / `NODE_ENV` | **分岐そのものが成果物から消える**    |
| 実行時   | 環境変数(`ALLOW_DEV_BYPASS` など)   | 成果物を作らない dev サーバーに残る戸 |

**この2枚を別の値で開け閉めしない。** バイパスが張るセッションは署名を確かめないビルドでしか通らない id token に乗っているので、片方だけ開けても何も起きない —— それが正しい状態である。

**閉じているときは 404 を返す。403 は「その場は在る」と教えてしまう。**

better-auth 側にもう1枚ある: provider の `disableIdTokenSignIn: true` は id token の口そのものを閉じる(`verify-id-token.ts` が `verifyIdToken` より先に見る)。本番のサインインが OAuth リダイレクトだけなら、本番でこれを立てられる。

## 4. 閉まっていることを検査する

**ソースではなく成果物を見る。** テストは「戸の開いたビルド」を一度作るので、ソースを見る検査は何も守らない。デプロイの手前に `build → 出力の .js を全部 grep` を挟む。

- **目印はソースから読み出す。** 検査側にも同じ文字列を書くと、文言を変えた日に黙って必ず緑になる。`const WARNING = "…"` を正規表現で拾い、その値を探す。
- **1ファイルではなく出力を全部見る。** 束は分割されうるので、目印がチャンクへ移った日に緑になる形にしない。
- **「在ること」も見る。** 目印が無いことだけを見る検査は、成果物が空でも認証ごと落ちても緑になる。本番の入口を示す文字列(IdP の URL など)が在ることを同時に確かめる。

## 5. 着地先を検証する — 先頭2文字では足りない

`?redirect=` を素通しすればオープンリダイレクトになる。**そして素直な検査は破れる。**

```ts
// これは通ってしまう
url.startsWith("/") && !url.startsWith("//") && !url.includes("\\");
```

`?redirect=/%09/evil.example` は `/\t/evil.example` に復号され、上の3条件すべてを満たす。**URL パーサはタブ・LF・CR を位置に関わらず取り除く**ので、解決すると `http://evil.example/` になる(タブを CR/LF に替えても同じ)。

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

## 6. 冪等にする

**固定の Account に戻す。** 叩くたびに新しい Account を作ると、所有権や種データが動き、E2E は「setup で1度だけ叩く」形に縛られる。

**見てから書く。** 2度目以降が1バイトも書かないなら、テストの中から何度でも叩ける。

## 7. 見つけられるようにする

**どこからもリンクしない。** アドレスバーに打てることが存在理由で、UI に出すと本番で消し忘れる面が増える。

代わりに **dev サーバーの起動バナーに1行出す。** バナーは値を出さず、**開いているか閉じているかだけ**を出す。

## 8. 使う側から駆動する

- **ブラウザ / Playwright**: `/dev/bypass?redirect=/…` へ遷移する。セッションは Cookie で残るので、setup で1度叩けばよい。
- **curl**: `curl -sL -c cookies.txt "…/dev/bypass?redirect=/"` で Cookie を取り、以降 `-b cookies.txt` を付ける。
- **Bearer 専用の口(MCP・API)**: Cookie が効かないので、**同じ入口でトークンも発行させる**(emdash は `?token=1`)。同じ名前のトークンを消してから作り直すと、叩き直しても増えない。
- **統合テスト**: 秘密を「開いた側」で既定にし、閉じた側を見るファイルだけが言い直す。**戸の開閉はハーネスを立てるときに決まるので、開いた側と閉じた側は必ずファイルが分かれる。**

## 先行例を読む

2つの実装(better-auth を通すもの / 自前の認証の下を潜るもの)を実際に読むための場所と、npm にしか無い側のソースの取り出し方は [`PRIOR-ART.md`](PRIOR-ART.md)。
