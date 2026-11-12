# Personal

自分自身のセットアップに紐づいたスキルで、`kjfsm-skills` には昇格させず、別プラグイン `kjfsm-personal` で配る。自分の端末にだけ入れる:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-personal@kjfsm
```

<!-- catalog:begin -->

- **[build-browser-game](./build-browser-game/SKILL.md)** — スマホでも遊べるブラウザゲームを、kjfsm の構成(Workers・Durable Objects。要るならログインと D1)で新しく作って本番に出すまでの手順。「ゲームを作って」と頼まれたとき、リアルタイム対戦を Durable Objects で組むとき、放置や売り買いのように画面を閉じても進むゲームを DO に組むとき、ゲームの数(強さ・勝負の長さ)を調整するとき、対戦で幽霊の人・遅れて鳴る演出・誤った引き分けが出たときに使う。
- **[connect-kjfsm-auth](./connect-kjfsm-auth/SKILL.md)** — kjfsm のアプリに、共通の IdP kjfsm-auth(`auth.kjfsm.net`)の RP としてログインを付ける。kjfsm の新しいサービスに認証が要るとき(better-auth に email/password や Google を直接組む前)、`genericOAuth` で kjfsm-auth に繋ぐとき、RP のクライアントを `auth-kjfsm-cli` で作る・作り直すとき、RP のログインが `invalid_client`・404・`unable_to_get_user_info` で落ちるときに使う。
- **[kjfsm-shared-db](./kjfsm-shared-db/SKILL.md)** — 共有 D1(`kjfsm-shared-db`)にすでに相乗りしているリポジトリで、スキーマを変える・共有 D1 から抜けるときの規律。`wrangler.jsonc` が `kjfsm-shared-db` を bind しているリポジトリでマイグレーションを生成・適用するとき、そこで `drizzle-kit push` を叩きそうになったとき、共有 D1 のサービスを専用の D1 へ移す・畳むときに使う。新しいサービスは共有 D1 に入れない(専用の D1 を作る)。
- **[setup-cf-app](./setup-cf-app/SKILL.md)** — 新規の Cloudflare Workers フルスタックアプリを、GitHub のテンプレート `kjfsm/cf-workers-free-template`(Free プランに収まる Vite の React SPA + Hono の API Worker)を写して立ち上げる。テンプレートが見えなければ公式テンプレートから組む。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。

<!-- catalog:end -->
