# 本番に出す

**エージェントは本番へ手でデプロイしない。** 本番に出すのは main への push を受けた Workers Builds(Cloudflare の GitHub App)で、その連携はマージのあと人間がダッシュボードで繋ぐ。手で出すと、本番がマージ前のブランチのコードになる。マイグレーションとデプロイの順も崩れうる。PR 本文を無引用のヒアドキュメントで書いただけで、本文の「`pnpm db:migrate:remote` を先に、`pnpm run deploy` を後に」がコマンドとして実行され、デプロイだけが通ってテーブルの無いまま新しいコードが出たことがある。

ログインを入れたなら、各段に [ACCOUNT.md](ACCOUNT.md) の「本番」の分を足す。

## 1. PR を出す(エージェント)

lefthook の pre-push で検証ゲートが全部回る。GitHub Actions の CI は、支払いの状態によっては始まらない。そのときにマージを止めるのは pre-push だけである。

完了基準: PR が出て、pre-push が通った。

## 2. 繋ぐ(人間)

PR をマージしたあと、ダッシュボードで Workers Builds を繋ぐ。Workers & Pages → `<app>` → Settings → Build → Connect。Worker がまだ無ければ、Create → Import a repository で作りながら繋ぐ。

| 項目                               | 値                      |
| ---------------------------------- | ----------------------- |
| リポジトリ / ブランチ              | `kjfsm/<repo>` / `main` |
| Build command                      | `pnpm run build`        |
| Deploy command                     | `npx wrangler deploy`   |
| API token                          | 既存の build token      |
| Builds for non-production branches | 下記                    |

non-production branches を入れると、PR ごとに `npx wrangler preview` が走り、PR のチェックになる。`wrangler.jsonc` に `previews` ブロックが無いと落ちて赤くなる。入れるなら、コードが `env.<名前>` で引く Durable Objects のバインディングを `previews` にも宣言する(プレビューごとに別の DO の名前空間が立つ)。以後 DO を足すたびに両方へ足すことを、`wrangler.jsonc` を `paths:` に持つ rule に書く。宣言しないなら切る。

連携を人間の手順にしているのは、本番へ確認なしに流れる設定だからである。エージェントが Builds API でトリガーを作ろうとしても、auto mode の判定に止められる。GitHub App は kjfsm のアカウントに入っていて、新しいリポジトリも読める。Builds API の `config_autofill` が通れば、読めている。

続けて、Settings → Domains & Routes で `<app>.kjfsm.net` を付ける。ドメインを `wrangler.jsonc` の `routes` に書かないのは、ログインを入れた日に手元の dev で better-auth が 403 を返すからである(→ `/kjfsm-personal:connect-kjfsm-auth`)。

完了基準: 最初のビルドが成功し、カスタムドメインで開ける。

## 3. 確かめる(エージェント)

1. ビルドのログを読み、`wrangler deploy` が通ったことを見る。cloudflare-builds の MCP で `workers_builds_list_builds` → `workers_builds_get_build_logs`
2. 本番で、主な URL が 200、WebSocket の経路が upgrade なしで 426 を返すことを見る。Playwright で2台を同じ部屋に入れ、ping の往復を測る。売り買いのように本番に残るデータを作る E2E は、走らせる前に人間に決めてもらう(auto mode は止める)
3. 実機での確認(音・振動・画面の減光止め・操作の手触り)を人間に渡す

完了基準: 1 と 2 の証拠を貼り、3 を人間に渡した。
