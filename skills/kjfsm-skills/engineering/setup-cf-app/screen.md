# 画面の層

`SKILL.md` の手順3で画面の層に入ったら読む。

- データの取得は1エンドポイント = 1 `queryOptions`。loader は値を返さず `queryClient.query({ ...options, staleTime: "static" })` で待ち、コンポーネントは `useSuspenseQuery` で読む。loader の戻り値を `useLoaderData` で読む形にしないのは、戻り値が Query のキャッシュの外にあり、書き込みのあとの invalidate で取り直されないから。`ensureQueryData` / `prefetchQuery` は非推奨で、`queryClient.query` に置き換わった
- ログインが要るルートは `beforeLoad` で振り分ける。**表示の振り分けで、認可ではない** — 認可は API の middleware が強制する
- 画面が Worker から import するのは `AppType` の型だけにする(`import type`)。値を import すると、Worker 側の依存(Drizzle・better-auth)がクライアントのバンドルに入る
- TanStack Router は公式のエージェント向けスキルを依存に同梱している。`@tanstack/intent` を dev 依存に入れて読ませる — `intent install` が書く案内は、入っている `intent` を使い、無ければ取りに行かずに報告するよう指示する。**`intent install` より先に `package.json` の `intent.skills` を書く** — 無いと許可するパッケージを対話で訊き、TTY が無いところでは進まない。許可は `@tanstack/*` に絞り、`"*"` にしない。許可するのはパッケージで中身ではなく、範囲内の依存を上げるたびに読ませる内容は黙って変わる。`"*"` だと、構成が選んでいない依存(dotenv など)が同梱したスキルまでその対象になる
- `intent install` は `AGENTS.md`(無ければ作る)に `intent-skills` の区画を書く。Claude Code は `AGENTS.md` を直接読む(`CLAUDE.md` を置かない形を敷くのは `/kjfsm-skills:setup-repo`)。区画は書き直しても次の `intent install` で元の形に戻るので、生成物として扱う
- 区画の外に「公式のスキルとリポジトリの rules・ADR・`/kjfsm-skills:setup-cf-app` が食い違ったら、リポジトリに従う」と添える。公式は先読み(`defaultPreload`)を勧めるが、Worker の要求数を抑えるために意図して切っている。公式の記述が実装と合わない所もある(`from` 無しの `to="."` の解決。2026-10)
