# サイト機能

## サイト設定

```typescript
import { getSiteSettings, getSiteSetting } from "emdash";

// すべての設定
const settings = await getSiteSettings();
settings.title; // "My Site"
settings.tagline; // "A description"
settings.logo?.url; // 解決済みメディアURL
settings.favicon?.url;

// 単一の設定
const title = await getSiteSetting("title");
```

利用可能なキー: `title`、`tagline`、`logo`、`favicon`、`social`、`timezone`、`dateFormat`。

サイト名やロゴなどをハードコードする代わりにこれらを使用してください。

## ナビゲーションメニュー

```typescript
import { getMenu, getMenus } from "emdash";

// 名前付きメニューを取得
const menu = await getMenu("primary");

// すべてのメニューを一覧取得
const menus = await getMenus();
```

### メニューのレンダリング

```astro
---
import { getMenu } from "emdash";
const primaryMenu = await getMenu("primary");
---
<nav>
	{primaryMenu?.items.map(item => (
		<a href={item.url} target={item.target}>{item.label}</a>
	))}
</nav>
```

### ネストしたメニュー(ドロップダウン)

```astro
{primaryMenu?.items.map(item => (
	<li>
		<a href={item.url}>{item.label}</a>
		{item.children.length > 0 && (
			<ul class="submenu">
				{item.children.map(child => (
					<li><a href={child.url}>{child.label}</a></li>
				))}
			</ul>
		)}
	</li>
))}
```

### MenuItemの形状

```typescript
interface MenuItem {
  id: string;
  label: string;
  url: string; // 解決済みURL
  target?: string; // "_blank" など
  children: MenuItem[];
}
```

## タクソノミー

```typescript
import { getTaxonomyTerms, getTerm, getEntryTerms, getEntriesByTerm } from "emdash";

// タクソノミー内のすべてのターム(nameはシードの"name"フィールドと完全に一致させる必要がある)
const categories = await getTaxonomyTerms("category");
const tags = await getTaxonomyTerms("tag");

// スラッグによる単一ターム
const term = await getTerm("category", "news");
// { id, name, slug, label, children, count }

// 特定のエントリのターム(entry.idではなくdata.idを使用!)
const postCategories = await getEntryTerms("posts", post.data.id, "category");
const postTags = await getEntryTerms("posts", post.data.id, "tag");

// 特定のタームを持つエントリ
const newsPosts = await getEntriesByTerm("posts", "category", "news");
```

**重要:** タクソノミー名の引数は、シードで定義した`"name"`と完全に一致させる必要があります。ブログのシードでは`"category"`と`"tag"`(単数形)を使用します。`"categories"`を使うとエラーなしで空の結果が返ります。

**重要:** `getEntryTerms`はスラッグではなくデータベースULID(`post.data.id`)を受け取ります。

### 記事のタームを表示する

```astro
---
const tags = await getEntryTerms("posts", post.data.id, "tag");
---
{tags.map(t => (
	<a href={`/tag/${t.slug}`}>{t.label}</a>
))}
```

### タクソノミーによるフィルタリング

```astro
---
const { entries: posts } = await getEmDashCollection("posts", {
	where: { category: term.slug },
	orderBy: { published_at: "desc" },
});
---
```

## ウィジェットエリア

名前付きウィジェットエリアをレンダリングします。

```astro
---
import { WidgetArea } from "emdash/ui";
---
<aside>
	<WidgetArea name="sidebar" />
</aside>
```

`WidgetArea`コンポーネントは、エリア内のすべてのウィジェット(検索、カテゴリ、タグ、最新記事、リッチテキストなど)を、適切なHTMLとCSSクラスとともに自動的にレンダリングします。

### 手動でのウィジェットレンダリング

より細かい制御が必要な場合は、`getWidgetArea`関数を使用します。

