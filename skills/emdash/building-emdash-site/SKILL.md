---
name: building-emdash-site
description: AstroでEmDash CMSサイトを構築・カスタマイズする。ページ作成、コレクション定義、シードファイル作成、コンテンツクエリ、Portable Textのレンダリング、メニュー/タクソノミー/ウィジェットのセットアップ、デプロイ設定など、EmDash搭載Astroサイトに関するあらゆるタスクで使用する。基本的なAstroの知識は前提とし、EmDash固有のパターンをすべて提供する。
---

# EmDashサイトの構築

EmDashはAstro上に構築されたCMSです。スキーマをコード内ではなくデータベースに保存し、ライブコンテンツコレクション経由でコンテンツを配信し、`/_emdash/admin`にフル機能の管理UIを提供します。サイトは`emdash`インテグレーションを備えた標準的なAstroプロジェクトです。

## よくある落とし穴

これらはサイトを静かに壊すものです。着手する前に知っておいてください。

1. **画像フィールドは文字列ではなくオブジェクトです。** `post.data.featured_image`は`{ id, src, alt }`です。`<img src={post.data.featured_image} />`と書くと`[object Object]`がレンダリングされます。`"emdash/ui"`の`<Image image={post.data.featured_image} />`を使ってください。

2. **`entry.id`と`entry.data.id`は別物です。** `entry.id`はスラッグ(URLで使用)です。`entry.data.id`はデータベースのULID(`getEntryTerms`、`Comments`など、実際のIDを必要とするAPI呼び出しで使用)です。取り違えると結果が静かに空になります。

3. **タクソノミー名はシードと完全に一致させる必要があります。** シードで`"name": "category"`と定義していれば、`getTerm("category", slug)`のようにクエリする必要があります -- `"categories"`ではありません。名前を間違えるとエラーなしで空の結果が返ります。

4. **`Astro.cache.set()`には必ず`cacheHint`を渡してください。** すべてのクエリは`cacheHint`を返します。コンテンツをクエリするすべてのページで`Astro.cache.set(cacheHint)`を呼び出してください。そうしないと、編集者が変更を公開してもキャッシュの無効化が機能しません。

5. **CMSコンテンツには`getStaticPaths`を使いません。** EmDashのコンテンツは動的です。ページはサーバーレンダリング(`astro.config.mjs`で`output: "server"`)にする必要があります。

6. **`.astro`からReactコンポーネントへ渡した子要素は文字列化されます。** Radix UIの`asChild`(`Slot`)パターンのように子要素のpropsを書き換える実装は、エラーなく静かに効かなくなります。shadcn/uiコンポーネントをこのサイトで使う際の詳細は**[references/astro-react-tailwind.md](references/astro-react-tailwind.md)**を参照してください。

## ファイル構成

すべてのEmDashサイトには、以下の主要ファイルがあります。

```
my-site/
├── astro.config.mjs          # emdash()インテグレーションを含むAstro設定
├── src/
│   ├── live.config.ts         # EmDashローダー登録(定型コード)
│   ├── pages/                 # Astroページ(すべてサーバーレンダリング)
│   ├── layouts/               # レイアウトコンポーネント
│   └── components/            # 再利用可能なコンポーネント
├── seed/
│   └── seed.json              # スキーマ + デモコンテンツ
├── emdash-env.d.ts          # 生成された型(`emdash types`から)
└── package.json
```

## ワークフロー

### 1. プロジェクトを設定する

`astro.config.mjs`、`live.config.ts`、デプロイ対象(Node vs Cloudflare)、型生成については**[references/configuration.md](references/configuration.md)**を参照してください。

### 2. スキーマを設計する

コレクション定義、フィールドタイプ、タクソノミー、メニュー、ウィジェットエリア、セクション、バイライン、シードファイルの完全な形式については**[references/schema-and-seed.md](references/schema-and-seed.md)**を参照してください。

### 3. ページを構築する

コンテンツクエリ、Portable Textのレンダリング、Imageコンポーネント、ビジュアル編集属性、キャッシュ、よくあるページパターン(一覧、詳細、タクソノミーアーカイブ、RSS、検索、404)については**[references/querying-and-rendering.md](references/querying-and-rendering.md)**を参照してください。

