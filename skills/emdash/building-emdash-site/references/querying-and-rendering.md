# コンテンツのクエリとレンダリング

> クエリ関数のシグネチャ・オプション・戻り値、プレビュー、ビジュアル編集(`entry.edit`)、
> `<PortableText>`のカスタムコンポーネント指定は公式にある。
> [guides/querying-content](https://docs.emdashcms.com/guides/querying-content/) と
> [reference/api](https://docs.emdashcms.com/reference/api/)。
> ここに書くのは、公式と食い違う点と、公式に載っていないAPIだけ。

## 目次

- [`cacheHint`を必ずセットする(公式に記載なし)](#cachehintを必ずセットする公式に記載なし)
- [`orderBy`はクエリ側で効く(公式に記載なし)](#orderbyはクエリ側で効く公式に記載なし)
- [`entry.id`と`entry.data.id`は別物](#entryidとentrydataidは別物)
- [日付は`Date`オブジェクトで返る](#日付はdateオブジェクトで返る)
- [`bylines`と`terms`はエントリに事前ロードされている](#bylinesとtermsはエントリに事前ロードされている)
- [`emdash/ui`のエクスポート(公式に一覧なし)](#emdashuiのエクスポート公式に一覧なし)
- [画像の描画](#画像の描画)

## `cacheHint`を必ずセットする(公式に記載なし)

公式のQuerying Contentは「サーバーレンダリングのページには`Astro.response.headers.set("Cache-Control", ...)`を
検討せよ」と書いているが、EmDashのクエリ結果はAstroのRoute Caching用の`cacheHint`を返す。
**コンテンツをクエリするすべてのページで`Astro.cache.set(cacheHint)`を呼ぶこと。** そうしないと、
編集者が変更を公開してもキャッシュの無効化が働かない。

```astro
---
const { entries: posts, cacheHint } = await getEmDashCollection("posts");
Astro.cache.set(cacheHint);
---
```

## `orderBy`はクエリ側で効く(公式に記載なし)

公式のAPI Referenceの`CollectionFilter`には`orderBy`が無く、Querying Contentは「並び順は保証しないので
テンプレートでsortしろ」と書いている。実際には`orderBy`がクエリオプションとして存在する。

```typescript
const { entries, nextCursor, cacheHint } = await getEmDashCollection("posts", {
  status: "published",
  limit: 10,
  cursor, // キーセットページネーション(offsetと排他)
  orderBy: { published_at: "desc", title: "asc" }, // 複数フィールド可。既定は { created_at: "desc" }
  where: { category: "news" },
});
```

`where`はタクソノミー名を自動判別してJOINでフィルタし、予約キー`byline`はバイラインクレジット
(共著含む)でフィルタする。範囲指定も書ける: `{ published_at: { gte: "2024-01-01", lt: "2025-01-01" } }`。

## `entry.id`と`entry.data.id`は別物

- `entry.id` — **スラッグ**。URLの組み立てに使う(`/posts/${post.id}`)
- `entry.data.id` — **データベースのULID**。`getEntryTerms`や`<Comments contentId>`など、実IDを要求する
  API呼び出しに使う

取り違えるとエラーなしで空の結果が返る。

## 日付は`Date`オブジェクトで返る

公式のAPI Referenceは`createdAt` / `updatedAt` / `publishedAt`を「ISO timestamp」と書いているが、
ランタイムで受け取るのは`Date`(`publishedAt`は`Date | null`)。`toLocaleDateString`や
`Intl.DateTimeFormat`をそのまま使える。

## `bylines`と`terms`はエントリに事前ロードされている

公式の`ContentEntry`の説明には出てこないが、クエリレイヤーが各エントリに次を付加する。

- `entry.data.bylines?: ContentBylineCredit[]` — 著者クレジットの配列(単数の`data.byline`は**存在しない**)
- `entry.data.terms?: Record<string, TaxonomyTerm[]>` — タクソノミー名 → 用語配列(例: `post.data.terms?.tag`)

そのため、著者やタグを表示するだけなら`getByline` / `getEntryTerms`を追加で呼ぶ必要はない。
複数エントリ分をまとめて引きたいときだけ`getTermsForEntries`を使う。

## `emdash/ui`のエクスポート(公式に一覧なし)

公式は`PortableText`と`Image`しか例示していない。実際に`emdash/ui`から取れるもの:

```typescript
import {
  Image, // EmDashメディア用。画像フィールドはオブジェクトなので生の<img>には渡せない
  PortableText,
  Comments,
  CommentForm,
  WidgetArea, // ウィジェットエリアを丸ごとレンダリングする(getWidgetAreaでの手組みは不要)
  EmDashHead, // プラグインのページコントリビューション用
  EmDashBodyStart,
  EmDashBodyEnd,
  emdashComponents, // PortableTextの既定コンポーネント群
  // Portable Textの個別ブロック: PTImage / Code / Embed / Gallery / Columns / Break / HtmlBlock / Block
  // マーク: Superscript / Subscript / Underline / StrikeThrough / Link
} from "emdash/ui";

import LiveSearch from "emdash/ui/search"; // インスタント検索コンポーネント
```

SEOメタは`emdash`本体から:

```typescript
import { getSeoMeta } from "emdash";

const seo = getSeoMeta(post, {
  siteTitle: "My Blog",
  siteUrl: Astro.url.origin,
  path: `/posts/${slug}`,
  defaultOgImage: featuredImageUrl, // 任意のフォールバック
});
// { title, description, canonical, ogImage, robots }
```

## 画像の描画

```astro
---
import { Image } from "emdash/ui";
---
{/* 正しい */}
<Image image={post.data.featured_image} />

{/* 生の<img>を使うなら .src(.url ではない) */}
{post.data.featured_image?.src && (
	<img src={post.data.featured_image.src} alt={post.data.featured_image.alt || ""} />
)}

{/* 誤り — オブジェクトなので [object Object] になる */}
<img src={post.data.featured_image} />
```
