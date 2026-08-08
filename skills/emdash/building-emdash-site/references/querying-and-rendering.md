# コンテンツのクエリとレンダリング

## コンテンツクエリ

すべてのクエリ関数は`"emdash"`からインポートします。

### getEmDashCollection

コレクションから複数のエントリを取得します。`{ entries, error, cacheHint, nextCursor, hasMore }`を返します。

```typescript
import { getEmDashCollection } from "emdash";

// 基本形
const { entries: posts } = await getEmDashCollection("posts");

// オプション付き
const { entries: posts, cacheHint } = await getEmDashCollection("posts", {
  status: "published",
  limit: 10,
  orderBy: { published_at: "desc" },
  where: { category: "news" },
});
```

オプション:

- `status` -- ステータスでフィルタ(`"published"`、`"draft"`など)
- `limit` -- 最大取得件数
- `cursor` -- キーセットページネーション用の不透明なカーソル(前回の結果の`nextCursor`を渡す)
- `orderBy` -- `{ field: "asc" | "desc" }`(デフォルト: `{ created_at: "desc" }`)
- `where` -- フィールド値またはタクソノミーターゲットでフィルタ。OR条件には配列を使用可: `{ category: ["news", "featured"] }`
- `locale` -- ロケールでフィルタ(i18nが設定されている場合)

### getEmDashEntry

スラッグで単一のエントリを取得します。`{ entry, error, isPreview, cacheHint }`を返します。

```typescript
import { getEmDashEntry } from "emdash";

const { entry: post, cacheHint } = await getEmDashEntry("posts", slug);

if (!post) {
  return Astro.redirect("/404");
}
```

### エントリの形状

```typescript
interface ContentEntry<T> {
  id: string; // スラッグ(URLで使用)
  data: T; // システムフィールドを含む全フィールド
  edit: EditProxy; // ビジュアル編集属性(要素にスプレッドする)
}

// dataにはシステムフィールドとカスタムフィールドが含まれる:
interface PostData {
  id: string; // データベースULID(タクソノミー検索などで使用)
  slug: string;
  status: string;
  title: string;
  featured_image?: {
    id: string;
    src?: string;
    alt?: string;
    width?: number;
    height?: number;
  };
  content?: PortableTextBlock[];
  createdAt: Date;
  updatedAt: Date;
  publishedAt: Date | null;
  // 事前ロード済み(単独クエリ不要)
  bylines?: ContentBylineCredit[]; // 著者クレジットの配列(roleLabel、source付き)
  terms?: Record<string, TaxonomyTerm[]>; // タクソノミー名 → 用語配列(例: terms.tag)
  // ... カスタムフィールド
}
```

`bylines` / `terms` はエントリに事前ロードされるので、著者やタクソノミーの表示に別途
`getByline` / `getEntryTerms` を呼ぶ必要は通常ない(例: `post.data.terms?.tag`、
複数エントリ分をまとめて引く場合は `getTermsForEntries`)。

**重要:** `entry.id`はスラッグ(URL用)、`entry.data.id`はデータベースULID(`getEntryTerms`などのAPI呼び出し用)です。

### キャッシュ

クエリ結果には、AstroのRoute Caching用の`cacheHint`が含まれます。

```astro
---
const { entries: posts, cacheHint } = await getEmDashCollection("posts");
Astro.cache.set(cacheHint);
---
```

必ず`Astro.cache.set(cacheHint)`を呼び出してください -- コンテンツが変更されたときの自動キャッシュ無効化が有効になります。

## Portable Textのレンダリング

### PortableTextコンポーネント

```astro
---
import { PortableText } from "emdash/ui";
---
<PortableText value={post.data.content} />
```

標準的なブロック(段落、見出し、リスト、引用、コードブロック、画像)とインラインマーク(太字、斜体、コード、取り消し線、リンク)をレンダリングします。

### カスタムブロックタイプ