### 4. サイト機能を組み込む

サイト設定、ナビゲーションメニュー、タクソノミー、ウィジェットエリア、検索、SEOメタ情報、コメント、ページコントリビューションについては**[references/site-features.md](references/site-features.md)**を参照してください。

### 5. シードファイルを作成する

コレクション、フィールド、タクソノミー、メニュー、ウィジェット、サンプルコンテンツを含む`seed/seed.json`を作成します。

### 6. 実行して検証する

```bash
npx emdash dev          # devサーバーを起動(マイグレーション+シード適用、型生成を実行)
```

管理UIは`http://localhost:4321/_emdash/admin`にあります。

## クイックAPIチートシート

```typescript
// コンテンツ(エントリには.data.bylines(著者クレジットの配列)が事前ロードされている)
import { getEmDashCollection, getEmDashEntry } from "emdash";
const { entries, nextCursor, cacheHint } = await getEmDashCollection("posts", {
  limit: 10,
  cursor,
  orderBy: { published_at: "desc" },
});
const { entry: post, cacheHint } = await getEmDashEntry("posts", slug);

// サイト機能
import {
  getSiteSettings,
  getMenu,
  getTaxonomyTerms,
  getTerm,
  getEntryTerms,
  getEntriesByTerm,
  getWidgetArea,
  search,
  getSection,
  getSeoMeta,
} from "emdash";

// バイライン(単独クエリ -- エントリにバイラインが付属しているため通常は不要)
import { getByline, getBylineBySlug } from "emdash";

// UIコンポーネント
import {
  PortableText,
  Image,
  Comments,
  CommentForm,
  WidgetArea,
  EmDashHead,
  EmDashBodyStart,
  EmDashBodyEnd,
} from "emdash/ui";
import LiveSearch from "emdash/ui/search";

// ページコンテキスト(プラグインのコントリビューション用)
import { createPublicPageContext } from "emdash/page";
```

## プラグイン

EmDashは、フック、ストレージ、設定、管理UI、APIルート、カスタムPortable TextブロックタイプでCMSを拡張するプラグインをサポートしています。次のような場合にプラグインを検討してください。

- コンテンツのライフサイクルイベントに反応させたい場合(例: 公開時に通知を送る、外部サービスに同期する)
- カスタム管理ページやダッシュボードウィジェットを追加したい場合
- Portable Textエディタにカスタムブロックタイプを追加したい場合(例: 埋め込み地図、コードプレイグラウンド、CTA)
- 再利用可能なサービスを提供したい場合(例: アナリティクス、フォーム、サードパーティ経由のコメント)

プラグインは`astro.config.mjs`で登録します。

```javascript
emdash({
	database: sqlite({ url: "file:./data.db" }),
	storage: local({ directory: "./uploads", baseUrl: "/_emdash/api/media/file" }),
	plugins: [myPlugin()],
}),
```

**プラグインを構築するには、`creating-plugins`スキル**(`.agents/skills/creating-plugins/`内)を読み込んでください。プラグインの構造、フック、ストレージ、管理UI、APIルート、Portable Textブロック、ケーパビリティ、そして`definePlugin()`APIの全体を扱っています。

## リファレンスドキュメント

今のタスクに関係するファイルだけを読むこと(全referenceを一括で読み込まない)。

| ファイル                                                                     | 内容                                                                             |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| [references/configuration.md](references/configuration.md)                   | プロジェクト設定、astro.config、live.config、デプロイ、型                        |
| [references/schema-and-seed.md](references/schema-and-seed.md)               | コレクション、フィールド、タクソノミー、メニュー、ウィジェット、シード形式       |
| [references/querying-and-rendering.md](references/querying-and-rendering.md) | コンテンツAPI、PortableText、Image、キャッシュ、ページパターン                   |
| [references/site-features.md](references/site-features.md)                   | 設定、メニュー、ウィジェット、検索、SEO、コメント、ページコントリビューション    |
| [references/astro-react-tailwind.md](references/astro-react-tailwind.md)     | shadcn/ui(React)を`.astro`から使う際の子要素の制約、Tailwind v4のCSS変数参照構文 |
