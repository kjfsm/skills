# Block Kit

Sandboxedプラグインの管理ページ向けの宣言的JSON UI。ブロックはホスト側がレンダリングし、ブラウザ内でプラグインのJavaScriptは一切実行されない。SlackのBlock Kitに着想を得ているが同一ではない -- 概念や命名は似ているが、ブロック/要素タイプやcapabilitiesは異なる。

Trustedプラグイン（`astro.config.ts`で宣言されるもの）は代わりにカスタムReactコンポーネントを同梱できる。Block Kitはランタイムにインストールされるsandboxedプラグイン向けのものである。

Block Kitの要素は[Portable Textブロック編集フィールド](./portable-text-blocks.md)でも使われる。プラグインがブロックタイプに`fields`を宣言すると、エディタはBlock Kitフォームをレンダリングする。

## 仕組み

1. ユーザーがプラグインの管理ページに移動する
2. 管理画面がプラグインの管理ルートに`page_load`インタラクションを送信する
3. プラグインがブロックの配列を含む`BlockResponse`を返す
4. 管理画面が`BlockRenderer`を使ってブロックをレンダリングする
5. ユーザーが操作する（ボタンクリック、フォーム送信）→ インタラクションが送り返される
6. プラグインが新しいブロックを返す

```typescript
import type { BlockInteraction } from "@emdash-cms/blocks";

routes: {
	admin: {
		handler: async (ctx) => {
			// EmDashはリクエストボディを一度だけパースし、ctx.inputとして公開する。
			// ctx.request.json()（ボディはすでに消費済み）ではなく直接読み取ること。
			// BlockInteractionはpage_load、block_action、form_submitの
			// ペイロードの判別可能なユニオン型である。
			const interaction = ctx.input as BlockInteraction;

			if (interaction.type === "page_load") {
				return {
					blocks: [
						{ type: "header", text: "My Plugin Settings" },
						{
							type: "form",
							block_id: "settings",
							fields: [
								{ type: "text_input", action_id: "api_url", label: "API URL" },
								{ type: "toggle", action_id: "enabled", label: "Enabled", initial_value: true },
							],
							submit: { label: "Save", action_id: "save" },
						},
					],
				};
			}

			if (interaction.type === "form_submit" && interaction.action_id === "save") {
				await ctx.kv.set("settings", interaction.values);
				return {
					blocks: [/* 更新後のブロック */],
					toast: { message: "Settings saved", type: "success" },
				};
			}
		},
	},
}
```

## ブロックタイプ

| タイプ    | 説明                                                       |
| --------- | ---------------------------------------------------------- |
| `header`  | 大きな太字の見出し                                         |
| `section` | オプションのアクセサリ要素を伴うテキスト                   |
| `divider` | 水平線                                                     |
| `fields`  | ラベル/値の2カラムグリッド                                 |
| `table`   | 書式設定・ソート・ページネーション付きのデータテーブル     |
| `actions` | ボタンやコントロールの横並び                               |
| `stats`   | トレンド表示付きのダッシュボード指標カード                 |
| `form`    | 条件付き表示と送信を伴う入力フィールド                     |
| `image`   | キャプション付きのブロックレベル画像                       |
| `context` | 目立たない小さなヘルプテキスト                             |
| `columns` | ネストされたブロックを持つ2〜3カラムレイアウト             |
| `chart`   | チャート（タイムシリーズの折れ線/棒、円、カスタムECharts） |
| `code`    | シンタックスハイライト付きのコードブロック                 |
| `meter`   | 進捗/クォータのメーターバー                                |
| `banner`  | Info、警告、エラーのインラインメッセージ                   |

## 要素タイプ

| タイプ         | 説明                                       |
| -------------- | ------------------------------------------ |
| `button`       | 確認ダイアログを任意で伴うアクションボタン |
| `text_input`   | 単一行または複数行のテキスト入力           |
| `number_input` | min/maxを伴う数値入力                      |
| `select`       | ドロップダウン選択                         |
| `toggle`       | オン/オフスイッチ                          |
| `secret_input` | APIキーやトークン用のマスク入力            |
| `checkbox`     | 複数選択チェックボックス                   |
| `radio`        | 単一選択ラジオボタン                       |
| `date_input`   | 日付ピッカー                               |
| `combobox`     | 検索可能なドロップダウン選択               |

## ブロック構文

### Header

```json
{ "type": "header", "text": "Settings" }
```

### Section

```json
{
  "type": "section",
  "text": "Configure your plugin settings below.",
  "accessory": { "type": "button", "text": "Refresh", "action_id": "refresh" }
}
```

### Divider

```json
{ "type": "divider" }
```

### Fields

```json
{
  "type": "fields",
  "fields": [
    { "label": "Status", "value": "Active" },
    { "label": "Last Sync", "value": "2 hours ago" }
  ]
}
```

### Stats

```json
{
  "type": "stats",
  "stats": [
    { "label": "Total", "value": "1,234", "trend": "+12%", "trend_direction": "up" },
    { "label": "Active", "value": "567" }
  ]
}
```

### Table

```json
{
  "type": "table",
  "columns": [
    { "key": "name", "label": "Name" },
    { "key": "status", "label": "Status" },
    { "key": "date", "label": "Date" }
  ],
  "rows": [{ "name": "Item 1", "status": "Active", "date": "2025-01-01" }]
}
```

### Actions

```json
{
  "type": "actions",
  "elements": [
    { "type": "button", "text": "Save", "action_id": "save", "style": "primary" },
    { "type": "button", "text": "Cancel", "action_id": "cancel" }
  ]
}
```

### Form

