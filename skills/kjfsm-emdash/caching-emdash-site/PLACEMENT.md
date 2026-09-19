# Worker を D1 primary の隣へ寄せる

[SKILL.md](./SKILL.md) の手順 1 の具体。

**primary の colo は D1 の GET API からは分からない** — `running_in_region` は `"APAC"` までしか返さない。クエリ API で1本投げ、`meta` を読む:

```
POST /accounts/{account_id}/d1/database/{database_id}/query   {"sql": "select 1"}
→ meta.served_by_colo: "SIN", meta.served_by_primary: true
```

colo からリージョン値への対応表は、Placement のドキュメントにも無い。自分で当てる(SIN → `aws:ap-southeast-1`):

```jsonc
// wrangler.jsonc
"placement": { "region": "aws:ap-southeast-1" },
```

**止める場所は2つある。** `d1({ binding: "DB" })` から `session` を外すことと、D1 側の read replication を `disabled` にすること(API の `PATCH .../d1/database/{id}` に `{"read_replication": {"mode": "disabled"}}`、またはダッシュボードの Settings → Read replication)。後者は DB の設定なので、コードのデプロイでは変わらない。
