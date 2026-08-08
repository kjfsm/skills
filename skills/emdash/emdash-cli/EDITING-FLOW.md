# 編集フロー: Portable Text ⇄ markdown

公式ドキュメントは`content get --raw`を「Return raw Portable Text (skip markdown conversion)」としか
説明していない。その変換が実際に何をするかはここにだけ書いてある。

## 自動変換

EmDashはリッチテキストを[Portable Text](https://portabletext.org/)(PT)——構造化されたJSON——として
保存する。CLIはPTとmarkdownの間を自動的に変換するので、使い慣れたテキスト形式で作業できる。

- **読み取り時**: `portableText`フィールド内のPT配列がmarkdown文字列に変換される
- **書き込み時**: `portableText`フィールド内のmarkdown文字列がPT配列に変換し直される
- **PT以外のフィールド**(string、text、numberなど)はそのまま通過する

CLIはコレクションのフィールドスキーマを取得して、どのフィールドに変換が必要かを判断する。

## サポートされるMarkdown構文

標準ブロック(ロスレスなラウンドトリップ):

| Markdown                     | PTブロック                                  |
| ---------------------------- | ------------------------------------------- |
| `# Heading` から `######`    | h1〜h6ブロック                              |
| 通常の段落                   | normalブロック                              |
| `> Quote`                    | blockquote                                  |
| `- item` / `* item`          | 箇条書きリスト(2スペースインデントでネスト) |
| `1. item`                    | 番号付きリスト(2スペースインデントでネスト) |
| ` ```lang `                  | 言語指定付きのコードブロック                |
| `![alt](url)`                | imageブロック                               |

インラインマーク:

| Markdown      | PTマーク             |
| ------------- | -------------------- |
| `**bold**`    | `strong`             |
| `_italic_`    | `em`                 |
| `` `code` ``  | `code`               |
| `~~strike~~`  | `strikethrough`      |
| `[text](url)` | リンクアノテーション |

## 未知のブロック(不透明なフェンス)

コンバーターが認識しないブロック(プラグインのカスタムブロック、埋め込みなど)はHTMLコメントとして
シリアライズされる。

```markdown
<!--ec:block {"_type":"callout","level":"warning","text":"Be careful"} -->
```

ラウンドトリップを経ても無傷のまま残る。見たり移動させたりはできるが、**JSONを手で編集すると壊れる**。
書き込み時には元のPTブロックへとデシリアライズし直される。

## 書き込み時の判定

`create` / `update`では、フィールドごとに次のように分岐する。

- `portableText`フィールド + **文字列値** → 送信前にmarkdownをPTに変換
- `portableText`フィールド + **配列値** → 生のPTとして送信(変換なし)
- その他のフィールドタイプ → そのまま送信

```bash
# markdown文字列 — 自動でPTに変換される
npx emdash content create posts --data '{"title": "Hello", "body": "# Welcome\n\nThis is **bold**."}'

# 生のPT配列 — そのまま送られる
npx emdash content create posts --data '{"title": "Hello", "body": [{"_type": "block", "children": [{"_type": "span", "text": "Welcome"}]}]}'
```

## rawモードを使うべき場面

`--raw`でmarkdown変換を完全にスキップし、生のPT JSONを扱う。

- PT構造を厳密に制御する必要がある場合
- カスタムブロックタイプを扱っている場合
- アイテム間でPTを変換なしにコピーする場合
