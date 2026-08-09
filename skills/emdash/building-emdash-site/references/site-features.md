# サイト機能

> サイト設定・メニュー・タクソノミー・ウィジェットエリア・セクション・検索の取得APIは公式にある。
> [reference/api](https://docs.emdashcms.com/reference/api/)、
> [guides/site-settings](https://docs.emdashcms.com/guides/site-settings/)、
> [guides/menus](https://docs.emdashcms.com/guides/menus/)、
> [guides/taxonomies](https://docs.emdashcms.com/guides/taxonomies/)、
> [guides/widgets](https://docs.emdashcms.com/guides/widgets/)、
> [guides/sections](https://docs.emdashcms.com/guides/sections/)。
> ここに書くのは、公式に載っていないAPI・型・前提条件だけ。

## 目次

- [タクソノミー: 引数の取り違えに注意](#タクソノミー-引数の取り違えに注意)
- [ウィジェットエリアは`<WidgetArea>`で丸ごと描画できる](#ウィジェットエリアはwidgetareaで丸ごと描画できる)
- [検索の前提条件](#検索の前提条件)
- [バイライン(公式にランタイム型の記載なし)](#バイライン公式にランタイム型の記載なし)
- [コメント](#コメント)
- [ページコントリビューション(公式にテンプレート側の記載なし)](#ページコントリビューション公式にテンプレート側の記載なし)

## タクソノミー: 引数の取り違えに注意

公式の例は`getEntryTerms("posts", "post-123", "category")`と書いていて分かりにくいが、第2引数は
**データベースULID**(`post.data.id`)であってスラッグ(`post.id`)ではない。

```typescript
const postTags = await getEntryTerms("posts", post.data.id, "tag");
```

また、タクソノミー名はシードの`"name"`と完全一致でなければ**エラーなしで空の結果**が返る。

多くの場合、そもそも`getEntryTerms`を呼ぶ必要はない —— エントリには`data.terms`(タクソノミー名 →
用語配列)が事前ロードされている。

## ウィジェットエリアは`<WidgetArea>`で丸ごと描画できる

公式のWidget Areasガイドは`getWidgetArea()`で取得して手組みする例しか載せていないが、`emdash/ui`に
エリアごと描画するコンポーネントがある。検索・カテゴリ・タグ・最新記事・リッチテキストなどのウィジェットを、
適切なHTMLとCSSクラスつきで自動的にレンダリングする。

```astro
---
import { WidgetArea } from "emdash/ui";
---
<aside>
	<WidgetArea name="sidebar" />
</aside>
```

細かく制御したいときだけ`getWidgetArea`で手組みする。

## 検索の前提条件

`search()`はインデックスされたものしか返さない。次の2つが揃っていないと空になる。

1. コレクションの`supports`に`"search"`が入っていること(管理画面ならコンテンツタイプ編集 → Features →
   Search、シードなら`"supports": [..., "search"]`)
2. 対象フィールドに`"searchable": true`が付いていること

`search()`の戻り値は`{ items, nextCursor? }`で、各`SearchResult`は`collection` / `id` / `title` / `slug` /
`snippet`(`<mark>`つきHTML)/ `score`を持つ。

素のformで組むほか、`emdash/ui/search`のインスタント検索コンポーネントも使える(公式に記載なし)。
`placeholder` / `collections`のほか、`class` / `inputClass` / `resultsClass`、`expandOnFocus`、
`--emdash-search-*`のCSS変数テーマに対応する。

```astro
---
import LiveSearch from "emdash/ui/search";
---
<LiveSearch placeholder="Search..." collections={["blog"]} />
```

## バイライン(公式にランタイム型の記載なし)

バイラインはユーザーアカウントとは独立した著者プロフィール。ゲスト著者や、ロールラベル付きの複数著者
クレジットをサポートする。シードでの定義形式は
[themes/seed-files](https://docs.emdashcms.com/themes/seed-files/)にある。

クエリレイヤーが全エントリに`data.bylines`として付加する(単数の`data.byline`は存在しない)。

```astro
{post.data.bylines?.map(credit => (
	<span>
		{credit.byline.displayName}
		{credit.roleLabel && <em> ({credit.roleLabel})</em>}
	</span>
))}
```

```typescript
interface ContentBylineCredit {
  byline: BylineSummary;
  sortOrder: number;
  roleLabel: string | null; // 例: "Guest essay"、"Photographer"
  source?: "explicit" | "inferred"; // "inferred" = author_idからのフォールバック
}

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

単独で引きたいときだけ`getByline` / `getBylineBySlug`を使う。

## コメント

```astro
---
import { Comments, CommentForm } from "emdash/ui";
---
<Comments collection="posts" contentId={post.data.id} threaded />
<CommentForm collection="posts" contentId={post.data.id} />
```

`contentId`は`post.data.id`(ULID)。コメントはシード内でコレクションごとに有効化する:
`"commentsEnabled": true`。

## ページコントリビューション(公式にテンプレート側の記載なし)

公式は`page:metadata` / `page:fragments`フックをプラグイン側から説明しているが、それを受け取る
テンプレート側のコンポーネントは書かれていない。プラグイン(アナリティクス、トラッキングピクセル、
構造化データなど)がページに寄与できるようにするには、レイアウトで次を組む。

```astro
---
import { EmDashHead, EmDashBodyStart, EmDashBodyEnd } from "emdash/ui";
import { createPublicPageContext } from "emdash/page";

const pageCtx = createPublicPageContext({
	Astro,
	kind: content ? "content" : "custom",
	pageType: "article", // トップや一覧なら "website"
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
		<!-- 自前のmetaタグ -->
		<EmDashHead page={pageCtx} />
	</head>
	<body>
		<EmDashBodyStart page={pageCtx} />
		<slot />
		<EmDashBodyEnd page={pageCtx} />
	</body>
</html>
```

`kind`は、コンテンツエントリを表示するページなら`"content"`(`content`に`{ collection, id, slug }`を
渡す)、それ以外は`"custom"`。