```astro
---
import { getWidgetArea } from "emdash";
import { PortableText } from "emdash/ui";

const sidebar = await getWidgetArea("sidebar");
---
{sidebar?.widgets.map(widget => (
	<div class="widget">
		{widget.title && <h3>{widget.title}</h3>}
		{widget.type === "content" && widget.content && (
			<PortableText value={widget.content} />
		)}
	</div>
))}
```

## 検索

### プログラムによる検索(推奨)

素のformと`search()`APIで検索ページを実装する。検索ページの置き場所は
サイトのルーティング次第(単一サイトなら`src/pages/search.astro`)。

```typescript
import { search } from "emdash";

const { items } = await search("hello world", {
  collections: ["blog"],
  status: "published",
  limit: 30,
});
// 戻り値: { items: SearchResult[], nextCursor? }
```

各結果(`SearchResult`)は次のプロパティを持つ: `collection`、`id`、`title`、`slug`、
`snippet`(`<mark>`によるハイライト付きHTML)、`score`。

```astro
---
import { search } from "emdash";
const query = Astro.url.searchParams.get("q") ?? "";
const { items: results } = query
	? await search(query, { collections: ["blog"], limit: 30 })
	: { items: [] };
---
<h1>検索</h1>
<form><input name="q" value={query} /></form>
{results.map((r) => <a href={`/blog/${r.slug}`}>{r.title}</a>)}
```

### LiveSearchコンポーネント(任意・インスタント検索)

素のformの代わりに、`emdash/ui/search`のインスタント検索コンポーネントも使える。`placeholder` / `collections` に加え、`class` / `inputClass` /
`resultsClass`などのCSSクラス、`expandOnFocus`、`--emdash-search-*`のCSS変数テーマに対応。

```astro
---
import LiveSearch from "emdash/ui/search";
---
<LiveSearch placeholder="Search..." collections={["blog"]} />
```

### 検索の前提条件

検索にはコレクションごとの有効化が必要です。

1. 管理画面で: コンテンツタイプの編集 -> Featuresで「Search」にチェック
2. シードファイルでフィールドに`"searchable": true`を設定
3. 検索可能なコレクションの、検索可能とマークされたフィールドのみがインデックスされる

## SEOメタ情報

コンテンツエントリからSEOメタ情報を生成します。

```typescript
import { getSeoMeta } from "emdash";

const seo = getSeoMeta(post, {
  siteTitle: "My Blog",
  siteUrl: Astro.url.origin,
  path: `/posts/${slug}`,
  defaultOgImage: featuredImageUrl, // オプションのフォールバック
});

// 戻り値: { title, description, canonical, ogImage, robots }
```

レイアウトの`<head>`内で使用します。

```astro
<title>{seo.title}</title>
<meta name="description" content={seo.description} />
<link rel="canonical" href={seo.canonical} />
<meta property="og:image" content={seo.ogImage} />
{seo.robots && <meta name="robots" content={seo.robots} />}
```

## コメント

組み込みのコメントシステム:

```astro
---
import { Comments, CommentForm } from "emdash/ui";
---
<Comments collection="posts" contentId={post.data.id} threaded />
<CommentForm collection="posts" contentId={post.data.id} />
```

コメントはシード内でコレクションごとに有効化します: `"commentsEnabled": true`。

## ページコントリビューション(プラグインによるHead/Body挿入)

プラグインはページの`<head>`と`<body>`にコンテンツを注入できます。これをサポートするには、ページコントリビューションコンポーネントを使用します。

```astro
---
import { EmDashHead, EmDashBodyStart, EmDashBodyEnd } from "emdash/ui";
import { createPublicPageContext } from "emdash/page";

const pageCtx = createPublicPageContext({
	Astro,
	kind: content ? "content" : "custom",
	pageType: "article",
	title: fullTitle,
	pageTitle: post.data.title,
	description,
	canonical,
	image,
	content: { collection: "posts", id: post.data.id, slug },
});
---
<html>
	<head>
		<!-- your meta tags -->
		<EmDashHead page={pageCtx} />
	</head>
	<body>
		<EmDashBodyStart page={pageCtx} />
		<!-- your content -->
		<EmDashBodyEnd page={pageCtx} />
	</body>
</html>
```

