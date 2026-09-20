# oxlint で置き換えられる機械的チェック(kjfsm 配下、2026-09 時点)

問い: 最近動かしている kjfsm 配下のリポジトリで、スクリプトや grep で機械的に行っているチェックのうち、oxlint(組み込みルール・設定・JS プラグイン)で置き換えられるものはどれか。

調査日: 2026-09-17。対象は `~/github/kjfsm/` のうち 2026-09-09 以降に触られた、`package.json` を持つリポジトリ。oxlint の挙動は、npm の最新版 1.83.0 と、各リポジトリに入っている 1.81.0 / 1.70.0 で実際に動かして確かめた(§3)。

## ソース

| キー  | ソース                                                                                                                    | 日付 / 版                |
| ----- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `jp`  | [JS Plugins](https://oxc.rs/docs/guide/usage/linter/js-plugins.html)                                                      | docs(取得時点)           |
| `wjp` | [Writing JS Plugins](https://oxc.rs/docs/guide/usage/linter/writing-js-plugins.html)                                      | docs                     |
| `lt`  | [Linter overview](https://oxc.rs/docs/guide/usage/linter.html)                                                            | docs                     |
| `al`  | [Oxlint JS Plugins Alpha](https://oxc.rs/blog/2026-03-11-oxlint-js-plugins-alpha.html)                                    | 2026-03-11               |
| `d`   | [oxc Discussion #11649: no-restricted-syntax with custom selector?](https://github.com/oxc-project/oxc/discussions/11649) | —                        |
| `sch` | `node_modules/oxlint/configuration_schema.json` とネイティブバイナリ(kjfsm-auth、1.82.0)                                  | 1.82.0                   |
| `exp` | §3 の実験(スクラッチパッドで実施、リポジトリには残していない)                                                             | 1.83.0 / 1.81.0 / 1.70.0 |
| `cfg` | [Configuration](https://oxc.rs/docs/guide/usage/linter/config.html)                                                       | docs                     |
| `cli` | `oxlint --help`(live-note、1.82.0)                                                                                        | 1.82.0                   |

## 0. 答え

**oxlint に移す価値があるのは3本である。** ソースを正規表現で読むテストのうち、React/TS のソースだけを対象にする syoh-gi-genesys の `noHardcodedJapanese.test.ts`(§2.4)。そして circle-scheduler の `verification.md` にある rg のうち、`console.*` と生の日付パースの2本(§2.6)。 それ以外は、次の3つのどれかに当たるので置き換えられない、あるいは置き換えると検査が弱くなる。

1. **ソースではなく成果物(ビルド出力)を見ている** — `assert-door-closed.mjs` などは、そうする理由をコメントに明記している。
2. **JS/TS ではないもの(TOML・SQL・CSS・Markdown)が相手、あるいはファイルをまたいだ突き合わせをしている** — oxlint のルールは1ファイルずつ AST を見る。
3. **Astro のテンプレート部分に違反が現れる** — oxlint は `.astro` の `<script>` とフロントマターしか見ない [`lt`]。実際の違反はテンプレートの中にあった(§2.3)。

## 前提: 自作プラグインは使わない

自作のプラグインは管理の手間が大きいので、この調査は**組み込みルールと、既製の `oxlint-plugin-eslint` で書ける範囲**に限る。`oxlint-plugin-eslint` は oxc 本体のリポジトリ(`oxc-project/oxc` の `npm/oxlint-plugin-eslint`)から、oxlint と同じ版番号で公開されている。peerDependencies は無いので、**oxlint と同じ版に揃えて固定する**。仕組みは JS プラグインなので、アルファ版の制約(§1)はそのまま受ける。

## 1. oxlint 側で使えるもの(事実)

- **JS プラグインはアルファ版である。** "JS plugins are currently in alpha, and remain under active development." [`jp`] `jsPlugins` にはローカルのファイル(`"./plugin.js"`)も npm パッケージも書ける [`jp`][`wjp`]。ESLint と同じ API(`create`)と、oxlint 独自の `createOnce` がある [`wjp`]。セレクタ・`sourceCode.getText`・トークン・スコープ解析に対応している [`jp`]。テスト用の `RuleTester` は `oxlint/plugins-dev` から import する [`wjp`]。
- **制約。** カスタムのファイル形式とパーサー(Svelte・Vue・Angular)にはまだ対応していない。型情報を使う自作ルールも書けない [`jp`][`al`]。速度は "right now it isn't" [faster] とされている [`wjp`]。
- **`no-restricted-syntax` はネイティブに無い** — 1.82.0 のスキーマにある `no-restricted-*` は `exports` / `globals` / `imports` / `properties` だけで、バイナリにも `no-restricted-syntax` という名前は無い [`sch`][`d`]。**`oxlint-plugin-eslint` を JS プラグインとして入れると使える**("unlocks rules like `no-restricted-syntax` which are not yet implemented natively" [`al`])。ただし `eslint` というプラグイン名は予約されているので、別名を付ける必要がある: `{"name": "eslint-js", "specifier": "oxlint-plugin-eslint"}`。付けないと `Plugin name 'eslint' is reserved` で落ちる [`exp`]。
  → emdash-template-site の `test/themes/date-formatting.test.ts` にある「oxlint は `no-restricted-syntax` を持たない(実測)」は、ネイティブに限れば今も正しい。ただしプラグインを入れれば使える。
- **対応するファイル形式。** `.js/.mjs/.cjs/.ts/.mts/.cts` とその JSX 版。`.vue` / `.svelte` / `.astro` は "by linting only their `<script>` blocks" [`lt`]。
- **`no-restricted-imports` はすでに使っている**(musescore-linter-plugin、euphotter、circle-scheduler)。依存方向を強制する用途では、置き換えはもう済んでいる。

## 2. 棚卸しと判定

### 2.1 成果物を見るスクリプト — 置き換え不可

| リポジトリ                         | チェック                                                                                                      | 判定の理由                                                                                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| live-note / kjfsm-auth / euphotter | `scripts/assert-door-closed.mjs`                                                                              | ビルドした束に dev 用の戸が残っていないかを見る。ソースには戸が**在るのが正しい**ので、ソースを lint しても意味が無い(各スクリプトの冒頭に明記) |
| yorozu-discord-bot                 | `scripts/assert-no-dev-bypass.mjs`                                                                            | 同上                                                                                                                                            |
| live-note                          | `scripts/assert-client-only.mjs`                                                                              | pdf.js がサーバーの束に入っていないかを見る。問題は依存グラフが決まったあとに初めて分かる                                                       |
| musescore-linter-plugin            | `ci.yml` の `grep` 2本(`dist/assets/index-*.js` に `fetch(` など / `dist/index.html` にインライン `<script>`) | 束ねたあとの成果物が相手。依存ライブラリの中の `fetch` もここで初めて見える                                                                     |

### 2.2 JS/TS 以外が相手、またはファイルをまたぐ — 置き換え不可

| リポジトリ                        | チェック                                                                                | 理由                                                                                                                                                                                                            |
| --------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| circle-scheduler                  | `scripts/check-secrets.ts`                                                              | `wrangler.toml` と `.dev.vars.example` のキー集合を突き合わせる                                                                                                                                                 |
| euphotter                         | `ci.yml` の `git grep 'DROP TABLE'`、`src/db/migrations.test.ts`                        | SQL が相手                                                                                                                                                                                                      |
| kjfsm-site / emdash-template-site | `edge-cache.test.ts`                                                                    | `astro.config` の `routeRules` とページの木を突き合わせる                                                                                                                                                       |
| emdash-template-site              | `gallery/animation-bridge.test.ts`、`showcase/registry.test.ts`                         | TS と CSS を突き合わせる                                                                                                                                                                                        |
| syoh-gi-genesys                   | `boardColors.test.ts` / `komaColors.test.ts`                                            | TS の定数と `app.css` のトークンを突き合わせる                                                                                                                                                                  |
| live-note                         | `verification.md` の `comm` (`@base-ui/react` の部品が `optimizeDeps.include` にあるか) | `app/` 全体の import の集合と `vite.config.ts` を突き合わせる                                                                                                                                                   |
| circle-scheduler                  | `verification.md` のコミット件名の scope 禁止、スキーマ変更時の minor 上げ              | git の履歴と差分が相手                                                                                                                                                                                          |
| profile-book-generator            | `verification.md` の `grep '"baseUrl"' tsconfig*.json`                                  | JSON が相手(oxlint は JSON を lint しない)                                                                                                                                                                      |
| kjfsm-auth                        | `verification.md` の `ss` によるポート確認                                              | 実行環境が相手                                                                                                                                                                                                  |
| yorozu-discord-bot                | `e2e/responsive.spec.ts`                                                                | 描画結果が相手                                                                                                                                                                                                  |
| shift-scheduler                   | `.claude/hooks/block-migration-delete.sh`                                               | ファイルの削除という操作が相手                                                                                                                                                                                  |
| skills                            | `scripts/check-invariants.sh`                                                           | Markdown・JSON・YAML が相手                                                                                                                                                                                     |
| musescore-linter-plugin           | `checkers/tests/severityContract.test.ts`                                               | 宣言と出力が同じファイルにあるので1ファイルのルールでも**書けなくはない**。ただしこのテストは実行時の `ALL_CHECKERS` と実装ソースの対応(引き当て漏れ)も見ている。そこは lint に移せないので、テストのままでよい |

### 2.3 ソースを正規表現で読む Astro サイトのテスト — 書けるが、置き換えると弱くなる

| リポジトリ                                | テスト                           | 禁止しているもの                                          |
| ----------------------------------------- | -------------------------------- | --------------------------------------------------------- |
| euphoric-band-site / emdash-template-site | `content-access.test.ts`         | `getEmDashEntry(` / `getEmDashCollection(` の直接呼び出し |
| emdash-template-site                      | `themes/date-formatting.test.ts` | `toISOString().slice`                                     |
| euphoric-band-site                        | `pages/not-found.test.ts`        | `Astro.redirect("/404" \| href.notFound…)`                |
| euphoric-band-site                        | `pages/routes.test.ts`           | 内部 URL のリテラル(`"/blog/…"`、`` `${origin}/blog` ``)  |

どれもセレクタ1本か、数行の JS ルールで書ける。§3 では、`.ts` と `.astro` のフロントマターにある違反をすべて検出できた。**ただし `.astro` のテンプレート部分(`---` の外にある `{…}` や `href="/blog/…"`)は検査されない** [`lt`][`exp`]。実際、emdash-template-site で `date-formatting` の違反を消したコミット 499e638 が削った行は、次のように全部テンプレートの中にあった。

```
-                {post.data.publishedAt?.toISOString().slice(0, 10) ?? ""}
-    <LabelEn>{published?.toISOString().slice(0, 10) ?? ""}</LabelEn>
```

`routes.test.ts` が見ている `href="/…"` も、主にテンプレートに書かれる。これらを oxlint に移すと、いちばん違反が出やすい場所が素通りになる。したがってテストのまま残す。`.astro` を持たない層(`src/lib/*.ts`、API ルートの `.ts`)だけを lint に移すと、同じ規則を2か所で持つことになる。得られるのは、エディタ上で早く気づけることだけである。

### 2.4 置き換えを勧めるもの — syoh-gi-genesys `app/i18n/test/noHardcodedJapanese.test.ts`

- 対象は `app/` の `.ts` / `.tsx` だけで、`.astro` は無い。テストは手書きの字句解析(コメントと文字列の区別)を約50行持っているが、AST を見れば同じことが正確にできる。**自作ルールは要らない。** `eslint-js/no-restricted-syntax` に次の3本のセレクタを並べれば足りる(§7 で、1.70.0 と 1.83.0 のどちらでも検出を確認した)。コメントは AST に現れないので、除外する処理も要らない。

  ```json
  { "selector": "Literal[value=/[\\u3040-\\u30ff\\u4e00-\\u9fff]/]", "message": "…" },
  { "selector": "TemplateElement[value.raw=/[\\u3040-\\u30ff\\u4e00-\\u9fff]/]", "message": "…" },
  { "selector": "JSXText[value=/[\\u3040-\\u30ff\\u4e00-\\u9fff]/]", "message": "…" }
  ```

  文字クラスはテストが今使っている範囲に合わせること。上はかな・カナ・CJK 統合漢字だけである。

- 手書きの字句解析では取りこぼしがある。正規表現リテラル(`/「/`)や、JSX 属性の中の引用符の扱いは AST に任せたほうが正しい。
- **ALLOWLIST** は、oxlint の `overrides` でそのファイルだけルールを `off` にする形に移せる。ただし、テストが持つ「ALLOWLIST に実在しないファイルが残っていない」「直ったのに ALLOWLIST に残っている」の2検査は、oxlint では表せない。`reportUnusedDisableDirectives` が効くのはインラインの `// oxlint-disable` だけである。**ALLOWLIST を減らす方向にしか動かさない規律を保つには、ALLOWLIST を `overrides` ではなくインラインの `oxlint-disable` にし、`options.reportUnusedDisableDirectives: "error"` を立てる**(euphotter が既に立てている)。こうすると、直したのに消し忘れた disable がエラーになる。
- **注意:** `no-restricted-syntax` はルール1つに全セレクタを持つ。`overrides` で同じルールを書き直すと置換される(circle-scheduler の設定冒頭のコメント)ので、日付と日本語のセレクタを同じファイル群に当てるときは1つの配列にまとめる。

### 2.5 ついで: 併用している ESLint

tsunagari-tai-app(`eslint-plugin-drizzle`、`eslint-plugin-tailwindcss`)と syoh-gi-genesys(`react-hooks`、`react-refresh`)は、oxlint のあとに ESLint を走らせている。これは問いの対象(スクリプトや grep)の外である。`react-hooks` は JS プラグインの互換確認済みリストに入っている [`jp`]。ほかは未検証である。

### 2.6 circle-scheduler の `verification.md` にある rg — 置き換え可

| チェック                                                                             | 判定   | 置き換え先                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------ | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rg 'console\.(log\|warn\|error)' app/lib/.server app/db app/domain -g '!logger.ts'` | 可     | **組み込みの `no-console`** を `overrides` で3つのディレクトリに当て、`app/db/logger.ts` は後ろの override で `off` にする。実験で、ドットで始まる `app/lib/.server/` も検査されることを確かめた [`exp`]。`no-console` は `info` や `debug` も止めるので、rg と同じ範囲にするなら `allow` に並べる |
| `rg 'new Date\("[0-9]{4}-' app workers`(テスト除く)                                  | 可     | 組み込みには無い。`eslint-js/no-restricted-syntax` のセレクタ `NewExpression[callee.name='Date'] > Literal[value=/^\d{4}-/]` か、`Literal.arguments` を付けて引数の位置に絞る(§7 で検出を確認)。テストは `ignorePatterns` ではなく override で外す                                                 |
| `rg '^\s*reporters:' vitest.config.ts`                                               | 一部可 | `vitest.config.ts` だけの override でプロパティ名 `reporters` を禁止できる。ただし設定ファイル1本のために JS プラグインを入れる得は小さい                                                                                                                                                          |
| `rg '"dot"' playwright.config.ts`                                                    | 一部可 | 同上。しかも守りたいのは「reporter を**明示している**こと」で、`dot` が無いことはその代理にすぎない。lint にしても代理のままである                                                                                                                                                                 |

2本とも現時点の hit は 0 なので、ルールを入れてもすぐには違反が出ない。いまの rg は「差分が触れているものだけ実行する」手作業で、CI には載っていない。oxlint に移す得は、手作業のチェックが `pnpm lint`(= CI と lefthook の `pnpm check`)に入ることにある。

## 3. 実験(自作プラグインを含む。前提の変更で参考扱い)

`oxlint@1.83.0` と `oxlint-plugin-eslint@1.83.0` を入れた空のディレクトリに、ローカルのプラグインを1つ置いて試した。ルールは4本で、`no-direct-cms`・`no-sliced-iso`・`no-redirect-404` はセレクタで、`no-hardcoded-ja` は `Literal` / `TemplateElement` / `JSXText` の訪問で書いた。これに `eslint-js/no-restricted-syntax` を加えた。

- `a.ts`: 検出したのは `toISOString().slice`(自作ルールと `no-restricted-syntax` の両方)、`getEmDashCollection(`、テンプレートリテラルの日本語。**無視した**のは `typeof getEmDashCollection` と、コメント内の日本語。
- `b.tsx`: JSX テキストの日本語を検出した。
- `p.astro`: フロントマターの3種と、`<script>` 内の日本語を検出した。**テンプレートの `<p>日本語 {new Date().toISOString().slice(0,10)}</p>` は、どちらも検出しなかった。**
- リポジトリに入っている 1.81.0(emdash-template-site)の本体でも、結果は同じだった。1.70.0(syoh-gi-genesys)の本体でも、ローカルのプラグインは動いた。

## 4. 版と設定の形式

| リポジトリ             | 最終コミット | 指定 / 実際に入っている版 | 設定               | lint スクリプト                       |
| ---------------------- | ------------ | ------------------------- | ------------------ | ------------------------------------- |
| live-note              | 2026-09-14   | ^1.82.0 / 1.82.0          | `.oxlintrc.json`   | `oxlint`                              |
| euphotter              | 2026-09-12   | ^1.80.0 / 1.80.0          | `.oxlintrc.json`   | `oxlint`                              |
| circle-scheduler       | 2026-09-12   | ^1.77.0 / 1.78.0          | `oxlint.config.ts` | `oxlint`                              |
| shift-scheduler        | 2026-09-12   | ^1.79.0 / 1.79.0          | `.oxlintrc.json`   | `oxlint`                              |
| tsunagari-tai-app      | 2026-09-12   | ^1.69.0 / 1.72.0          | `.oxlintrc.json`   | `oxlint && eslint .`                  |
| yorozu-discord-bot     | 2026-09-11   | ^1.81.0 / 1.81.0          | `.oxlintrc.json`   | `oxlint`                              |
| kjfsm-auth             | 2026-09-09   | ^1.82.0 / 1.82.0          | なし               | `oxlint --deny-warnings`              |
| euphoric-band-site     | 2026-09-09   | ^1.81.0 / 1.81.0          | `.oxlintrc.json`   | `oxlint --type-aware --deny-warnings` |
| profile-book-generator | 2026-09-08   | ^1.81.0 / 1.81.0          | `.oxlintrc.json`   | `oxlint`                              |

- **`oxlint.config.ts` と `.oxlintrc.json` の違い。** TS 版は Node 版の `oxlint` パッケージと、TS を実行できる Node(v22.18+ か v24+)が要る。単体バイナリでは使えない [`cfg`]。CLI のヘルプは JS/TS の設定を experimental としている [`cli`]。1つのディレクトリにはどちらか一方しか置けない [`cfg`]。**npm パッケージの設定を import できるのは TS 版だけ**である("Package imports are not supported in the `.oxlintrc.json` format" [`cfg`])。circle-scheduler が TS 版を選んだのは、overrides が同じルールをマージせず置換するので、共通の禁止を関数で必ず差し込むためである(同ファイルの冒頭コメント)。
- **`--deny-warnings`。** 警告でも非 0 で終わる [`cli`]。JS プラグインのルールも、重大度は設定側で決まるので扱いは組み込みと同じである。ルールを `"error"` で書けば、`--deny-warnings` の無いリポジトリでも CI で止まる。`--report-unused-disable-directives` も CLI にある [`cli`]。§2.4 の除外リストを減らす方向にしか動かさないために使う。
- **JS プラグインを入れると、`oxlint` が Node で動くことが前提になる**(pnpm から呼ぶ限り、どのリポジトリも既にそう)。

## 5. 二段にする意味(ソースの lint + 成果物のチェック)

**dev 用の入口(戸)には無い。** ソースに戸が在るのは正しい。問題になるのは、戸を塞ぐ条件分岐(`import.meta.env.DEV` など)が本番ビルドで消えずに残る場合で、その判定はバンドラーの定数畳み込みと tree-shaking の結果でしか分からない。ソースに「戸は必ず `if (import.meta.env.DEV)` の中に置く」という lint を足す案はある。しかしそれは成果物のチェックが既に捕まえるものの一部を、早く赤くするだけである。戸の置き場所は各リポジトリで1〜2か所なので、早くなる分に見合わない。

**pdf.js(`assert-client-only`)には、少しだけある。** `no-restricted-imports` で「サーバーから到達するファイル(`*.server.ts`、loader/action を持つ route)は `pdfjs-dist` を import しない」と書けば、直接の import はエディタの上で赤くなる。ただし、間接の import(クライアント用のモジュールを経由して引き込む形)は捕まえられない。成果物のチェックは外せない。直接の import で実際に事故が起きてから足せば足りる。

## 6. 共有できるか

- **共有する価値のあるルールは、いま無い。** 複数のリポジトリに共通するのは成果物のチェック(`assert-door-closed` 系の4本)だけで、これは oxlint の外にある。これを共有するなら、置き場所は `dev-bypass-sign-in` スキルに、スクリプトの雛形として置くのが素直である。oxlint の共有設定ではない。
- **oxlint の設定を npm パッケージで配る形は、`.oxlintrc.json` では取れない** [`cfg`]。配るなら TS 版の設定へ移す必要がある。9本中8本が JSON なので、そのための移行の方が大きい。
- **`setup-skills` で配る形にするなら、ルールではなく判定基準の方である。** `verification.md` の「カスタムチェック」に rg を書く前に、「ソースの JS/TS を1ファイルで見るなら、まず `.oxlintrc.json` のルール(組み込み → `eslint-js/no-restricted-syntax` の順。自作プラグインは作らない)にできないか考える」という1行を置く。circle-scheduler の2本は、この1行があれば最初から lint になっていた。

## 7. 実験(既製ルールだけ)

`oxlint` と `oxlint-plugin-eslint` を同じ版(1.83.0 と 1.70.0 の2組)で入れた空のディレクトリで、自作ルールを使わずに試した。

- `app/a.tsx` で、`no-restricted-syntax` が検出したのは次の5件である: 文字列リテラルの日本語、テンプレートリテラルの日本語、`new Date("2026-01-01")`、JSX テキストの日本語、JSX 属性の日本語。**無視した**のは、コメントの日本語、`"hello"`、`new Date(Date.now())`。
- `vitest.config.ts` に限った override の `Property[key.name='reporters']` が、`reporters` を検出した。
- 組み込みの `no-console`(1.82.0)を `overrides` で `app/db/**` などに当て、`app/db/logger.ts` だけ `off` にした。検出されたのは対象ディレクトリのファイルだけで、`app/lib/.server/` のようにドットで始まるディレクトリも検査された。
- `oxlint` をディレクトリ指定なしで走らせると `node_modules/oxlint-plugin-eslint` の中まで lint して警告が大量に出た。ただしこれはスクラッチに `.gitignore` が無かったためで、実際のリポジトリでは起きない。
