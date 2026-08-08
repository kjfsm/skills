# スキーマとシードファイル

シードファイル(`seed/seed.json`)は、サイトのスキーマ全体とオプションのデモコンテンツを定義します。これはビルドにインライン化され、データベースが空でセットアップウィザードが完了していない場合に、最初のリクエスト時に自動的に適用されます。

## シードファイルの構造

```json
{
	"$schema": "https://emdashcms.com/seed.schema.json",
	"version": "1",
	"meta": {
		"name": "My Site",
		"description": "A description of this site",
		"author": "Author Name"
	},
	"settings": { ... },
	"collections": [ ... ],
	"taxonomies": [ ... ],
	"menus": [ ... ],
	"widgetAreas": [ ... ],
	"sections": [ ... ],
	"bylines": [ ... ],
	"content": { ... }
}
```

## コレクション

コレクションはコンテンツタイプを定義します。各コレクションはデータベーステーブル(`ec_{slug}`)になります。

```json
{
	"slug": "posts",
	"label": "Posts",
	"labelSingular": "Post",
	"supports": ["drafts", "revisions", "search", "seo"],
	"commentsEnabled": true,
	"fields": [ ... ]
}
```

### コレクションのsupports

| Support      | 説明                          |
| ------------ | ----------------------------- |
| `drafts`     | 下書き/公開ワークフロー       |
| `revisions`  | リビジョン履歴                |
| `preview`    | 下書きの署名付きプレビューURL |
| `scheduling` | 公開日時の予約                |
| `search`     | 全文検索インデックス          |
| `seo`        | 管理画面のSEOメタフィールド   |

### スラッグのルール

- 小文字の英数字とアンダースコア: `/^[a-z][a-z0-9_]*$/`
- 最大63文字
- 予約済みスラッグと競合不可

## フィールドタイプ

EmDashは16種のフィールドタイプをサポートする(各タイプはSQLiteのカラムタイプに対応)。

| タイプ         | カラムタイプ | ランタイムでの形状                    | 備考                                |
| -------------- | ------------ | ------------------------------------- | ----------------------------------- |
| `string`       | TEXT         | `string`                              | 一行テキスト                        |
| `text`         | TEXT         | `string`                              | 複数行テキスト(テキストエリア)      |
| `url`          | TEXT         | `string`                              | URL値                               |
| `slug`         | TEXT         | `string`                              | URL安全な識別子                     |
| `number`       | REAL         | `number`                              | 浮動小数点数                        |
| `integer`      | INTEGER      | `number`                              | 整数                                |
| `boolean`      | INTEGER      | `boolean`                             | 0/1として保存                       |
| `datetime`     | TEXT         | `Date`                                | DBではISO 8601文字列                |
| `select`       | TEXT         | `string`                              | 選択肢から1つ(`validation.options`) |
| `multiSelect`  | JSON         | `string[]`                            | 選択肢から複数                      |
| `portableText` | JSON         | `PortableTextBlock[]`                 | 構造化JSONとしてのリッチテキスト    |
| `image`        | TEXT         | `{ id, src?, alt?, width?, height? }` | **文字列ではなくオブジェクト**      |
| `file`         | TEXT         | `string`(メディアID)                  | メディアライブラリのファイル参照    |
| `reference`    | TEXT         | `string`(ID)                          | 他のエントリへの参照                |
| `json`         | JSON         | `any`                                 | 任意のJSONデータ                    |
| `repeater`     | JSON         | `object[]`                            | サブフィールドの繰り返しグループ    |

### フィールド定義

```json
{
  "slug": "title",
  "label": "Title",
  "type": "string",
  "required": true,
  "searchable": true
}
```

`select`(選択肢は`validation.options`、既定値は`defaultValue`):

```json
{
  "slug": "state",
  "label": "Status",
  "type": "select",
  "required": true,
  "defaultValue": "◯ 受付OK",
  "validation": { "options": ["◎ ガラ空き", "◯ 受付OK", "✕ 受付NG"] }
}
```

フィールドが持てるプロパティ:

- `slug`(必須) -- フィールド識別子
- `label`(必須) -- 管理画面での表示ラベル
- `type`(必須) -- 上記のタイプのいずれか
- `required` -- 必須バリデーション
- `unique` -- 値の一意性を要求
- `defaultValue` -- 新規エントリの既定値
- `validation` -- 追加のバリデーション規則(`options` / `minLength` / `max` など)
- `searchable` -- 全文検索インデックスに含めるかどうか
- `widget` / `options` -- 管理UIのウィジェット指定・ウィジェット固有設定

### よくあるフィールドパターン

**ブログ記事:**

```json
"fields": [
	{ "slug": "title", "label": "Title", "type": "string", "required": true, "searchable": true },
	{ "slug": "featured_image", "label": "Featured Image", "type": "image" },
	{ "slug": "content", "label": "Content", "type": "portableText", "searchable": true },
	{ "slug": "excerpt", "label": "Excerpt", "type": "text" }
]
```

**ポートフォリオプロジェクト:**

