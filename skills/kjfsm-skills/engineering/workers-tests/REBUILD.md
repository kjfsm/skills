# 既存のスイートを立て直す

[SKILL.md](SKILL.md) の共通の規律に加えて、すでにあるスイートが重い・複雑・信用できないときに決めること。直すべき対象がテストとは限らない — 多くの場合、テストの歪みはプロダクションコードの設計が漏れ出したものである。

## vitest.config の複雑さは症状であって病気ではない

`projects` が増えていたら、まず **なぜ分かれているのか** を 1 つずつ言葉にする。ランタイムの違い([SKILL.md](SKILL.md))で説明できない分かれ目は、ほぼ **モックの都合** である。設定を整理しても症状しか消えない。

Workers で元凶になるのは、ほぼ次の 2 つである。

- **どこからでも env を取れるグローバルアクセサ**（`getEnv()` のようなもの）
- **アプリ層からの `cloudflare:workers` の直 import**

このどちらかがアプリ層にあると、それを触るモジュールはすべて workerd を要求するか、`vi.mock` を要求する。1 つ消すだけで連鎖ごと消えることがある。**設定の行数ではなく `vi.mock` の本数を減らす方向に投資する。**

消したあとは lint で固定する。`no-restricted-imports` で `app/**` からの `cloudflare:workers` を禁止し、**そのルールが実際に発火することをダミーファイルで確かめる**（設定しただけで効いていないことがある）。

env の受け取り方は経路ごとに決めておく。

| 経路                         | 受け取り方                                               |
| ---------------------------- | -------------------------------------------------------- |
| route の loader/action       | context 経由（React Router v8 なら `createContext`）     |
| サーバー専用モジュール       | 引数。必要なバインディングだけを `Pick<Env, "...">` で   |
| queue / scheduled / DO alarm | ハンドラ自身と同型の `(args, env, ctx)` 引数渡し         |
| `waitUntil`                  | `ctx.waitUntil`（`cloudflare:workers` のものは使わない） |

`ctx.waitUntil` 経由にしておくと、テスト側の fake ctx が promise を捕まえて「積んだか」だけでなく「完了まで到達したか」を await 検証できる。

## 消す前に棚卸しする

スイートを作り直すと決めたら、消す前に **各テストが何を守っていたか** を 1 行ずつ書き出す。名前ではなく守っていた不変条件を書く — 「過去にこの事故があった」「この設計判断を固定していた」まで含める。

`prune-tests` スキルの棚卸し表がそのまま使える — 列「守っている不変条件」が棚卸しで、`削除` の行が「復元しない」の候補になる。

この表が作り直しのバックログになる。各行に「復元した」か「復元しない（理由）」が付くまでが完了である。テストの本数は復旧の目安にならない — 本数が戻っても、守っていたものが戻ったかは別の話である。

**復元の基点となるコミットを表に書いておく。** `git show <基点>:<パス>` でいつでも読める。

## 書き直すより、履歴から復元して直す

作り直しというと全部書き直したくなるが、**旧テストの検証内容そのものは資産**である。捨てるべきは構造（重複・肥大）であって、内容ではない。判断はディレクトリ単位で行う。

- **復元する** — 検証内容が具体的で、1 テスト 1 主張になっているもの。データ層・境界値・実挙動の確認が該当する。実 D1 や Durable Object を使うテストはここに来ることが多い
- **書き直す** — 同じ判定を何度もコピーしているもの。典型は全 route に「権限が無ければ 403」を貼り付けた層。判定は最も内側で 1 回検証し、外側は配線だけを見る形に畳む

実 D1 のテストは、多くの場合 **import の付け替えだけで動く**。復元してみて落ちたら、そこが現構成との差分である。

## バージョン移行で必要になる機械的な修正

パッケージを上げたとき、あるいは古いスイートを復元したときに当たるもの。

- **パッケージ名が `@cloudflare/vitest-pool-workers` から `@cloudflare/vitest-plugin` に変わった**（v1）。依存名・import・tsconfig の `types` エントリの3か所を直す。`npx @cloudflare/codemods vitest:pool-workers-to-vitest-plugin` が3つとも書き換える。**`cloudflare/workers-sdk` 側の fixture ディレクトリも `fixtures/vitest-plugin-examples/` に改名されている** — 旧パスを叩くと 404 が返るだけなので、レシピが見つからないときはまずここを疑う
- **`cloudflare:test` の `env` / `SELF` は非推奨** → `cloudflare:workers` の `env` / `exports.default.fetch()`。ドキュメントのページにはまだ非推奨の記載がないので、型定義を見て判断する
- **`defineWorkersProject` は `cloudflareTest()` プラグインに置き換わった**（v0.13）。`plugins: [cloudflareTest({ wrangler: { configPath } })]` の形になる
- **ストレージと Durable Object の分離が「テストごと」から「テストファイルごと」に変わった**（v0.13）。同じ `idFromName` を使い回すと前のテストの状態が残る。公式 fixture と同じく `crypto.randomUUID()` を混ぜて毎回別のインスタンスを引くか、`afterEach` で `reset()`（全バインディングのデータを削除）/ `abortAllDurableObjects()`（インスタンスのみリセット・永続データは残す）を呼ぶ
- **request-scoped なストアの中身が変わっていれば、テスト用ヘルパーの引数も直す**（`AsyncLocalStorage` に env を積むのをやめた、など）

## 実 D1 の足場は、公式 d1 レシピの形にする

マイグレーションの **読み込みは Node 側（config）、適用は workerd 側（setup ファイル）** に分かれる。

```ts
// vitest.config.ts — readD1Migrations は @cloudflare/vitest-plugin から
const migrations = await readD1Migrations(path.join(import.meta.dirname, "migrations"));
cloudflareTest({
  wrangler: { configPath: "./wrangler.toml" },
  miniflare: { bindings: { TEST_MIGRATIONS: migrations } }, // テスト専用バインディング
});
```

```ts
// setupFiles に指定するファイル
await applyD1Migrations(env.DB, migrations);
```

setup ファイルは **テストファイル単位のストレージ分離の外** で走り、複数回実行されうる。`applyD1Migrations()` は未適用のものだけを当てるので無条件に呼んでよい。その裏返しとして **setup が書いた状態は実行をまたいでディスクに残る**。マイグレーションはそれでよいが、**seed を setup に置くとテスト間で累積する** — seed はテスト本体側に置く。

ファイル数が増えると setup の総時間が効いてくる。実測してから `fileParallelism` や適用の共有を検討する。
