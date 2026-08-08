---
name: building-emdash-site
description: AstroでEmDash CMSサイトを構築・カスタマイズする。ページ作成、コレクション定義、シードファイル作成、コンテンツクエリ、Portable Textのレンダリング、メニュー/タクソノミー/ウィジェットのセットアップ、デプロイ設定など、EmDash搭載Astroサイトに関するあらゆるタスクで使用する。APIの一次情報源は公式ドキュメントで、このスキルは公式に載っていない落とし穴と公式と食い違う挙動を扱う。
---

# EmDashサイトの構築

EmDashはAstro上に構築されたCMS。スキーマをコード内ではなくデータベースに保存し、ライブコンテンツコレクション経由でコンテンツを配信し、`/_emdash/admin`にフル機能の管理UIを提供する。サイトは`emdash`インテグレーションを備えた標準的なAstroプロジェクト。

## このスキルの読み方

**一次情報源は公式ドキュメント <https://docs.emdashcms.com/> である。** APIの一覧・シグネチャ・
設定項目・シードファイルの全形式は公式にある。MCPサーバー(`https://docs.emdashcms.com/mcp`)を
接続していれば`search_docs`でも引ける。

このスキルに書いてあるのは次の2つだけ:

1. **公式に書かれていないこと** — 実地で踏んだ落とし穴、このサイト群の構成方針
2. **公式と食い違うこと** — 公式の記述が実装と合っていない箇所(下記)

APIの使い方を調べたいなら、まず公式を読むこと。

## 公式ドキュメントの該当ページ