```json
"fields": [
	{ "slug": "title", "label": "Title", "type": "string", "required": true, "searchable": true },
	{ "slug": "featured_image", "label": "Featured Image", "type": "image", "required": true },
	{ "slug": "client", "label": "Client", "type": "string" },
	{ "slug": "year", "label": "Year", "type": "string" },
	{ "slug": "summary", "label": "Summary", "type": "text", "searchable": true },
	{ "slug": "content", "label": "Content", "type": "portableText", "searchable": true },
	{ "slug": "gallery", "label": "Gallery", "type": "json" },
	{ "slug": "url", "label": "Project URL", "type": "string" }
]
```

**ページ(最小構成):**

```json
"fields": [
	{ "slug": "title", "label": "Title", "type": "string", "required": true, "searchable": true },
	{ "slug": "content", "label": "Content", "type": "portableText", "searchable": true }
]
```

## タクソノミー

タクソノミーは、コレクションに紐づくタグ/カテゴリシステムです。

```json
{
  "name": "category",
  "label": "Categories",
  "labelSingular": "Category",
  "hierarchical": true,
  "collections": ["posts"],
  "terms": [
    { "slug": "development", "label": "Development" },
    { "slug": "design", "label": "Design" }
  ]
}
```

- `hierarchical: true` -- ツリー構造(WordPressのカテゴリのような)
- `hierarchical: false` -- フラットなリスト(WordPressのタグのような)
- `collections` -- このタクソノミーが適用されるコレクション
- `terms` -- 事前定義して作成するターム

## メニュー

管理UIから管理されるナビゲーションメニュー。

```json
{
  "name": "primary",
  "label": "Primary Navigation",
  "items": [
    { "type": "custom", "label": "Work", "url": "/works" },
    { "type": "custom", "label": "Blog", "url": "/blog" },
    { "type": "page", "label": "About", "ref": "about", "collection": "pages" }
  ]
}
```

メニュー項目のタイプ:

- `custom` -- 任意のURL(`url`)
- `page` -- コンテンツエントリへの参照(`collection` + `ref`(エントリのスラッグ))。
  URLはレンダリング時にそのエントリのルートへ解決される

## ウィジェットエリア

編集者が設定可能なウィジェットを追加できる名前付き領域。

```json
{
  "name": "sidebar",
  "label": "Sidebar",
  "description": "Widget area displayed on single post pages",
  "widgets": [
    {
      "type": "component",
      "componentId": "core:search",
      "title": "Search"
    },
    {
      "type": "component",
      "componentId": "core:categories",
      "title": "Categories"
    },
    {
      "type": "component",
      "componentId": "core:tags",
      "title": "Tags"
    },
    {
      "type": "component",
      "componentId": "core:recent-posts",
      "title": "Recent Posts",
      "settings": { "count": 5, "showDate": true }
    },
    {
      "type": "component",
      "componentId": "core:archives",
      "title": "Archives",
      "settings": { "type": "monthly", "limit": 6 }
    },
    {
      "type": "content",
      "title": "About",
      "content": [
        {
          "_type": "block",
          "style": "normal",
          "children": [{ "_type": "span", "text": "Some rich text content." }]
        }
      ]
    }
  ]
}
```

### ウィジェットタイプ

| タイプ      | 説明                               | 主なフィールド            |
| ----------- | ---------------------------------- | ------------------------- |
| `content`   | リッチテキスト(Portable Text)      | `content`                 |
| `menu`      | ナビゲーションメニュー             | `menuName`                |
| `component` | コアまたはカスタムのコンポーネント | `componentId`、`settings` |

### コアウィジェットコンポーネント

- `core:search` -- 検索フォーム
- `core:categories` -- 件数付きカテゴリ一覧
- `core:tags` -- タグクラウド
- `core:recent-posts` -- 最新記事一覧
- `core:archives` -- 月別アーカイブリンク

## セクション(再利用可能なブロック)

エディタ内で`/section`スラッシュコマンドから編集者が挿入できる再利用可能なコンテンツブロック。

```json
{
  "slug": "newsletter-signup",
  "title": "Newsletter Signup",
  "description": "A call-to-action block for newsletter subscriptions",
  "keywords": ["newsletter", "subscribe", "email", "cta"],
  "source": "theme",
  "content": [
    {
      "_type": "block",
      "style": "h3",
      "children": [{ "_type": "span", "text": "Stay in the loop" }]
    },
    {
      "_type": "block",
      "style": "normal",
      "children": [{ "_type": "span", "text": "Get notified when new posts are published." }]
    }
  ]
}
```

## バイライン

ユーザーアカウントとは独立した、名前付きの著者プロフィール。

```json
{
  "id": "byline-editorial",
  "slug": "emdash-editorial",
  "displayName": "EmDash Editorial"
}
```

ゲストバイライン:

```json
{
  "id": "byline-guest",
  "slug": "guest-contributor",
  "displayName": "Guest Contributor",
  "isGuest": true
}
```

## 設定

