# 本番に出す順

どの手順も本番(GitHub・共有 D1・本番の IdP・Cloudflare)に触る。始める前に、この一覧をユーザーに見せて、まとめて確認を取る。

1. ブランチを push して PR を出す。lefthook の pre-push で、検証ゲートが全部回る
2. 共有 D1 で slug が空いているかを読む → `/kjfsm-personal:kjfsm-shared-db` の手順 1
3. `openssl rand -base64 32 | pnpm exec wrangler secret put BETTER_AUTH_SECRET --name <app>`
   - Worker がまだ無ければ、これが作る(作成の確認の扱いは `/kjfsm-personal:connect-kjfsm-auth` の手順 2)
4. 本番の IdP にクライアントを作る → `/kjfsm-personal:connect-kjfsm-auth` の手順 2
   - `redirect_uri` は `https://<app>.kjfsm.net/api/auth/callback/kjfsm`
5. `pnpm db:migrate:remote` を流す → `/kjfsm-personal:kjfsm-shared-db` の「スキーマを変える」(bookmark と、適用前後の比較)
6. `pnpm run deploy`
7. カスタムドメインを付ける: `pnpm exec wrangler deploy --domain <app>.kjfsm.net` を1回だけ走らせる
   - 以後は `--domain` を付けずにデプロイしても外れない(Workers Domains の API で確かめた)
   - Cloudflare の MCP のトークンでは Workers Domains を書けない(`Authentication error`)
   - `wrangler.jsonc` に `routes` を置かない(手元の dev で better-auth が 403 を返す)
8. 本番を確かめる
   - 主な URL が 200、`/dev/bypass` が 404、WebSocket の経路が upgrade なしで 426
   - `/login` への POST が、`auth.kjfsm.net/api/auth/oauth2/authorize` へ正しい `client_id`・`redirect_uri`・`S256` で送る。その URL を叩くと、IdP のサインイン画面へ 302 で送られる(`invalid_client` にならない)
   - Playwright で2台を同じ部屋に入れ、ping の往復を測る
9. 人間に渡す
   - 実機での確認(音・振動・画面の減光止め・操作の手触り)
   - IdP を通したログインの一巡(Google と同意画面は人間にしか通れない)
   - PR のマージ(この時点の本番は、ブランチのコードで動いている)
   - iOS のホーム画面(standalone)から開いたときのログインは未確認であることを伝える
