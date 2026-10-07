# 作った直後のサイトのやることリスト

テンプレートのコードが追いついていないかもしれない変更を、版ごとに並べる。サイトのコードか本番の設定に効くものだけで、管理画面だけで完結する変更は載せない。版で範囲を絞らず、全項目を判定する。

各項目は3つで書く:

- **判定:** サイトのルートで流すコマンド。出力があれば当たりで、対応に条件が書いてあればその条件を出力の箇所で確かめる。
- **対応:** 当たったときにコードで行うこと。
- **本番:** 最初のデプロイのあとに本番で行うこと(あれば)。

判定の `src` は Astro のソースディレクトリ。`node_modules` は常に除く。`grep -c` の判定は、`0` が当たりである。行単位の grep なので、props や引数を複数行に分けて書いたサイトでは、対応済みでも当たることがある — 当たったら該当箇所を開いて確かめる。

公式テンプレートのコードをまとめて書き直したのは v0.28.1 の同期(2026-07-08)が最後で、それ以降は壊れる箇所の小修正だけが入っている。このリストが 0.29 から始まるのはそのためである。

## 目次

- [blog-cloudflare で当たる項目](#blog-cloudflare-で当たる項目)
- [版に依らない](#版に依らない)
- [0.29](#029)
- [0.30](#030)
- [0.31](#031)
- [0.33](#033)
- [0.34](#034)
- [0.36](#036)
- [0.37](#037)
- [0.38](#038)
- [0.40.1](#0401)
- [0.41](#041)
- [0.42](#042)
- [1.0](#10)
- [1.1](#11)

## blog-cloudflare で当たる項目

[`emdash-cms/templates` の `blog-cloudflare`](https://github.com/emdash-cms/templates/tree/main/blog-cloudflare) を、**1.0.1 の同期(2026-09-28)時点** で判定した結果。どこから手を付けるかの目安であり、判定の代わりにはならない — サイトでも判定は流す。

| 項目                                                                                                | 当たる箇所                                                                                                                                               |
| --------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [cron の頻度](#cron-の頻度を決める)                                                                 | `wrangler.jsonc`(毎分)                                                                                                                                   |
| [`search()` のページング](#search-が-cursor-でページングできるようになった)                         | `search.astro`(30件で打ち切り)                                                                                                                           |
| [Turnstile](#コメントの-turnstile-をサーバーで検証するようになった)                                 | `posts/[slug].astro` の `CommentForm`(`commentsEnabled: true`)                                                                                           |
| [`siteUrl`](#siteurl-を設定する)                                                                    | `astro.config.mjs` にも `wrangler.jsonc` にも無い                                                                                                        |
| [`sortOrder`](#コレクションのサイドバーの並び順sortorder)                                           | `seed/seed.json`(全コレクション)                                                                                                                         |
| [trigram](#検索に-trigram-を選べるようになった)                                                     | `posts` / `pages` の検索                                                                                                                                 |
| [Node の版](#nodejs-2216-以上が必須になった)                                                        | `package.json` に `engines` が無い                                                                                                                       |
| [`avatarStorageKey`](#バイラインのアバターを-avatarstoragekey-で組む)                               | `PostCard.astro`、`index.astro`、`posts/index.astro`、`posts/[slug].astro`                                                                               |
| [`getPublicMediaUrl`](#生のメディア-url-を-getpublicmediaurl-で組む)                                | 上の4か所 + `posts/[slug].astro` の `getImageUrl`(og:image)                                                                                              |
| [SEO パネルの自動適用](#emdashhead-が-seo-パネルの値を自動で重ねる)                                 | `posts/[slug].astro` の `getSeoMeta` の手組み(`supports` の `seo` は追随済み)                                                                            |
| [Worker Loader とサンドボックス](#worker-loader-が無いとサンドボックスのプラグインは読み込まれない) | `astro.config.mjs` の `sandboxed: [webhookNotifier]`(`--no-sandboxed-plugins` で作ったとき)                                                              |
| [`group`](#コレクションの-group)                                                                    | `seed/seed.json`                                                                                                                                         |
| [一覧の `edit`](#一覧のエントリにも-edit-が付くようになった)                                        | `category/[slug].astro`、`tag/[slug].astro`(`rss.xml.ts` も出るが HTML ではないので対象外。`index.astro`・`posts/index.astro` は 1.0.1 の同期で追随済み) |
| [`<WidgetArea>` の二重取得](#widgetarea-が自分でキャッシュタグを立てるようになった)                 | 当たらない(`<WidgetArea>` を素のまま置いている)                                                                                                          |
| [404 を `rewrite` で返す](#見つからないエントリを-astrorewrite404-で返す)                           | `posts/[slug].astro`、`pages/[slug].astro`、`category/[slug].astro`、`tag/[slug].astro`(1.1 の項目。2026-10-07 にテンプレートを判定)                     |

当たらなかった項目(すでに追随済み): `emdash/ui/comments`(1.0 で旧 import が消えたので、追随していないと build が落ちる)、`.light` クラス、`includeCounts: false`、詳細ページの `content` の受け渡し、1.0 系の項目すべて(内部サブパス・`experimental`・非推奨 capability・`emdash plugin`)、`htmlBlock` の差し替え(1.1、差し替えていない)。エッジキャッシュ(`routeRules`)は入っていないので、キャッシュタグの項目と `toolbar: "client"`(0.29)も当たらない。デプロイ時にマイグレーションを当てる方式(0.35、`emdash migrate`)は、既定が実行時に当てる `auto` のままなので載せていない。

テンプレートが次の版に同期されたら、この表を判定し直して日付と版を書き換える。更新の有無は `gh api repos/emdash-cms/templates/commits -q '.[0].commit.message'` で分かる。

## 版に依らない

### cron の頻度を決める

- **判定:** `grep -n '"crons"' wrangler.jsonc`
- **対応:** テンプレートは `* * * * *`(毎分)で入っている。予約公開の遅れをどこまで許すかで決める(`0 * * * *` なら最大1時間遅れ)。Cron Trigger はアカウント単位で本数の上限があるので、同じアカウントの他の Worker と合わせて数える。
- **本番:** デプロイの数分後に、管理画面のダッシュボードでスケジューラの警告が出ていないことを確かめる(0.34 から、定期実行が止まっていると警告が出る)。

## 0.29

### `search()` が cursor でページングできるようになった

- **判定:** `grep -rn "await search(" src | grep -v cursor`
- **対応:** これまで結果は `limit` で黙って打ち切られていた。`search(query, { limit, cursor })` が返す `nextCursor` を `?cursor=` に載せて「次へ」を出す(最後のページでは `undefined`)。

### コメントの Turnstile をサーバーで検証するようになった

- **判定:** `grep -rn "<CommentForm" src | grep -v turnstileSiteKey`
- **対応:** コメントを受け付けるなら、`CommentForm` に `turnstileSiteKey` を渡す。渡さないと、公開のコメント欄の対策は honeypot だけになる。
- **本番:** Turnstile のウィジェットを作り、`pnpm wrangler secret put EMDASH_TURNSTILE_SECRET_KEY` で秘密鍵を入れる。**サイトキーを渡したフォームをデプロイしてから入れる** — 鍵があるとトークンの無い投稿はすべて拒否されるので、順番を逆にするとコメントが1件も通らない。鍵が無いあいだはサーバーの検証が行われない。**1.1.0 未満は `wrangler secret put` で入れた鍵を読まない**([emdash#3622](https://github.com/emdash-cms/emdash/pull/3622)) — ビルド時に在った鍵だけを、サーバーのバンドルへ焼き込んで使う。1.1.0 以上に上げてから入れ、ビルド時に鍵を置いていたなら作り直す。

## 0.30

### `siteUrl` を設定する

- **判定:** `grep -c "siteUrl\|EMDASH_SITE_URL\|SITE_URL" astro.config.mjs wrangler.jsonc`(両方 `0` なら当たり)
- **対応:** 本番のドメインが決まっていれば、`emdash({ siteUrl: "https://…" })` を足す(コードに書かないなら `wrangler.jsonc` の `vars` に `EMDASH_SITE_URL`)。MCP の OAuth discovery(0.30)と、送信メールのリンク(0.33。マジックリンク・招待・コメント通知など)がこの値を使う。無いときはリクエストの origin や、セットアップ時に保存した URL が使われる。
- **本番:** `workers.dev` で初回セットアップをしてから独自ドメインへ移したなら、移したあとに設定し、マジックリンクのメールのリンク先を確かめる。

## 0.31

### サイトの秘密鍵を実行時にしか読まなくなった

- **判定:** `grep -n "EMDASH_ENCRYPTION_KEY" .env`
- **対応:** 無し。`EMDASH_ENCRYPTION_KEY`・`EMDASH_PREVIEW_SECRET`・`EMDASH_IP_SALT` は実行時の `process.env` からだけ読まれ、ビルド時の `.env` はバンドルに入らない。
- **本番:** `.env` の値は本番では使われないので、`pnpm wrangler secret put EMDASH_ENCRYPTION_KEY` で入れる。

## 0.33

### `emdash dev` が非推奨になった

- **判定:** `grep -rn "emdash dev" --exclude-dir=node_modules --exclude-dir=.git .`
- **対応:** `pnpm dev`(`astro dev`)に書き換える。ドキュメント・`AGENTS.md`・同梱スキルも対象。**1.0 で `emdash dev` と `emdash auth secret` は消えた**(`Unknown command` で落ちる)。`package.json` の `emdash.url` は `emdash dev --types` しか読んでいなかったので消してよい。

### コメントの部品が `emdash/ui/comments` へ移った

- **判定:** `grep -rn "Comment.*from \"emdash/ui\"" src`
- **対応:** `Comments` / `CommentForm` を `emdash/ui/comments` から import する。**1.0 で `emdash/ui` からの export は消えた** — 残っていると build が落ちる。

### term の並び順をコアが持つようになった

- **判定:** `grep -rln "taxonomy-order\|sortTerms\|termOrder" --exclude-dir=node_modules src plugins astro.config.mjs 2>/dev/null`
- **対応:** 自前の並べ替え(プラグインやソート関数)を外し、取得した順のまま描く。既存の term は、上げた時点の表示順がそのまま保存される。
- **本番:** 外す前に、自前プラグインの設定値が本番に残っていないかを確かめる(残っていれば、管理画面の並べ替えで同じ順にしてから外す)。

### 検索に trigram を選べるようになった

- **判定:** `grep -n '"search"' seed/seed.json`(日本語のコンテンツがあるサイトなら当たりとして扱う)
- **対応:** 検索ページに、3文字未満の語は一致しない旨をコメントで残す。
- **本番:** 検索を有効にしているコレクションの方式を `trigram` にする。切り替え方は公式の [REST API の Search tokenizers](https://docs.emdashcms.com/reference/rest-api/)。語幹処理をしない `unicode61` も選べるが、単語の区切りを前提にするので、日本語ではこれも文中一致をしない。

### コレクションのサイドバーの並び順(`sortOrder`)

- **判定:** `grep -c '"sortOrder"' seed/seed.json`(`0` なら当たり)
- **対応:** seed の各コレクションに `sortOrder` を入れる。
- **本番:** seed は本番に流れないので、管理画面かスキーマ API で同じ順にする。

## 0.34

### repeater フィールドの生成型

- **判定:** `grep -n "repeater" seed/seed.json`
- **対応:** 生成型が repeater の中身まで型を持つようになった。repeater の値を `unknown` から手で絞っている関数があれば、生成型に乗り換えて消す。

## 0.36

### Node.js 22.16 以上が必須になった

- **判定:** `grep -A2 '"engines"' package.json | grep '"node"' || echo engines-missing`(出力が `engines-missing` か、22.16 未満を許す範囲なら当たり)
- **対応:** `package.json` に `"engines": { "node": ">=22.16" }` を足す。EmDash の CLI と SQLite が Node 組み込みの `node:sqlite` を使うようになった。
- **本番:** Workers Builds などでビルドするなら、ビルド環境の Node が 22.16 以上かを確かめる。

### `better-sqlite3` が依存から消えた

- **判定:** `grep -n "better-sqlite3" pnpm-workspace.yaml package.json`
- **対応:** `allowBuilds` などから外す(EmDash は `node:sqlite` へ移った)。

### 画像フィールドのダーク版(`darkVariant`)と `.light` クラス

- **判定:** `grep -rn "classList" src/layouts`
- **対応:** `emdash/ui` の `Image` は、`<html>` に `dark` か `light` のクラスがあればそちらに従い、無ければ `prefers-color-scheme` に従う。テーマ切り替えがあるサイトで、ライトのときにクラスを付けていなければ、`light` を付ける(付けないと、OS がダークでライトを選んだときにダーク版の画像が出る)。Tailwind の `dark:` をクラスに紐付けているなら、`.light` を足しても影響しない。

### メディア使用状況の定期集計(`mediaUsageCron`)が廃止された

- **判定:** `grep -rn "mediaUsageCron" --exclude-dir=node_modules .`
- **対応:** 設定から消す。
- **本番:** メディア使用状況を使うなら、管理画面の「Settings → Media usage tracking」を開き、Ready になるまで待つ。

## 0.37

### MCP の書き込み系ツールが `_rev` を必須にした

- **判定:** `grep -rln "content_update\|content_publish" --exclude-dir=node_modules docs .claude .agents AGENTS.md 2>/dev/null`
- **対応:** `content_update` / `content_publish` / `content_unpublish` / `content_discard_draft` を呼ぶ手順に、直前に `content_get` で `_rev` を取る旨を書く。

### バイラインのアバターを `avatarStorageKey` で組む

- **判定:** `grep -rn "avatarMediaId" src`
- **対応:** メディア ID では配信ルートに当たらない。`byline.avatarStorageKey` を `Astro.locals.emdash.getPublicMediaUrl(key)` に渡して URL を組む。

### 生のメディア URL を `getPublicMediaUrl` で組む

- **判定:** `grep -rn "/_emdash/api/media/file/" src`
- **対応:** og:image・JSON-LD・`<img>` の URL を `Astro.locals.emdash.getPublicMediaUrl(storageKey)` で組む。R2 に公開ドメインがあればそちらを返すので、SNS のクローラが取りに来るたびに Worker が動くのを避けられる。公開ドメインが無ければ従来の配信ルートを返す。

### 件数を描かない term の取得に `includeCounts: false`

- **判定:** `grep -rn "getTerm(\|getTaxonomyTerms(" src | grep -v includeCounts`
- **対応:** 件数を描かない呼び出しに `{ includeCounts: false }` を渡す(割り当ての集計を省く)。

### 設定・メニュー・ウィジェットのキャッシュタグ(`*WithCacheHint`)

- **判定:** `grep -rn "routeRules" astro.config.mjs && grep -rn "getSiteSettings()\|getMenu(\|<WidgetArea" src`(前半が空ならエッジキャッシュを使っていないので当たらない)
- **対応:** `getSiteSettingsWithCacheHint()` / `getMenuWithCacheHint()` / `getWidgetAreaWithCacheHint()` に替え、返る `cacheHint` を `Astro.cache.set()` に渡す。設定やメニューを変えたとき、全ページのエッジキャッシュがタグで消えるようになる。
  - **レイアウトで立てるときは `Astro.cache.options.maxAge !== undefined` のときだけにする。** レイアウトはストリーミング中に描かれるので、`routeRules` に無いルート(`/search` など)でミドルウェアが `set(false)` したあとに上書きし、検索結果がエッジに積まれる。
  - キャッシュの設計そのものは `caching-emdash-site` スキルが持つ。

## 0.38

### `<EmDashHead>` が SEO パネルの値を自動で重ねる

- **判定:** `grep -rln "getEmDashEntry\|getSeoMeta" src/pages; grep -n '"supports"' seed/seed.json | grep -v seo`(前半は詳細ページの一覧で、それぞれが `content` を渡しているかを確かめる。後半は SEO パネルが無いコレクション)
- **対応:** 詳細ページから `createPublicPageContext` に `content: { collection, id }` を渡す。description / og:title / og:description / og:image / canonical / robots は `<EmDashHead>` がパネルの値で上書きするので、手で重ねていた処理を消し、本文由来のフォールバックだけを渡す。**`<title>` はサイト側の責任のまま残る** — `getSeoMeta()` を丸ごと消すとパネルの title が `<title>` に出なくなるので、title の解決には残す。自動で重なるのは `getEmDashEntry()` で取ったページだけで、prerender のページは `getSeoMeta()` のまま。詳細ページを持つのに `supports` に `seo` が無いコレクションは、seed に足す。
- **本番:** SEO パネルを使うコレクションの `supports` に `seo` が入っているかを確かめる(seed で入れていても本番には流れない)。

### Worker Loader が無いとサンドボックスのプラグインは読み込まれない

- **判定:** `grep -qE '^\s*"worker_loaders"' wrangler.jsonc || grep -n "sandboxed:" astro.config.mjs`(行頭に限るのは、`--no-sandboxed-plugins` がこのキーを `//` でコメントアウトして残すから)
- **対応:** `--no-sandboxed-plugins` で作ると `worker_loaders` はコメントアウトされるが、`astro.config.mjs` の `sandboxed: [...]` は残る。このままでは、そこに並べたプラグインは **黙って読み込まれない**(起動時に "Plugin sandbox is configured but not available" の警告だけが出る)。有料プランならコメントを外す。無料プランなら `sandboxed` から外すか、`plugins: []` へ移して同じプロセスで動かす。移すと隔離も資源の制限も無くなるので、プラグインにサイト本体と同じ権限を渡すことになる(公式の [Capabilities & Security](https://docs.emdashcms.com/plugins/creating-plugins/capabilities/))。
- **本番:** デプロイ後のログ(`pnpm wrangler tail`)に上の警告が出ていないことを確かめる。

### 一覧のエントリにも `edit` が付くようになった

- **判定:** `grep -L "\.edit\." $(grep -rl "getEmDashCollection" src/pages)`(一覧を取るページのうち、`edit` を展開していないもの)
- **対応:** 任意。`getEmDashCollection()` の結果を描く箇所でも、`{...entry.edit.title}` を展開すると管理画面からその場で編集できる。部品に切り出しているなら `edit` を props で渡す。

### コレクションの `group`

- **判定:** `grep -c '"group"' seed/seed.json`(`0` なら当たり。コレクションが少なければ対応しないと決めてよい)
- **対応:** seed のコレクションに `group` を入れる。同じ `group` のコレクションが管理画面のサイドバーで1つのフォルダになる。
- **本番:** 管理画面かスキーマ API で同じ `group` を入れる(0.38 のデプロイ後)。

### Portable Text の表が CSS 変数を読む

- **判定:** `grep -rn "@theme inline" src/styles`
- **対応:** 公開側の表は `--color-border` / `--color-surface` / `--color-bg-subtle` を読む。Tailwind の `@theme inline` に置いた `--color-*` は実行時の CSS に出ないので、本文のコンテナ(`.prose` など)で自分のトークンから渡す。渡さないと明るい灰色の既定値になり、ダークテーマで文字が読めない。

### 編集ロック(マイグレーション 075)

- **判定:** `grep -rln "content_update" --exclude-dir=node_modules docs .claude .agents AGENTS.md 2>/dev/null`
- **対応:** 管理画面で開いているエントリを MCP から更新すると 409 が返る旨を、運用手順に書く。
- **本番:** マイグレーションはランタイムが当てるので作業は無い。

## 0.40.1

### MCP の `media_upload` が base64 だけを受けるようになった

- **判定:** `grep -rn "media_upload" --exclude-dir=node_modules docs .claude .agents AGENTS.md 2>/dev/null`
- **対応:** `url` を渡して取り込ませる手順を、ファイルを取得して base64 と `contentType` を渡す手順に書き換える。署名付き URL で上げたあとに確定するのは `media_create`(`POST /_emdash/api/media/upload-url` が返す `storageKey` を渡す)。

## 0.41

### `<WidgetArea>` が自分でキャッシュタグを立てるようになった

- **判定:** `grep -rn "getWidgetAreaWithCacheHint" src`
- **対応:** ページ側で先に `getWidgetAreaWithCacheHint()` を呼んで `Astro.cache.set()` に渡していたなら消す(0.37 の項目で足した処理)。`<WidgetArea>` が `Astro.cache.enabled` のとき自分で立てる。ウィジェットを編集したあとに古いエリアがエッジに残る不具合もこの版で直った。

## 0.42

### `relations` が予約スラグになり、`emdash plugin` が消えた

- **判定:** `grep -n '"slug": "relations"' seed/seed.json; grep -rn "emdash plugin" --exclude-dir=node_modules --exclude-dir=.git .`
- **対応:** `relations` というコレクションがあるなら別名にする(既存のものは中身も API も残るが、管理画面から開けなくなる)。`emdash plugin`(login / scaffold / validate / bundle / publish)を呼ぶスクリプトは、レジストリ側の手順へ移す。

## 1.0

1.0 の最初の版は **1.0.1** である。npm には誤って公開された `emdash@1.0.0`(0.7 相当のコード)が deprecated で残っているので入れない。0.42 からの移行は公式の [upgrade guide](https://docs.emdashcms.com/upgrade-to-v1/)。以降、破壊的変更はメジャー版でしか入らない。

### 内部サブパスが `internal/` の下へ移った

- **判定:** `grep -rnE 'emdash/(db/(sqlite|libsql|postgres)-migrations|database/(pg-)?migration-lock)|cloudflare/db/(d1|hyperdrive)-migrations' --exclude-dir=node_modules src plugins astro.config.mjs 2>/dev/null`
- **対応:** 公開のエントリポイントに付け替える。`emdash/internal/…` は公開 API ではないので、直接 import しない。上げたら再ビルドする(`emdash migrate` は古い版が書いたマイグレーションのマニフェストを受け付けない)。

### `cloudflareCache()` が消えた

- **判定:** `grep -rnE "cloudflareCache|@emdash-cms/cloudflare/cache|CF_ZONE_ID|CF_CACHE_PURGE_TOKEN" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null`
- **対応:** `@emdash-cms/cloudflare` の `cloudflareCache()` と、そのエントリポイント `@emdash-cms/cloudflare/cache`・`/cache/config` は消えた(import が解決できずビルドが落ちる)。`@astrojs/cloudflare/cache` の `cacheCloudflare()`(Workers Cache)へ替え、`CF_ZONE_ID` と `CF_CACHE_PURGE_TOKEN` のシークレットは消す。`kvCache()`(オブジェクトキャッシュ)は変わらない。設定の書き方は `caching-emdash-site`。

### `emdash auth secret` の代わりに `emdash secrets generate`

- **判定:** `grep -rn "auth secret" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null`
- **対応:** スクリプトから `emdash auth secret` を消す。暗号鍵は `emdash secrets generate` で作る。`EMDASH_AUTH_SECRET` がすでに設定してあれば消さない(コメント投稿者の IP ハッシュが変わらなくなる)。

### `experimental` オプションが消えた

- **判定:** `grep -n "experimental" astro.config.mjs`
- **対応:** `experimental.registry` は起動時にエラーになる。トップレベルの `registry` へ移す。`experimental: {}` は実行時には無視されるが、TypeScript の設定では型から消えたので削る。

### 非推奨の capability 名が起動時に警告される

- **判定:** `grep -rnE '"(read|write):[a-z]+"|network:fetch|page:inject' --exclude-dir=node_modules src plugins astro.config.mjs 2>/dev/null`
- **対応:** 自前のプラグインが宣言している旧名(`read:content`・`network:fetch`・`page:inject` など)を、起動時の警告が一覧する現行名(`content:read`・`network:request` など)へ替える。警告はプラグインごとに1度、起動時に出る。

## 1.1

### 見つからないエントリを `Astro.rewrite("/404")` で返す

- **判定:** `grep -rn 'redirect("/404")' src`
- **対応:** `Astro.rewrite("/404")` に替える(上流のテンプレートも [emdash#3650](https://github.com/emdash-cms/emdash/pull/3650) で替えた)。リダイレクトだと元の URL は 302 を返し、検索エンジンには 404 が伝わらない。しかもその 302 は元のルートの `routeRules` を継承してキャッシュに載り、あとでエントリを公開してもパージが当たらない。`rewrite` の 404 は 1.1.0 から EmDash のミドルウェアがキャッシュから外す。

### `htmlBlock` の描画を差し替えているなら、isolated のブロックを上流へ渡す

- **判定:** `grep -rn "htmlBlock:" src`
- **対応:** 1.1.0 から、管理画面で作る HTML ブロックは `isolated: true` が付き、CSS・JS を sandbox の iframe で動かす前提になった。自前の描画が `html` を sanitize してインラインに出していると、CSS・JS が黙って落ちる。`node.isolated` が真のときだけ `emdash/ui` の `HtmlBlock` に `node` を渡し、それ以外は今までどおり描く。差し替えていなければ上流の描画が両方を扱うので要らない。