カスタムPTブロック(例: マーケティングコンポーネント)には、`components`プロパティを渡します。

```astro
---
import { PortableText } from "emdash/ui";
import Hero from "./blocks/Hero.astro";
import Features from "./blocks/Features.astro";

const customTypes = {
	"marketing.hero": Hero,
	"marketing.features": Features,
};
---
<PortableText value={page.data.content} components={{ type: customTypes }} />
```

各カスタムコンポーネントは、ブロックデータをpropsとして受け取ります。

## Imageコンポーネント

**CMS画像には必ずEmDashのImageコンポーネントを使用してください。** 画像フィールドは文字列ではなくオブジェクトです。

```astro
---
import { Image } from "emdash/ui";
---

{/* 正しい -- 画像オブジェクトを渡している */}
<Image image={post.data.featured_image} />

{/* 明示的なpropsでも動作する */}
{post.data.featured_image?.src && (
	<img src={post.data.featured_image.src} alt={post.data.featured_image.alt || ""} />
)}
```

**よくある間違い:**

```astro
{/* 誤り -- imageは文字列ではなくオブジェクト */}
<img src={post.data.featured_image} />
```

## ビジュアル編集属性

エントリには、インライン編集用の`edit`属性が含まれます。フィールドを表示する要素にスプレッドしてください。

```astro
<h1 {...post.edit.title}>{post.data.title}</h1>
<p {...post.edit.excerpt}>{post.data.excerpt}</p>
<div {...post.edit.featured_image}>
	<Image image={post.data.featured_image} />
</div>
```

管理者がログインしてサイトを閲覧している場合、これらの属性によりクリックで編集する機能が有効になります。

## よくあるページパターン

### 一覧ページ(例: `/posts/index.astro`)

```astro
---
import { getEmDashCollection, getEntryTerms } from "emdash";
import { Image } from "emdash/ui";
import Base from "../../layouts/Base.astro";

const { entries: posts, cacheHint } = await getEmDashCollection("posts", {
	orderBy: { published_at: "desc" },
});
Astro.cache.set(cacheHint);

const sortedPosts = posts.toSorted((a, b) => {
	const dateA = a.data.publishedAt?.getTime() ?? 0;
	const dateB = b.data.publishedAt?.getTime() ?? 0;
	return dateB - dateA;
});
---
<Base title="Posts">
	{sortedPosts.map(post => (
		<article>
			{post.data.featured_image && <Image image={post.data.featured_image} />}
			<a href={`/posts/${post.id}`}>{post.data.title}</a>
			{post.data.excerpt && <p>{post.data.excerpt}</p>}
		</article>
	))}
</Base>
```

### 詳細ページ(例: `/posts/[slug].astro`)

```astro
---
import { getEmDashEntry, getEntryTerms, getSeoMeta } from "emdash";
import { Image, PortableText } from "emdash/ui";
import Base from "../../layouts/Base.astro";

const { slug } = Astro.params;
if (!slug) return Astro.redirect("/404");

const { entry: post, cacheHint } = await getEmDashEntry("posts", slug);
if (!post) return Astro.redirect("/404");

Astro.cache.set(cacheHint);

const seo = getSeoMeta(post, {
	siteTitle: "My Blog",
	siteUrl: Astro.url.origin,
	path: `/posts/${slug}`,
});

const tags = await getEntryTerms("posts", post.data.id, "tag");
---
<Base title={seo.title} description={seo.description}>
	<article>
		{post.data.featured_image && (
			<div {...post.edit.featured_image}>
				<Image image={post.data.featured_image} />
			</div>
		)}
		<h1 {...post.edit.title}>{post.data.title}</h1>
		<PortableText value={post.data.content} />
		{tags.length > 0 && (
			<div>
				{tags.map(t => <a href={`/tag/${t.slug}`}>{t.label}</a>)}
			</div>
		)}
	</article>
</Base>
```