```json
{
  "type": "form",
  "block_id": "settings",
  "fields": [
    { "type": "text_input", "action_id": "name", "label": "Name" },
    { "type": "number_input", "action_id": "count", "label": "Count", "min": 0, "max": 100 },
    {
      "type": "select",
      "action_id": "theme",
      "label": "Theme",
      "options": [
        { "label": "Light", "value": "light" },
        { "label": "Dark", "value": "dark" }
      ]
    },
    { "type": "toggle", "action_id": "enabled", "label": "Enabled", "initial_value": true },
    { "type": "secret_input", "action_id": "api_key", "label": "API Key" }
  ],
  "submit": { "label": "Save", "action_id": "save_settings" }
}
```

### Columns

```json
{
  "type": "columns",
  "columns": [
    { "blocks": [{ "type": "header", "text": "Left" }] },
    { "blocks": [{ "type": "header", "text": "Right" }] }
  ]
}
```

### Chart（タイムシリーズ）

```json
{
  "type": "chart",
  "config": {
    "chart_type": "timeseries",
    "series": [
      {
        "name": "Requests",
        "data": [
          [1709596800000, 42],
          [1709600400000, 67],
          [1709604000000, 53]
        ],
        "color": "#086FFF"
      },
      {
        "name": "Errors",
        "data": [
          [1709596800000, 2],
          [1709600400000, 5],
          [1709604000000, 1]
        ]
      }
    ],
    "x_axis_name": "Time",
    "y_axis_name": "Count",
    "style": "line",
    "gradient": true,
    "height": 300
  }
}
```

- `series[].data` — `[timestamp_ms, value]`タプルの配列
- `series[].color` — 16進カラーコード（任意、未指定の場合はKumoパレットから自動割り当て）
- `style` — `"line"`（デフォルト）または`"bar"`
- `gradient` — ライン下のグラデーション塗りつぶし（デフォルトfalse）
- `height` — チャートの高さ（px単位、デフォルト350）

### Chart（カスタム）

円グラフ、ゲージ、その他任意のECharts可視化向け。

```json
{
  "type": "chart",
  "config": {
    "chart_type": "custom",
    "options": {
      "series": [
        {
          "type": "pie",
          "data": [
            { "value": 335, "name": "Published" },
            { "value": 234, "name": "Draft" },
            { "value": 120, "name": "Scheduled" }
          ]
        }
      ]
    },
    "height": 300
  }
}
```

- `options` — `chart.setOption()`にそのまま渡される生のEChartsオプションオブジェクト

### Code

```json
{
  "type": "code",
  "code": "const greeting = \"Hello!\";\nconsole.log(greeting);",
  "language": "ts"
}
```

- `language` — `"ts"`、`"tsx"`、`"jsonc"`、`"bash"`、または`"css"`（デフォルトは`"ts"`）

### Meter

```json
{
  "type": "meter",
  "label": "Storage used",
  "value": 65,
  "custom_value": "6.5 GB / 10 GB"
}
```

- `value` — 数値（デフォルト範囲は0〜100）
- `max` / `min` — カスタム範囲（デフォルトは0〜100）
- `custom_value` — パーセンテージの代わりに表示する文字列（例: "750 / 1,000"）

### Banner

```json
{
  "type": "banner",
  "title": "API key invalid",
  "description": "Please check your API key in settings.",
  "variant": "error"
}
```

- `variant` — `"default"`（情報、デフォルト）、`"alert"`（警告）、または`"error"`
- `title`または`description`の少なくとも一方が必須

## 条件付きフィールド

他のフィールドの値に基づいてフィールドを表示/非表示にする。クライアント側で評価され、ラウンドトリップは発生しない。

```json
{
  "type": "toggle",
  "action_id": "auth_enabled",
  "label": "Enable Authentication"
}
```

```json
{
  "type": "secret_input",
  "action_id": "api_key",
  "label": "API Key",
  "condition": { "field": "auth_enabled", "eq": true }
}
```

## ビルダーヘルパー

`@emdash-cms/blocks`はTypeScriptヘルパーを提供する。

```typescript
import { blocks, elements } from "@emdash-cms/blocks";

const { header, form, section, stats, timeseriesChart, customChart, banner: bannerBlock } = blocks;
const { textInput, toggle, select, button } = elements;

return {
  blocks: [
    header("Settings"),
    form({
      blockId: "settings",
      fields: [
        textInput("site_title", "Site Title", { initialValue: "My Site" }),
        toggle("generate_sitemap", "Generate Sitemap", { initialValue: true }),
        select("robots", "Default Robots", [
          { label: "Index, Follow", value: "index,follow" },
          { label: "No Index", value: "noindex,follow" },
        ]),
      ],
      submit: { label: "Save", actionId: "save" },
    }),
    // タイムシリーズチャート
    timeseriesChart({
      series: [
        {
          name: "Page Views",
          data: [
            [Date.now() - 3600000, 100],
            [Date.now(), 150],
          ],
        },
      ],
      yAxisName: "Views",
      gradient: true,
    }),
    // カスタムEChartsオプションによる円グラフ
    customChart({
      options: {
        series: [
          {
            type: "pie",
            data: [
              { value: 335, name: "Published" },
              { value: 234, name: "Draft" },
            ],
          },
        ],
      },
    }),
  ],
};
```

## ボタンの確認ダイアログ

```json
{
  "type": "button",
  "text": "Delete All",
  "action_id": "delete_all",
  "style": "danger",
  "confirm": {
    "title": "Are you sure?",
    "text": "This cannot be undone.",
    "confirm": "Delete",
    "deny": "Cancel"
  }
}
```

## トーストレスポンス

通知を表示するには、ブロックと併せて`toast`を返す。

```typescript
return {
  blocks: [/* ... */],
  toast: { message: "Settings saved", type: "success" }, // "success" | "error" | "info"
};
```

</content>
