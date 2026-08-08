# Portable Textブロックタイプ

**Trustedプラグイン限定。** PTブロックは、サイト側レンダリング用のAstroコンポーネント（`componentsEntry`）を必要とし、これはビルド時にnpmパッケージからロードされる。Sandboxed/マーケットプレイスプラグインはPTブロックを定義できない。

プラグインはPortable Textエディタにカスタムブロックタイプを追加できる。これらはスラッシュコマンドメニューに表示され、任意の`portableText`フィールドに挿入できる。

## ブロックタイプの宣言

`definePlugin()`内で、`admin.portableTextBlocks`の下にブロックを宣言する。

```typescript
admin: {
	portableTextBlocks: [
		{
			type: "youtube",
			label: "YouTube Video",
			icon: "video",
			placeholder: "Paste YouTube URL...",
			fields: [
				{ type: "text_input", action_id: "id", label: "YouTube URL" },
				{ type: "text_input", action_id: "title", label: "Title" },
				{ type: "text_input", action_id: "poster", label: "Poster Image URL" },
			],
		},
		{
			type: "codepen",
			label: "CodePen",
			icon: "code",
			placeholder: "Paste CodePen URL...",
		},
	],
}
```

### ブロック設定フィールド

| フィールド    | 型       | 説明                                              |
| ------------- | -------- | ------------------------------------------------- |
| `type`        | `string` | ブロックタイプ名（PTの`_type`で使われる）。必須。 |
| `label`       | `string` | スラッシュコマンドメニューでの表示名。必須。      |
| `icon`        | `string` | アイコンキー。任意。                              |
| `description` | `string` | スラッシュコマンドメニューでの説明。任意。        |
| `placeholder` | `string` | 入力欄のプレースホルダーテキスト。任意。          |
| `fields`      | `array`  | 編集UI用のBlock Kitフォームフィールド。任意。     |

### アイコン

指定可能なアイコン名: `video`、`code`、`link`、`link-external`。不明または未指定の場合は汎用のキューブアイコンにフォールバックする。

### フィールド

`fields`が宣言されている場合、エディタは編集用にBlock Kitフォームをレンダリングする。省略された場合は、シンプルなURL入力が表示される。

フィールドにはBlock Kitの要素構文を使う。

```typescript
fields: [
  {
    type: "text_input",
    action_id: "id",
    label: "URL",
    placeholder: "https://...",
  },
  { type: "text_input", action_id: "title", label: "Title" },
  { type: "text_input", action_id: "poster", label: "Poster Image" },
  { type: "number_input", action_id: "start", label: "Start Time (seconds)" },
  { type: "toggle", action_id: "autoplay", label: "Autoplay" },
  {
    type: "select",
    action_id: "size",
    label: "Size",
    options: [
      { label: "Small", value: "small" },
      { label: "Medium", value: "medium" },
      { label: "Large", value: "large" },
    ],
  },
];
```

すべての要素タイプは[Block Kitリファレンス](./block-kit.md)を参照。

各フィールドの`action_id`はPortable Textブロックデータのキーになる。`action_id: "id"`を持つフィールドは主識別子（通常はURL）として扱われる。

### データフロー

1. ユーザーがエディタで`/`を入力し、ブロックタイプを選択する
2. Block Kitフォーム（`fields`がない場合はシンプルなURL入力）を伴うモーダルが開く
3. ユーザーがフィールドを入力し、送信する
4. `_type`をブロックタイプに設定し、フィールドの値をプロパティとしてブロックが挿入される
5. 既存ブロックの編集時は、値が事前入力された状態で同じモーダルが再度開く

Portable Textの出力。

```json
{
  "_type": "youtube",
  "_key": "abc123",
  "id": "https://youtube.com/watch?v=dQw4w9WgXcQ",
  "title": "Never Gonna Give You Up",
  "poster": "https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg"
}
```

## サイト側レンダリング

サイト上でブロックタイプをレンダリングするには、`componentsEntry`からAstroコンポーネントをエクスポートする。

### コンポーネントファイル

```typescript
// src/astro/index.ts
import YouTube from "./YouTube.astro";
import CodePen from "./CodePen.astro";

// このエクスポート名は必須である
export const blockComponents = {
  youtube: YouTube,
  codepen: CodePen,
};
```

### Astroコンポーネント

```astro
---
// src/astro/YouTube.astro
const { id, title, poster } = Astro.props.node;

// URLから動画IDを抽出
const videoId = id?.match(/(?:v=|youtu\.be\/)([^&]+)/)?.[1] ?? id;
---

<div class="youtube-embed">
	<iframe
		src={`https://www.youtube-nocookie.com/embed/${videoId}`}
		title={title || "YouTube Video"}
		allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
		allowfullscreen
	></iframe>
</div>
```

コンポーネントはブロックデータ全体を含む`Astro.props.node`を受け取る。

### プラグインディスクリプタ

ディスクリプタで`componentsEntry`を設定する。

```typescript
export function myPlugin(options = {}): PluginDescriptor {
  return {
    id: "my-plugin",
    entrypoint: "@my-org/my-plugin",
    componentsEntry: "@my-org/my-plugin/astro",
    version: "1.0.0",
    options,
  };
}
```

### パッケージのエクスポート

`./astro`エクスポートを追加する。

```json
{
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js" },
    "./admin": { "types": "./dist/admin.d.ts", "import": "./dist/admin.js" },
    "./astro": {
      "types": "./dist/astro/index.d.ts",
      "import": "./dist/astro/index.js"
    }
  }
}
```

### 自動配線

プラグインのブロックコンポーネントは、サイト上の`<PortableText>`に自動的にマージされる。マージ順序は以下の通り。

1. EmDashのデフォルト（優先度最低）
2. プラグインのブロックコンポーネント
3. ユーザー提供のコンポーネント（優先度最高）

サイトの作者は何もインポートする必要がない。ユーザーコンポーネントはプラグインのデフォルトより優先される。

## 完全なサンプル

```typescript
// src/index.ts
import { definePlugin } from "emdash";
import type { PluginDescriptor } from "emdash";

export function embedsPlugin(options = {}): PluginDescriptor {
  return {
    id: "embeds",
    version: "1.0.0",
    entrypoint: "@my-org/plugin-embeds",
    componentsEntry: "@my-org/plugin-embeds/astro",
    options,
  };
}

export function createPlugin() {
  return definePlugin({
    id: "embeds",
    version: "1.0.0",

    admin: {
      portableTextBlocks: [
        {
          type: "youtube",
          label: "YouTube Video",
          icon: "video",
          placeholder: "Paste YouTube URL...",
          fields: [
            { type: "text_input", action_id: "id", label: "YouTube URL" },
            { type: "text_input", action_id: "title", label: "Title" },
            {
              type: "text_input",
              action_id: "poster",
              label: "Poster Image URL",
            },
          ],
        },
        {
          type: "linkPreview",
          label: "Link Preview",
          icon: "link-external",
          placeholder: "Paste any URL...",
        },
      ],
    },
  });
}

export default createPlugin;
```

```typescript
// src/astro/index.ts
import YouTube from "./YouTube.astro";
import LinkPreview from "./LinkPreview.astro";

export const blockComponents = {
  youtube: YouTube,
  linkPreview: LinkPreview,
};
```

</content>
