# Personal

自分自身のセットアップに紐づいたスキルで、`kjfsm-skills` には昇格させず、別プラグイン `kjfsm-personal` で配る。自分の端末にだけ入れる:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-personal@kjfsm
```

<!-- catalog:begin -->

- **[connect-kjfsm-auth](./connect-kjfsm-auth/SKILL.md)** — kjfsm のアプリに、共通の IdP kjfsm-auth(`auth.kjfsm.net`)の RP としてログインを付ける。kjfsm の新しいサービスに認証が要るとき(better-auth に email/password や Google を直接組む前)、`genericOAuth` で kjfsm-auth に繋ぐとき、RP のクライアントを `auth-kjfsm-cli` で作る・作り直すとき、RP のログインが `invalid_client`・404・`unable_to_get_user_info` で落ちるときに使う。
- **[edit-article](./edit-article/SKILL.md)** — セクションの再構成、明瞭さの向上、文章の引き締めによって記事を編集・改善する。
- **[kjfsm-shared-db](./kjfsm-shared-db/SKILL.md)** — kjfsm のアプリが相乗りする共有 D1(`kjfsm-shared-db`)に入る・その中でスキーマを変える規律。kjfsm の新しいサービスに D1 が要るとき(`wrangler d1 create` を叩く前)、`wrangler.jsonc` が `kjfsm-shared-db` を bind しているリポジトリでマイグレーションを生成・適用するとき、共有 D1 からサービスを抜くときに使う。

<!-- catalog:end -->