### タクソノミーアーカイブ(例: `/category/[slug].astro`)

```astro
---
import { getTerm, getEmDashCollection } from "emdash";
import Base from "../../layouts/Base.astro";

const { slug } = Astro.params;
const term = slug ? await getTerm("category", slug) : null;
if (!term) return Astro.redirect("/404");

const { entries: posts } = await getEmDashCollection("posts", {
	where: { category: term.slug },
	orderBy: { published_at: "desc" },
});
---
<Base title={`${term.label} posts`}>
	<h1>{term.label}</h1>
	{posts.map(post => (
		<a href={`/posts/${post.id}`}>{post.data.title}</a>
	))}
</Base>
```

### RSSフィード(例: `/rss.xml.ts`)

```typescript
import type { APIRoute } from "astro";
import { getEmDashCollection } from "emdash";

const siteTitle = "My Site";

export const GET: APIRoute = async ({ url }) => {
  const siteUrl = url.origin;
  const { entries: posts } = await getEmDashCollection("posts", {
    orderBy: { published_at: "desc" },
    limit: 20,
  });

  const items = posts
    .filter((p) => p.data.publishedAt)
    .map((post) => {
      const postUrl = `${siteUrl}/posts/${post.id}`;
      return `    <item>
      <title>${escapeXml(post.data.title)}</title>
      <link>${postUrl}</link>
      <guid isPermaLink="true">${postUrl}</guid>
      <pubDate>${post.data.publishedAt!.toUTCString()}</pubDate>
      <description>${escapeXml(post.data.excerpt || "")}</description>
    </item>`;
    })
    .join("\n");

  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>${escapeXml(siteTitle)}</title>
    <link>${siteUrl}</link>
    <atom:link href="${siteUrl}/rss.xml" rel="self" type="application/rss+xml"/>
    <language>en-us</language>
    <lastBuildDate>${new Date().toUTCString()}</lastBuildDate>
${items}
  </channel>
</rss>`,
    {
      headers: {
        "Content-Type": "application/rss+xml; charset=utf-8",
        "Cache-Control": "public, max-age=3600",
      },
    },
  );
};

function escapeXml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}
```

### 404ページ(`/404.astro`)

```astro
---
import Base from "../layouts/Base.astro";
---
<Base title="Not Found">
	<h1>Page not found</h1>
	<p>The page you're looking for doesn't exist.</p>
	<a href="/">Go home</a>
</Base>
```

### 空状態

コレクションにコンテンツがない場合は、わかりやすい空状態を表示します。

```astro
{posts.length === 0 ? (
	<section>
		<h2>No posts yet</h2>
		<p>Create your first post in the admin panel.</p>
		<a href="/_emdash/admin/content/posts/new">Create a post</a>
	</section>
) : (
	/* ... render posts ... */
)}
```

## ページネーション

`getEmDashCollection`は、カーソルベースのキーセットページネーションをサポートします。前回の結果の`nextCursor`から`cursor`を渡すと次のページを取得できます。

```astro
---
const cursor = Astro.url.searchParams.get("cursor") ?? undefined;
const { entries, nextCursor, cacheHint } = await getEmDashCollection("posts", {
	limit: 10,
	cursor,
	orderBy: { published_at: "desc" },
});
Astro.cache.set(cacheHint);
---
{entries.map(post => (
	<a href={`/posts/${post.id}`}>{post.data.title}</a>
))}
{nextCursor && <a href={`?cursor=${nextCursor}`}>Next page</a>}
```

これ以上結果がない場合、`nextCursor`は`undefined`になります。

## 日付のフォーマット

日付は`Date`オブジェクトとして渡されます。`toLocaleDateString`または`Intl.DateTimeFormat`を使用してください。

```typescript
const formatted = post.data.publishedAt?.toLocaleDateString("en-US", {
  year: "numeric",
  month: "long",
  day: "numeric",
});
```
