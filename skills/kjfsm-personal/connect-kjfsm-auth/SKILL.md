---
name: connect-kjfsm-auth
description: kjfsm のアプリに、共通の IdP kjfsm-auth(`auth.kjfsm.net`)の RP としてログインを付ける。kjfsm の新しいサービスに認証が要るとき(better-auth に email/password や Google を直接組む前)、`genericOAuth` で kjfsm-auth に繋ぐとき、RP のクライアントを `auth-kjfsm-cli` で作る・作り直すとき、RP のログインが `invalid_client`・404・`unable_to_get_user_info` で落ちるときに使う。
---

# kjfsm-auth に RP を繋ぐ

kjfsm のアプリはパスワードも Google のクライアントも持たない。**better-auth の `genericOAuth` で kjfsm-auth の RP になる。** 認証だけを IdP に集め、グループ・組織・権限はアプリ側に残す。

一次情報源は kjfsm-auth のリポジトリ(`~/github/kjfsm/kjfsm-auth`、private)にある。このスキルは RP 側の **手順と順序** を持ち、各設定の理由の詳細はそちらに任せる。

- `docs/implementation-notes.md` の「RP 側」「RP を繋ぐときに詰まったところ」 — 下の各設定がなぜ要るか
- `docs/operations.md` の「クライアントを管理する」 — `auth-kjfsm-cli` の全オプション
- `CONTEXT.md` — IdP / RP / クライアント / ユーザー / アカウントの呼び分け

参考例は `~/github/kjfsm/live-note`(`app/lib/auth.server.ts`・`vite.config.ts`・`README.md`)。

**このスキルは IdP 自体を触らない。** kjfsm-auth のリポジトリで作業しているなら、そこの `docs/` が正で、このスキルは要らない。

## 0. 前提を揃える

