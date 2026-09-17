# EmDash を上げるときのやることリスト

サイトのコードか本番の設定に効く変更だけを、版ごとに並べる。管理画面だけで完結する変更は載せない。

各項目は3つで書く:

- **判定:** サイトのルートで流すコマンド。出力があれば当たりで、対応に条件が書いてあればその条件を出力の箇所で確かめる。
- **対応:** 当たったときにコードで行うこと。
- **本番:** マージ後に本番で行うこと(あれば)。

判定の `src` は Astro のソースディレクトリ。`node_modules` は常に除く。

## 目次

- [blog-cloudflare で当たる項目](#blog-cloudflare-で当たる項目)
- [毎回](#毎回)
- [セットアップ直後だけ](#セットアップ直後だけ)
- [0.33](#033)
- [0.34](#034)
- [0.36](#036)
- [0.37](#037)
- [0.38](#038)

## blog-cloudflare で当たる項目

[`emdash-cms/templates` の `blog-cloudflare`](https://github.com/emdash-cms/templates/tree/main/blog-cloudflare) を、**0.38.0 の同期(2026-09-15)時点** で判定した結果。セットアップ直後にどこから手を付けるかの目安であり、判定の代わりにはならない — サイトでも判定は流す。

| 項目                                                                  | 当たる箇所                                                                           |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| [cron の頻度](#cron-の頻度を決める)                                   | `wrangler.jsonc`(毎分)                                                               |
| [`sortOrder`](#コレクションのサイドバーの並び順sortorder)             | `seed/seed.json`(全コレクション)                                                     |
| [trigram](#検索に-trigram-を選べるようになった)                       | `posts` / `pages` の検索                                                             |
| [`avatarStorageKey`](#バイラインのアバターを-avatarstoragekey-で組む) | `PostCard.astro`、`index.astro`、`posts/index.astro`、`posts/[slug].astro`           |
| [`getPublicMediaUrl`](#生のメディア-url-を-getpublicmediaurl-で組む)  | 上の4か所 + `posts/[slug].astro` の `getImageUrl`(og:image)                          |
| [SEO パネルの自動適用](#emdashhead-が-seo-パネルの値を自動で重ねる)   | `posts/[slug].astro` の `getSeoMeta` の手組み、`pages` の `supports` に `seo` が無い |
| [`group`](#コレクションの-group)                                      | `seed/seed.json`                                                                     |

当たらなかった項目(すでに追随済み): `emdash/ui/comments`、`.light` クラス、`includeCounts: false`、詳細ページの `content` の受け渡し。エッジキャッシュ(`routeRules`)は入っていないので、キャッシュタグの項目も当たらない。

テンプレートが次の版に同期されたら、この表を判定し直して日付と版を書き換える。更新の有無は `gh api repos/emdash-cms/templates/commits -q '.[0].commit.message'` で分かる。

## 毎回

### 生成型を作り直す

- **判定:** `git status --short emdash-env.d.ts`(`pnpm dev` を起動したあと)
- **対応:** 差分をそのままコミットに含める。生成型が変わると、手で型を絞っていた箇所が不要になることがある(0.34 の repeater など)。

### DB マイグレーションを確かめる

- **判定:** 変更履歴に `migration` の語があるか。
- **対応:** 無し。
- **本番:** 既定ではデプロイ後の最初のリクエストでランタイムが当てる。サイトがデプロイ手順で当てる構成(`emdash migrate`)なら、その手順が走ることを確かめる。PR 本文に番号を書く。

## セットアップ直後だけ

### cron の頻度を決める

- **判定:** `grep -n '"crons"' wrangler.jsonc`
- **対応:** テンプレートは `* * * * *`(毎分)で入っている。予約公開の遅れをどこまで許すかで決める(`0 * * * *` なら最大1時間遅れ)。Cron Trigger はアカウント単位で本数の上限があるので、同じアカウントの他の Worker と合わせて数える。

## 0.33

### `emdash dev` が非推奨になった

- **判定:** `grep -rn "emdash dev" --exclude-dir=node_modules --exclude-dir=.git .`
- **対応:** `pnpm dev`(`astro dev`)に書き換える。ドキュメント・`AGENTS.md`・同梱スキルも対象。

### コメントの部品が `emdash/ui/comments` へ移った

- **判定:** `grep -rn "Comment.*from \"emdash/ui\"" src`
- **対応:** `Comments` / `CommentForm` を `emdash/ui/comments` から import する。

### term の並び順をコアが持つようになった

- **判定:** `grep -rln "taxonomy-order\|sortTerms\|termOrder" --exclude-dir=node_modules src plugins astro.config.mjs 2>/dev/null`
- **対応:** 自前の並べ替え(プラグインやソート関数)を外し、取得した順のまま描く。既存の term は、上げた時点の表示順がそのまま保存される。
- **本番:** 外す前に、自前プラグインの設定値が本番に残っていないかを確かめる(残っていれば、管理画面の並べ替えで同じ順にしてから外す)。

### 検索に trigram を選べるようになった

- **判定:** `grep -n '"search"' seed/seed.json`(日本語のコンテンツがあるサイトなら当たりとして扱う)
- **対応:** 検索ページに、3文字未満の語は一致しない旨をコメントで残す。
- **本番:** 検索を有効にしているコレクションの索引を trigram で作り直す。既定の索引は日本語の文中一致をしない。

### コレクションのサイドバーの並び順(`sortOrder`)

- **判定:** `grep -c '"sortOrder"' seed/seed.json`(`0` なら当たり)
- **対応:** seed の各コレクションに `sortOrder` を入れる。
- **本番:** seed は本番に流れないので、管理画面かスキーマ API で同じ順にする。

## 0.34

### repeater フィールドの生成型

- **判定:** `grep -n "repeater" seed/seed.json`
- **対応:** 生成型が repeater の中身まで型を持つようになった。repeater の値を `unknown` から手で絞っている関数があれば、生成型に乗り換えて消す。

## 0.36

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
- **対応:** 詳細ページから `createPublicPageContext` に `content: { collection, id }` を渡す。description / og:image / canonical / robots は `<EmDashHead>` がパネルの値で上書きするので、`getSeoMeta()` などで手で重ねていた処理を消し、本文由来のフォールバックだけを渡す。`<title>` だけはサイト側の責任のまま残る。詳細ページを持つのに `supports` に `seo` が無いコレクションは、seed に足す。
- **本番:** SEO パネルを使うコレクションの `supports` に `seo` が入っているかを確かめる(seed で入れていても本番には流れない)。

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