| やりたいこと                         | 公式ページ                                                                                                                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| プロジェクト設定・`emdash()`の設定   | [reference/configuration](https://docs.emdashcms.com/reference/configuration/)                                                                                                             |
| Cloudflareへのデプロイ               | [deployment/cloudflare](https://docs.emdashcms.com/deployment/cloudflare/)                                                                                                                 |
| コンテンツのクエリ                   | [guides/querying-content](https://docs.emdashcms.com/guides/querying-content/)                                                                                                             |
| JS API全体(クエリ・メニュー・検索)   | [reference/api](https://docs.emdashcms.com/reference/api/)                                                                                                                                 |
| フィールドタイプ                     | [reference/field-types](https://docs.emdashcms.com/reference/field-types/)                                                                                                                 |
| シードファイルの形式                 | [themes/seed-files](https://docs.emdashcms.com/themes/seed-files/)                                                                                                                         |
| メニュー / ウィジェット / セクション | [guides/menus](https://docs.emdashcms.com/guides/menus/) ・ [guides/widgets](https://docs.emdashcms.com/guides/widgets/) ・ [guides/sections](https://docs.emdashcms.com/guides/sections/) |
| タクソノミー                         | [guides/taxonomies](https://docs.emdashcms.com/guides/taxonomies/)                                                                                                                         |
| サイト設定                           | [guides/site-settings](https://docs.emdashcms.com/guides/site-settings/)                                                                                                                   |
| 稼働中サイトのスキーマ変更           | [deployment/schema-evolution](https://docs.emdashcms.com/deployment/schema-evolution/)                                                                                                     |
| CLI                                  | [reference/cli](https://docs.emdashcms.com/reference/cli/) — 詳細は`emdash-cli`スキル                                                                                                      |
| プラグイン開発                       | [plugins/overview](https://docs.emdashcms.com/plugins/overview/) — 詳細は`creating-plugins`スキル                                                                                          |

## 公式ドキュメントが実装と食い違う点

そのまま信じると壊れる。実装(`emdash`パッケージ)側が正しい。

1. **画像フィールドの値は`src`であって`url`ではない。** 公式のField Types Referenceは
   `{ id, url, alt, width, height }`と書いているが、ランタイムで返るのは
   `{ id, src?, alt?, width?, height?, provider?, previewUrl?, meta? }`。`post.data.featured_image.url`は
   常に`undefined`になる。

2. **`getEmDashCollection`は`orderBy`を受け取る。** 公式のAPI Referenceの`CollectionFilter`には
   `orderBy`が載っておらず、Querying Contentは「並び順は保証しないのでテンプレート側でsortしろ」と
   書いているが、実際には`orderBy: { published_at: "desc" }`(複数フィールド可、既定は
   `{ created_at: "desc" }`)がクエリ側で効く。

3. **クエリ結果には`cacheHint`が付く。** 公式は`Astro.response.headers.set("Cache-Control", ...)`を
   勧めているが、EmDashはAstroのRoute Caching用の`cacheHint`を返す。詳細は
   [references/querying-and-rendering.md](references/querying-and-rendering.md)。

4. **コレクションの`supports`は6種類ある。** 公式のSeed File Formatは`"drafts"`と`"revisions"`しか
   挙げていないが、実際は`drafts` / `revisions` / `preview` / `scheduling` / `search` / `seo`。

## よくある落とし穴

公式には書かれていない。着手する前に知っておくこと。

1. **画像フィールドは文字列ではなくオブジェクト。** `<img src={post.data.featured_image} />`と書くと
   `[object Object]`がレンダリングされる。`"emdash/ui"`の`<Image image={post.data.featured_image} />`を
   使う(生の`<img>`を使うなら`.src`。上記の食い違い1も参照)。

2. **`entry.id`と`entry.data.id`は別物。** `entry.id`はスラッグ(URLで使用)。`entry.data.id`は
   データベースのULID(`getEntryTerms`、`Comments`など、実際のIDを必要とするAPI呼び出しで使用)。
   取り違えると結果が静かに空になる。

3. **タクソノミー名はシードと完全に一致させる必要がある。** シードで`"name": "category"`と定義して
   いれば`getTerm("category", slug)`とクエリする —— `"categories"`ではない。名前を間違えると
   エラーなしで空の結果が返る。

4. **`Astro.cache.set(cacheHint)`を忘れない。** コンテンツをクエリするすべてのページで呼ぶこと。
   そうしないと、編集者が変更を公開してもキャッシュの無効化が機能しない。

5. **CMSコンテンツには`getStaticPaths`を使わない。** 公式は静的生成も選択肢として挙げているが、
   これらのサイトはコンテンツが動的なのでサーバーレンダリング(`astro.config.mjs`で
   `output: "server"`)に統一している。

6. **`.astro`からReactコンポーネントへ渡した子要素は文字列化される。** Radix UIの`asChild`(`Slot`)
   パターンのように子要素のpropsを書き換える実装は、エラーなく静かに効かなくなる。詳細は
   **[references/astro-react-interop.md](references/astro-react-interop.md)**。

7. **`seed/seed.json`は稼働中サイトのマイグレーション手段ではない。** シードはDBが空のときの
   最初のリクエストでのみ適用される。詳細は
   [references/schema-and-seed.md](references/schema-and-seed.md)。

## ファイル構成

```
my-site/
├── astro.config.mjs          # emdash()インテグレーションを含むAstro設定
├── wrangler.jsonc            # D1 / R2 / KV のバインディング
├── src/
│   ├── live.config.ts         # EmDashローダー登録(定型コード)
│   ├── pages/                 # Astroページ(すべてサーバーレンダリング)
│   ├── layouts/
│   └── components/
├── seed/
│   └── seed.json              # スキーマ + デモコンテンツ
├── emdash-env.d.ts            # 生成された型(devサーバー起動時に自動生成)
└── package.json
```

## 実行と検証

```bash
npx emdash dev          # devサーバー起動(マイグレーション+シード適用、型生成)
```

管理UIは`http://localhost:4321/_emdash/admin`。

## リファレンスドキュメント

いずれも「公式との差分」だけを書いている。今のタスクに関係するファイルだけを読むこと。

| ファイル                                                                     | 内容                                                                          |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [references/configuration.md](references/configuration.md)                   | Cloudflare前提の`astro.config.mjs` / `wrangler.jsonc`の実例、型生成の実際     |
| [references/schema-and-seed.md](references/schema-and-seed.md)               | シードの適用タイミングの罠、`supports`、フィールドタイプの実際の形状          |
| [references/querying-and-rendering.md](references/querying-and-rendering.md) | `cacheHint`、`orderBy`、事前ロードされる`bylines`/`terms`、`edit`属性         |
| [references/site-features.md](references/site-features.md)                   | バイライン、検索の前提条件、ページコントリビューション、レイアウトの型        |
| [references/astro-react-interop.md](references/astro-react-interop.md)       | shadcn/ui(React)を`.astro`から使う際の子要素の制約(EmDashではなくAstro側の話) |