- **RP は D1 を持つ。** better-auth の RP には `user` / `session` / `account` / `verification` が残る。kjfsm のサービスなら共有 D1 に置く → `/kjfsm-personal:kjfsm-shared-db`(prefix 付きの4テーブルを作るところまで)
- **4テーブルの日付列は `integer(name, { mode: "timestamp_ms" })` で持つ。** better-auth 1.7 の drizzle アダプタは Date をそのまま渡すので、text の列だと D1 が `D1_TYPE_ERROR` で落とす(better-auth #10816)
- **ログインが1周するかを試すだけの使い捨て RP** なら D1 は要らない。`memoryAdapter` で足りる(implementation-notes の「試すだけの RP」。本番では使えない)
- **手元のポートを固定する。** IdP は 8801、その devtools は 9801。既存の kjfsm アプリと被らない番号を `grep -rn 'port' ~/github/kjfsm/*/vite.config.ts ~/github/kjfsm/*/wrangler.jsonc` で探し、`strictPort: true` で固定する — 登録する `redirect_uri` にポートが入り、変わるとログインが落ちる

完了基準: RP の D1 に4テーブルがあり(または memoryAdapter)、手元のポートが1つに固定されている。

## 1. better-auth を組む

```ts
export const IDP_PROVIDER_ID = "kjfsm";

export function authOptions(env: Env, baseURL: string) {
  return {
    database: drizzleAdapter(createDb(env.DB), { provider: "sqlite", schema }),
    baseURL,
    secret: env.BETTER_AUTH_SECRET,
    emailAndPassword: { enabled: false },
    // 手元では IdP と同じ localhost に同居する。Cookie はポートを区別しないので、
    // 既定の名前のままだと互いのセッションを上書きし合う。
    advanced: { cookiePrefix: "<app>" },
    plugins: [
      genericOAuth({
        config: [
          {
            providerId: IDP_PROVIDER_ID,
            clientId: env.IDP_CLIENT_ID,
            clientSecret: env.IDP_CLIENT_SECRET,
            // discoveryUrl は使わない(better-auth #10999)。
            authorizationUrl: `${env.IDP_URL}/oauth2/authorize`,
            tokenUrl: `${env.IDP_URL}/oauth2/token`,
            userInfoUrl: `${env.IDP_URL}/oauth2/userinfo`,
            scopes: ["openid", "profile", "email"],
            pkce: true,
            // IdP はクライアントを client_secret_basic で登録する。既定の post だと token エンドポイントが弾く。
            authentication: "basic",
          },
        ],
      }),
    ],
  } satisfies BetterAuthOptions;
}

/** baseURL を要求の origin から決めるので、要求ごとに組む。開発・テスト・本番でホストが違う。 */
export function authFor(request: Request, env: Env) {
  return betterAuth(authOptions(env, new URL(request.url).origin));
}
```

`wrangler.jsonc` には本番の値を置き、手元だけローカルの IdP へ向け直す。

```jsonc
"vars": { "IDP_URL": "https://auth.kjfsm.net/api/auth" },
"secrets": { "required": ["BETTER_AUTH_SECRET", "IDP_CLIENT_ID", "IDP_CLIENT_SECRET"] },
```

向け直しは `@cloudflare/vite-plugin` の `config` で `vars.IDP_URL` を `http://localhost:8801/api/auth` に差し替える(live-note の `vite.config.ts`)。**`wrangler.jsonc` の方をローカルにしない** — `main` へのデプロイがダッシュボードの値を上書きして、本番のログインが壊れる。

- **ログインを始めるのは `auth.api.signInSocial({ body: { provider: "kjfsm", callbackURL } })`**(クライアントからなら `POST /api/auth/sign-in/social`)。`genericOAuth` は専用のエンドポイントを持たない
- **戻り先は `/api/auth/callback/kjfsm`。** `oauth2/` を挟むと 404

完了基準: 型チェックが通り、`authOptions` が上の設定を1か所で持っている(dev bypass を作るなら、同じ `authOptions` を使う)。

## 2. クライアントを登録する

クライアントは **環境ごとに1つ** — `redirect_uri` は完全一致で照合され、ワイルドカードは無い。手元と本番で2つ作る。`workers.dev` やプレビュー URL でログインしたいなら、そのホストの分も要る(Durable Object を持つ Worker にはプレビュー URL が作られない)。

`auth-kjfsm-cli` の実体は `~/github/kjfsm/kjfsm-auth/cli/auth-kjfsm-cli.ts`。PATH に無ければ `ln -s` する(operations.md)。**`auth login` はブラウザでの承認が要るので、未ログインなら人間に頼む。**

`client_secret` は作成と再発行の実行でしか取れず、CLI は **出口をちょうど1つ** 要求する。出口の無い `create` は何も作らずに落ちる。**`--show-secret` は使わない** — 会話ログに残り、消せない。

**手元**(ローカルの kjfsm-auth を `pnpm dev` しておく):

```sh
auth-kjfsm-cli --host http://localhost:8801 clients create --name <app> --type native \
  --redirect-uri http://localhost:<port>/api/auth/callback/kjfsm \
  --secret-file .dev.vars --env-prefix IDP_
```

`--type native` を落とすと、ループバックの `redirect_uri` が 400 で拒否される。

**本番**は、叩く前に人間の確認を取る(本番の IdP にクライアントが増える)。

```sh
auth-kjfsm-cli clients create --name <app> \
  --redirect-uri https://<app>.kjfsm.net/api/auth/callback/kjfsm \
  --exec "pnpm exec wrangler secret put IDP_CLIENT_SECRET --name <app>"
client_id=$(auth-kjfsm-cli --json clients list --redirect-uri https://<app>.kjfsm.net/api/auth/callback/kjfsm \
  | jq -er 'if length == 1 then .[0].client_id else error("クライアントが \(length) 件ある") end') \
  && printf %s "$client_id" | pnpm exec wrangler secret put IDP_CLIENT_ID --name <app>
openssl rand -base64 32 | pnpm exec wrangler secret put BETTER_AUTH_SECRET --name <app>
```

- **`--json` と `--exec` を一緒に付けない。** `--exec` の子の出力が stdout に混ざり、`client_id` を拾い損ねる。だから `client_id` は `list` で引き直す
- **`--exec` の子が落ちても、クライアントは残る。** 作り直さず、出力に出る `clients rotate-secret <client_id> --exec ...` でやり直す
- **`wrangler secret put` が「最新バージョンが未デプロイ」で拒否されたら `wrangler versions secret put`。** 反映にはデプロイが要る
- `BETTER_AUTH_SECRET` は IdP の値とは無関係の、この RP だけの値。手元と本番で別に作る
- **初回デプロイより先に入れる。** `secrets.required` が揃わないと deploy が upload で止まる。Worker がまだ無いと `secret put` が作成を対話で尋ねるので、止まったら人間に打ってもらう

完了基準: `clients list --redirect-uri <URL>` が環境ごとにちょうど1件を返し、`wrangler secret list --name <app>` に3本が並ぶ。

## 3. 1周させる

1. 手元: kjfsm-auth を `pnpm dev`(8801)、RP を `pnpm dev` し、ログインボタンから IdP → Google → 同意画面 → RP へ戻る
2. 本番: デプロイ後に同じ往復を1回

**同意画面は RP ごとに初回1回必ず出る。** 飛ばすクライアントは作れない(kjfsm-auth の ADR 0002)。スコープを1つ足すと、全ユーザーが同意を取り直す。

詰まったときの対応表:

| 症状                                                                              | 原因                                                                                                                                                                             |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invalid_client`(`client registered for client_secret_basic cannot use ..._post`) | `authentication: "basic"` が無い                                                                                                                                                 |
| `unable_to_get_user_info`                                                         | ID トークンに `email` が載っていない。IdP 側の `customIdTokenClaims` で解決済みのはずなので、RP の `scopes` に `email` があるかを見る。あれば IdP 側の退行(implementation-notes) |
| IdP で `redirect_uri` 不一致                                                      | 登録した URL とポート・ホスト・パスのどれかが違う(`clients list` で見る)                                                                                                         |
| 戻り先が 404                                                                      | `/api/auth/oauth2/callback/...` を使っている                                                                                                                                     |
| 戻った直後にセッションが無い                                                      | `cookiePrefix` が無い、または `localhost` と `127.0.0.1` を混ぜている                                                                                                            |
| 手元だけ 403                                                                      | `wrangler.jsonc` に custom domain の `routes` がある(下)                                                                                                                         |

**`routes` と手元の 403。** 素の `wrangler dev` は custom domain の `routes` があると Origin と Referer をその route のホストへ書き換え、better-auth が 403 を返す(kjfsm-auth で実測)。`@cloudflare/vite-plugin` の dev サーバーで同じことが起きるかは確かめていない。当たったら、`routes` を消してドメインをダッシュボードで付けるのが kjfsm-auth の選んだ回避である。

完了基準: RP の D1 に `user` 1行と `account` 1行(`providerId = 'kjfsm'`、`accountId` = IdP の `sub`)ができている。

**IdP 上の人を指すときは `account.accountId` で引く。** RP の `user.id` は RP が自分で振った別の値で、サービスを跨いで同じ人を表すのは IdP の `sub`(= IdP の `user.id`)だけである。特定の人だけを通す例は pensieve の `server/auth/auth.ts`(`OWNER_SUB`)。

## 4. E2E とエージェントのための入口

E2E もエージェントも、IdP と Google の往復の向こうでは動けない。**IdP を踏まずに座る入口は RP 側に作る**(kjfsm-auth の dev bypass は IdP 自身のためのもの)→ `/kjfsm-skills:dev-bypass-sign-in`。`authOptions` を本番と共有すること。

**1つの RP の D1 を、手元の IdP と本番の IdP の両方に繋がない。** 同じ email を名乗る別の発行元のアカウントが、1人のユーザーに束ねられる。やむを得ず繋ぐなら `account: { accountLinking: { disableImplicitLinking: true } }`。
