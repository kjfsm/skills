# 先行例

**どちらも `testUtils` を使っていない。** 片方はそれが存在する前に書かれ、もう片方は better-auth ではない。読む価値があるのは、**testUtils では埋まらない部分** —— 戸の閉じ方、シードの持たせ方、着地先の検証 —— である。

自分が選んだ経路の側だけ読めばよい。

## 本番の口を通す — euphotter (better-auth + Cloudflare Workers)

| 読むもの                         | そこにあるもの                                                            |
| -------------------------------- | ------------------------------------------------------------------------- |
| `src/server/dev-bypass.ts`       | 署名の無い id token の組み立て、内側からの `sign-in/social`、着地先の検証 |
| `src/server/auth.ts`             | `verifyIdToken` を外すビルド時の分岐と、その戸を1つに畳んだ理由           |
| `src/server/index.ts`            | 閉じているときに 404 を返す側の分岐(`auth.ts` と同じ式を**写してある**)   |
| `scripts/assert-door-closed.mjs` | 成果物を grep する検査。`pnpm deploy` が build と deploy の間に挟む       |
| `scripts/dev-banner.ts`          | 起動バナー。`.dev.vars` を読んで開/閉だけを出す                           |
| `tests/http/harness.ts`          | 統合テストが「開いた側」を既定の秘密にしている形                          |

`.dev.vars.example` と `docs/agents/verification.md` に、人間向けの説明と E2E からの叩き方がある。

**id token を偽造する部分は、testUtils を選ぶなら要らない。** 残りは要る。

**写経しない側**: この入口は所有権の取得と種データの投入も抱えている(`dev-seed.ts`)。これはこのアプリのドメインの都合なので、切り離して読む。

## 手で潜る — emdash CMS (自前の認証)

**emdash は better-auth を使っていない**(`arctic` + `@oslojs/*` + 自前の `@emdash-cms/auth`)。参考になるのは**形**であって書き方ではない。

入口は2つある。

| ルート                          | やること                                                                         |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `/_emdash/api/auth/dev-bypass`  | `users` を email で引き、無ければ role=50 で insert し、`session.set("user", …)` |
| `/_emdash/api/setup/dev-bypass` | 上に加えて seed の適用・`setup_complete` の記録・`?token=1` での PAT 発行        |

読みどころ:

- **戸は `import.meta.env.DEV` の1枚だけ**で、ハンドラの先頭で `403 FORBIDDEN` を返す。ビルド済みのインスタンスでは定数畳み込みで潰れるので、**ホストに関わらず本番では常に閉じている。**
- **`?token=1`** は Bearer 専用の口(MCP)のための PAT を同じ入口で発行する。**同じ名前の古いトークンを消してから作り直す** —— 生のトークンは作成時にしか読めないので、溜めずに作り直すほうが使える。
- **`?content=0`** でスキーマだけ入れ、サンプルコンテンツを飛ばす。**種の量を呼ぶ側が選べる**のは、E2E が固定の件数を数えるときに効く。
- **リダイレクトは 302 ではなく meta refresh の HTML** を返す。セッションが保存し切ってから遷移させるため、とコメントにある。
- **`isSafeRedirect` は `startsWith("/") && !startsWith("//") && !includes("\\")` である。** SKILL.md の 6. がこれを破っている —— **先行例をそのまま写さない理由がここにある。**

### ソースの取り出し方(リポジトリが公開されていない)

`dist/` の `.map` に `sourcesContent` が入っているので、コメントごと原文が読める。

```bash
curl -sL "$(npm view emdash dist.tarball)" -o emdash.tgz
tar xzf emdash.tgz
node -e '
  const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(m.sourcesContent.join("\n"));
' package/dist/astro/routes/api/setup/dev-bypass.mjs.map
```

`tar tzf emdash.tgz | grep <探すもの>` で当たりを付ける。同じ手が `better-auth` / `@better-auth/core` にも効く。
