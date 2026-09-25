# 本番に出す

**エージェントは本番へ手でデプロイしない。** 本番に出すのは、main への push を受けた Workers Builds(Cloudflare の GitHub App)である。その連携は、main にマージしたあと人間がダッシュボードで繋ぐ。

game-01 では、最初はエージェントが手でデプロイしていた。そのせいで2つのことが起きた。

- **本番がマージ前のブランチのコードになった。**
- **マイグレーションより先に、新しいコードが出た。** PR 本文を無引用のヒアドキュメントで書いたため、本文の「`pnpm db:migrate:remote` を先に、`pnpm run deploy` を後に」がコマンドとして実行された。デプロイだけが通り、テーブルが無いまま新しいコードが出て、`/ranking` が 500 になった

## マージの前(エージェント)

どの手順も本番(共有 D1・本番の IdP・Cloudflare)に触る。始める前に、この節の一覧をユーザーに見せ、まとめて確認を取る。

1. 共有 D1 で slug が空いているかを読む → `/kjfsm-personal:kjfsm-shared-db` の手順 1
2. `openssl rand -base64 32 | pnpm exec wrangler secret put BETTER_AUTH_SECRET --name <app>` で secret を入れる。Worker がまだ無ければ、これが作る
3. 本番の IdP にクライアントを作り、残り2本の secret を入れる → `/kjfsm-personal:connect-kjfsm-auth` の手順 2。`redirect_uri` は `https://<app>.kjfsm.net/api/auth/callback/kjfsm`
4. PR を出す。本文には、最初のビルドが共有 D1 へ流すマイグレーションの SQL を載せる。マージのあとは、確認なしに流れるためである(→ `/kjfsm-personal:kjfsm-shared-db` の「スキーマを変える」)
   - lefthook の pre-push で検証ゲートが全部回る
   - GitHub Actions の CI は、支払いの状態によっては始まらない(game-01 で起きた)。そのときにマージを止めるのは、pre-push だけである

完了基準: `wrangler secret list --name <app>` に3本が並び、PR 本文に流れる SQL がある。

## マージのあと(人間)

5. PR をマージする
6. (エージェント)共有 D1 の Time Travel の bookmark と、`<slug>_` の外のスキーマを控える(→ `/kjfsm-personal:kjfsm-shared-db` の「スキーマを変える」)。次の連携で、最初のビルドがマイグレーションを流す
   - auto mode では、スキーマを読む `wrangler d1 execute --remote` が止められることがある(game-01 で起きた。bookmark は取れた)。止められたら別の手で読みに行かず、そのコマンドを人間に渡す。人間が控えないなら、流れる SQL の全文を読んで、触れる名前が全部 `<slug>_` で始まることを確かめてから進める
7. ダッシュボードで Workers Builds を繋ぐ: Workers & Pages → `<app>` → Settings → Build → Connect

   | 項目                  | 値                                                         |
   | --------------------- | ---------------------------------------------------------- |
   | リポジトリ / ブランチ | `kjfsm/<repo>` / `main`                                    |
   | Build command         | `pnpm run build && pnpm run check:door`                    |
   | Deploy command        | `pnpm db:migrate:remote && npx wrangler deploy`            |
   | API token             | `kjfsm-auth-app build token`(共有 D1 への適用に実績がある) |
   - デプロイのコマンドは、必ずマイグレーションを先にする
   - 「Builds for non-production branches」は切る。入れたままだと、PR ごとに `npx wrangler preview` が走り、`previews` ブロックが無いと落ちて、PR のチェックが赤くなる(game-01 で起きた)。Durable Objects を持つ Worker にはプレビュー URL が作られないので、入れておく得も無い
   - このトリガーは、エージェントが Builds API で作ろうとしても auto mode の判定に止められる。確認なしに共有 D1 へ流れる設定だからで、それゆえ人間の手順にしてある
   - GitHub App は kjfsm のアカウントに入っていて、新しいリポジトリも読める。Builds API の `config_autofill` が通れば、読めている

8. カスタムドメインを付ける: Settings → Domains & Routes で `<app>.kjfsm.net`。`wrangler.jsonc` に `routes` を置かない(手元の dev で better-auth が 403 を返す)

完了基準: 最初のビルドが成功し、カスタムドメインで開ける。

## 確かめる(エージェント)

9. ビルドのログを読む(cloudflare-builds の MCP で、`workers_builds_list_builds` → `workers_builds_get_build_logs`)
   - マイグレーションが流れ、`wrangler deploy` が通ったこと
   - 6 で控えたスキーマと比べ直して、`<slug>_` の外が変わっていないこと
10. 本番を確かめる
    - 主な URL が 200、`/dev/bypass` が 404、WebSocket の経路が upgrade なしで 426
    - `/login` への POST が、`auth.kjfsm.net/api/auth/oauth2/authorize` へ正しい `client_id`・`redirect_uri`・`S256` で送る。その URL を叩くと、IdP のサインイン画面へ 302 で送られる(`invalid_client` にならない)
    - Playwright で2台を同じ部屋に入れ、ping の往復を測る
11. 人間に渡す
    - 実機での確認(音・振動・画面の減光止め・操作の手触り)
    - IdP を通したログインの一巡(Google と同意画面は人間にしか通れない)
    - iOS のホーム画面(standalone)から開いたときのログインは未確認であることを伝える

完了基準: 9 と 10 の証拠を貼り、11 を人間に渡した。