サイト全体の設定:

```json
"settings": {
	"title": "My Blog",
	"tagline": "Thoughts on building for the web"
}
```

利用可能なキー: `title`、`tagline`、`logo`、`favicon`、`social`、`timezone`、`dateFormat`。

## コンテンツ

コレクションのスラッグ別に整理されたサンプルコンテンツ:

```json
"content": {
	"posts": [
		{
			"id": "post-1",
			"slug": "hello-world",
			"status": "published",
			"data": {
				"title": "Hello World",
				"excerpt": "My first post.",
				"featured_image": {
					"$media": {
						"url": "https://images.unsplash.com/photo-xxx?w=1200&h=800&fit=crop",
						"alt": "Description of image",
						"filename": "hello-world.jpg"
					}
				},
				"content": [
					{
						"_type": "block",
						"style": "normal",
						"children": [{ "_type": "span", "text": "This is the body text." }]
					}
				]
			},
			"bylines": [
				{ "byline": "byline-editorial" }
			],
			"taxonomies": {
				"category": ["development"],
				"tag": ["webdev", "opinion"]
			}
		}
	],
	"pages": [
		{
			"id": "about",
			"slug": "about",
			"status": "published",
			"data": {
				"title": "About",
				"content": [
					{
						"_type": "block",
						"style": "normal",
						"children": [{ "_type": "span", "text": "About this site." }]
					}
				]
			}
		}
	]
}
```

### シードコンテンツ内のメディア参照

画像フィールドには`$media`を使用します -- EmDashが画像をダウンロードして保存します。

```json
"featured_image": {
	"$media": {
		"url": "https://images.unsplash.com/photo-xxx?w=1200&h=800&fit=crop",
		"alt": "Description",
		"filename": "my-image.jpg"
	}
}
```

ダウンロードしない外部画像の場合:

```json
"featured_image": "https://images.unsplash.com/photo-xxx?w=1200"
```

### シードコンテンツ内の参照フィールド

他のエントリを参照するには`$ref:id`形式を使用します。

```json
"author": "$ref:byline-editorial"
```

### シードコンテンツ内のPortable Text

`portableText`型のコンテンツフィールドは、ブロックの配列です。

```json
[
  {
    "_type": "block",
    "style": "normal",
    "children": [{ "_type": "span", "text": "A paragraph." }]
  },
  {
    "_type": "block",
    "style": "h2",
    "children": [{ "_type": "span", "text": "A heading" }]
  },
  {
    "_type": "block",
    "style": "blockquote",
    "children": [{ "_type": "span", "text": "A quote." }]
  }
]
```

インラインマーク(太字、斜体、リンク):

```json
{
  "_type": "block",
  "style": "normal",
  "children": [
    { "_type": "span", "text": "This is " },
    { "_type": "span", "text": "bold", "marks": ["strong"] },
    { "_type": "span", "text": " and " },
    { "_type": "span", "text": "italic", "marks": ["em"] }
  ]
}
```

ブロックスタイル: `normal`、`h1`-`h6`、`blockquote`。

### 下書きコンテンツ

未公開のコンテンツを作成するには`"status": "draft"`を設定します。

```json
{
	"id": "post-draft",
	"slug": "work-in-progress",
	"status": "draft",
	"data": { ... }
}
```

## シードの適用

`.emdash/seed.json`、`package.json#emdash.seed`、または`seed/seed.json`のシードはビルドにインライン化され、データベースが空でセットアップウィザードが完了していない場合に最初のリクエスト時に適用されます。既存のデータは決して上書きされません。

**この「最初のリクエスト時のみ」という制約は、コンテンツだけでなくコレクション定義・フィールドなどスキーマ全体にも及ぶ。** 一度DBが初期化された(空でなくなった)後は、`seed/seed.json`に新しいコレクション・フィールド・コンテンツを追加してデプロイしても、既存インスタンスには自動反映されない -- コードと本番のスキーマがズレたままになる。稼働中のインスタンスへスキーマ変更やコンテンツを反映するには、管理画面・CLI(`emdash schema create-collection`などのリモートコマンド)・接続済みMCPツール(`schema_create_collection` / `schema_create_field` / `content_create`など)で直接操作する必要がある。`seed/seed.json`はあくまで初回ブートストラップ用であり、稼働中サイトのマイグレーション手段ではない。

適用時にバリデーションが実行されます。よく検出されるエラー:

- 画像フィールドに生のURLが指定されている(`$media`を使うべき)
- 参照フィールドに生のIDが指定されている(`$ref:id`を使うべき)
- PortableTextが配列でない、または`_type`が欠けている
- 型の不一致(文字列と数値の混在など)

シードが不正な場合、最初のリクエストは失敗し、エラーがログに記録されます。修正後、devサーバーを再起動してください。

## シードのエクスポート

```bash
npx emdash export-seed                      # スキーマのみ
npx emdash export-seed --with-content       # スキーマ + 全コンテンツ
npx emdash export-seed --with-content=posts,pages  # 特定のコレクションのみ
```