これにより、プラグイン(アナリティクス、トラッキングピクセル、構造化データなど)が任意のページに寄与できるようになります。

## バイライン

バイラインはユーザーアカウントとは独立した著者プロフィールです。ゲスト著者や、ロールラベル付きの複数著者クレジットをサポートします。

### エントリに事前ロードされる

バイラインは、クエリレイヤーによって自動的にすべてのエントリに`data.bylines`として
付加されます(単数の`data.byline`は存在しません)。

```astro
{/* すべてのクレジット(共著者やゲストエッセイのroleLabelを含む) */}
{post.data.bylines?.map(credit => (
	<span>
		{credit.byline.displayName}
		{credit.roleLabel && <em> ({credit.roleLabel})</em>}
	</span>
))}
```

- `entry.data.bylines` -- `ContentBylineCredit`の配列(各要素は`.byline`(著者本体)、`.roleLabel`、`.source`を持つ)

### 単独のクエリ関数

```typescript
import { getByline, getBylineBySlug } from "emdash";

// 特定のバイラインを検索
const byline = await getBylineBySlug("jane-doe");
```

### BylineSummaryの形状

```typescript
interface BylineSummary {
  id: string;
  slug: string;
  displayName: string;
  bio: string | null;
  avatarMediaId: string | null;
  websiteUrl: string | null;
  isGuest: boolean;
}
```

### ContentBylineCreditの形状

```typescript
interface ContentBylineCredit {
  byline: BylineSummary;
  sortOrder: number;
  roleLabel: string | null; // 例: "Guest essay"、"Photographer"
  source?: "explicit" | "inferred"; // "inferred" = author_idからのフォールバック
}
```

## ダークモードパターン

Cookieベースのテーマ切り替え(読み込み時のちらつきなし):

```html
<!-- スタイル読み込み前の<head>内 -->
<script is:inline>
  (function () {
    var c = document.cookie;
    var i = c.indexOf("theme=");
    var theme = i >= 0 ? c.slice(i + 6).split(";")[0] : null;
    if (theme === "dark" || theme === "light") {
      document.documentElement.classList.add(theme);
    } else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
      document.documentElement.classList.add("dark");
    }
  })();
</script>
```

次に、`.dark`クラスに応じて変化するCSS変数を使用します。

```css
:root {
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
}
:root.dark {
  --color-bg: #0d0d0d;
  --color-text: #ededed;
}
```

## レイアウトパターン

典型的なベースレイアウト:

```astro
---
import { getMenu, getEmDashCollection } from "emdash";
import { WidgetArea, EmDashHead, EmDashBodyStart, EmDashBodyEnd } from "emdash/ui";
import { createPublicPageContext } from "emdash/page";
import LiveSearch from "emdash/ui/search";

interface Props {
	title: string;
	description?: string | null;
	image?: string | null;
	content?: { collection: string; id: string; slug?: string | null };
}

const { title, pageTitle, description, image, content } = Astro.props;
const menu = await getMenu("primary");

const pageCtx = createPublicPageContext({
	Astro,
	kind: content ? "content" : "custom",
	pageType: "website",
	title,
	pageTitle: pageTitle ?? title,
	description,
	image,
	content,
});
---
<!doctype html>
<html lang="en">
	<head>
		<meta charset="UTF-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1.0" />
		<title>{title}</title>
		{description && <meta name="description" content={description} />}
		<EmDashHead page={pageCtx} />
	</head>
	<body>
		<EmDashBodyStart page={pageCtx} />
		<header>
			<nav>
				<a href="/">My Site</a>
				<LiveSearch placeholder="Search..." collections={["posts", "pages"]} />
				{menu?.items.map(item => (
					<a href={item.url}>{item.label}</a>
				))}
			</nav>
		</header>
		<main>
			<slot />
		</main>
		<footer>
			<WidgetArea name="footer" />
		</footer>
		<EmDashBodyEnd page={pageCtx} />
	</body>
</html>
```
