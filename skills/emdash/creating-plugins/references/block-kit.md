# Block Kit: 公式に載っていないブロックと要素

> Block Kitの仕組み(`page_load` / `block_action` / `form_submit`のやりとり、`BlockResponse`、
> ビルダーヘルパー、条件付きフィールド、`header` / `section` / `divider` / `fields` / `table` /
> `actions` / `stats` / `form` / `image` / `context` / `columns` / `empty` / `accordion`)は
> [creating-plugins/block-kit](https://docs.emdashcms.com/plugins/creating-plugins/block-kit/)にある。
> ここに書くのは、**公式の一覧に載っていない**ブロック・要素だけ(`@emdash-cms/blocks`のバリデータが
> 実際に受け付けるもの)。

## 公式の表に無いブロック

### `chart`(タイムシリーズ)

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
          [1709600400000, 67]
        ],
        "color": "#086FFF"
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
- `series[].color` — 16進カラー(任意。未指定ならパレットから自動割り当て)
- `style` — `"line"`(既定)または`"bar"`
- `gradient` — ライン下のグラデーション塗り(既定false)
- `height` — px(既定350)

### `chart`(カスタム / ECharts生オプション)

円グラフ、ゲージなど任意の可視化用。`options`はそのまま`chart.setOption()`に渡される。

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
            { "value": 234, "name": "Draft" }
          ]
        }
      ]
    },
    "height": 300
  }
}
```

### `banner`

```json
{
  "type": "banner",
  "title": "API key invalid",
  "description": "Please check your API key in settings.",
  "variant": "error"
}
```

- `variant` — `"default"`(情報、既定)/ `"alert"`(警告)/ `"error"`
- `title`か`description`の少なくとも一方が必須

### `meter`

```json
{
  "type": "meter",
  "label": "Storage used",
  "value": 65,
  "custom_value": "6.5 GB / 10 GB"
}
```

- `value` — 数値。範囲は`min`/`max`で変更(既定0〜100)
- `custom_value` — パーセンテージの代わりに表示する文字列

### `code`

```json
{
  "type": "code",
  "code": "const greeting = \"Hello!\";\nconsole.log(greeting);",
  "language": "ts"
}
```

- `language` — `"ts"` / `"tsx"` / `"jsonc"` / `"bash"` / `"css"`(既定`"ts"`)

## 公式の表に無い要素

公式が挙げているのは`button` / `text_input` / `number_input` / `select` / `toggle` / `secret_input`の
6つだけだが、実際にはこれらも使える。

### `checkbox` / `radio`

```json
{
  "type": "checkbox",
  "action_id": "features",
  "label": "Features",
  "options": [
    { "label": "Sitemap", "value": "sitemap" },
    { "label": "RSS", "value": "rss" }
  ],
  "initial_value": ["sitemap"]
}
```

`radio`は同じ形で、`initial_value`が文字列(単一選択)になる。

### `date_input`

```json
{ "type": "date_input", "action_id": "starts_at", "label": "Starts at", "placeholder": "YYYY-MM-DD" }
```

### `combobox`

検索可能なドロップダウン。`select`と同じく`options: [{ label, value }]`を取る。

```json
{ "type": "combobox", "action_id": "collection", "label": "Collection", "options": [] }
```

### `media_picker`

メディアライブラリから選ばせる。`mime_type_filter`はMIMEタイプのプレフィックス(既定`"image/"`)。

```json
{ "type": "media_picker", "action_id": "og_image", "label": "OG Image", "mime_type_filter": "image/" }
```

### `repeater`

同じ形の行を可変個入力させる。サブフィールドに使えるのは`text_input` / `number_input` / `select` /
`toggle`の4つだけ。

```json
{
  "type": "repeater",
  "action_id": "faqs",
  "label": "FAQ",
  "item_label": "FAQ",
  "min_items": 0,
  "max_items": 10,
  "fields": [
    { "type": "text_input", "action_id": "question", "label": "Question" },
    { "type": "text_input", "action_id": "answer", "label": "Answer" }
  ]
}
```

**注意**: 管理UIは新しい行をサブフィールドの型から初期化する(空文字列 / `false`)ので、`initial_value`で
既存行を事前入力することはできない。保存済みの行はフォームの`values`ペイロードとして返すこと。

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

## トースト

ブロックと併せて返すと通知が出る。

```typescript
return {
  blocks: [/* ... */],
  toast: { message: "Settings saved", type: "success" }, // "success" | "error" | "info"
};
```
