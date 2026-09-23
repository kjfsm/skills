# Personal

自分自身のセットアップに紐づいたスキルで、`kjfsm-skills` には昇格させず、別プラグイン `kjfsm-personal` で配る。自分の端末にだけ入れる:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-personal@kjfsm
```

- **[connect-kjfsm-auth](./connect-kjfsm-auth/SKILL.md)** — kjfsm のアプリを、共通の IdP kjfsm-auth(`auth.kjfsm.net`)の RP にする。`genericOAuth` の設定、`auth-kjfsm-cli` での手元と本番のクライアント登録(secret を会話に出さない順序)、1周させたときの詰まりどころ。IdP 自体の運用は kjfsm-auth の `docs/` が持つ。
- **[edit-article](./edit-article/SKILL.md)** — セクションの再構成、明瞭さの向上、文章の引き締めによって記事を編集・改善する。
- **[kjfsm-shared-db](./kjfsm-shared-db/SKILL.md)** — kjfsm のアプリが相乗りする共有 D1 `kjfsm-shared-db` に入る・その中でスキーマを変える・抜ける。相乗りしないもの、prefix と `migrations_table` の決め方、`drizzle-kit push` の封じ方、DB 単位でしか戻せない Time Travel。判断の一次情報源は circle-scheduler の ADR 0025。
