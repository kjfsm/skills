# 編集フロー

CLIを通じたコンテンツ編集の仕組み。Portable Text変換、`_rev`トークン、rawモードについて解説します。

## Portable TextとMarkdown

EmDashはリッチテキストを[Portable Text](https://portabletext.org/)(PT)——構造化されたJSON形式——として保存します。CLIはPTとmarkdownの間を自動的に変換するため、使い慣れたテキスト形式で作業できます。

### 自動変換

- **読み取り時**: `portableText`フィールド内のPT配列がmarkdown文字列に変換されます
- **書き込み時**: `portableText`フィールド内のmarkdown文字列がPT配列に変換し直されます
- **PT以外のフィールド**(string、text、numberなど)はそのまま変更されずに通過します

CLIはコレクションのフィールドスキーマを取得することで、どのフィールドに変換が必要かを検知します。

### サポートされるMarkdown構文

標準ブロック(ロスレスなラウンドトリップ):

| Markdown                     | PT block                                    |
| ---------------------------- | ------------------------------------------- |
| `# Heading` through `######` | h1〜h6ブロック                              |
| Plain paragraph              | normalブロック                              |
| `> Quote`                    | blockquote                                  |
| `- item` / `* item`          | 箇条書きリスト(2スペースインデントでネスト) |
| `1. item`                    | 番号付きリスト(2スペースインデントでネスト) |
| ` ``` ```lang``` `           | 言語指定付きのコードブロック                |
| `![alt](url)`                | imageブロック                               |

インラインマーク:

| Markdown      | PT mark              |
| ------------- | -------------------- |
| `**bold**`    | `strong`             |
| `_italic_`    | `em`                 |
| `` `code` ``  | `code`               |
| `~~strike~~`  | `strikethrough`      |
| `[text](url)` | リンクアノテーション |

### 未知のブロック(不透明なフェンス)

コンバーターが認識しないブロック(カスタムブロック、埋め込みなど)はHTMLコメントとしてシリアライズされます。

```markdown
<!--ec:block {"_type":"callout","level":"warning","text":"Be careful"} -->
```

これらはラウンドトリップを経ても無傷のまま残ります。見たり移動させたりはできますが、JSONを編集すると破損するおそれがあります。書き込み時には、元のPTブロックへとデシリアライズし直されます。

### Rawモード

markdown変換を完全にスキップして、生のPT JSONを扱います。

```bash
npx emdash content get posts 01ABC123 --raw
```

以下の場合にrawモードを使用してください。

- PT構造を厳密に制御する必要がある場合
- カスタムブロックタイプを扱っている場合
- アイテム間でPTを変換なしにコピーする場合

### コンテンツの書き込み

コンテンツの作成または更新時、各フィールドは以下のようにチェックされます。

- `portableText`フィールド + **文字列値** → 送信前にmarkdownをPTに変換
- `portableText`フィールド + **配列値** → 生のPTとして送信(変換なし)
- その他のフィールドタイプ → そのまま送信

```bash
# Markdown string — converted to PT automatically
npx emdash content create posts --data '{"title": "Hello", "body": "# Welcome\n\nThis is **bold**."}'

# Raw PT array — passed through as-is
npx emdash content create posts --data '{"title": "Hello", "body": [{"_type": "block", "children": [{"_type": "span", "text": "Welcome"}]}]}'
```

## 自動公開

このCLIはエージェント向けに設計されています。デフォルトで`create`と`update`時に自動的に公開するため、エージェントはドラフト/公開のライフサイクルを管理することなく読み取り後書き込みの一貫性を得られます。

### 仕組み

- **`create`** — アイテムを作成した後、公開します。返されるアイテムは`published`ステータスになります。
- **`update`** — アイテムを更新します。コレクションがリビジョンを使用しており、更新によってドラフトリビジョンが作成された場合、自動的に公開してドラフトをcontentテーブルに昇格させます。返されるアイテムには更新後のデータが反映されます。
- **`get`** — 最新の状態を返します。保留中のドラフトが存在する場合(例: 誰かが管理UIで編集したが公開しなかった)、公開済みデータの代わりにドラフトデータが返されます。公開済みデータのみを見るには`--published`を使用してください。

自動公開をスキップするにはcreate/updateで`--draft`を使用してください。

### なぜ自動公開なのか

EmDashのコレクションはドラフトリビジョンをサポートできます。サポートしている場合、`update`はcontentテーブルではなくドラフトリビジョンにデータを書き込みます。自動公開がなければ、エージェントはupdateした後に`get`でアイテムを取得すると、今まさに行った変更ではなく古い公開済みデータを目にすることになります。自動公開はこの混乱を解消します。

## 読み取ってから書き込む

更新には楽観的並行性制御のために`_rev`トークンが使用されます——これはファイルを編集する前に読み取ることを要求するファイル編集ツールと同じ原則です。上書きしようとしている内容を必ず確認しなければなりません。

### たとえ話

ファイルシステムの編集ツールだと考えてみてください。

1. ファイルの現在の内容を確認するために**読み取る**
2. 何を変更するか決める
3. 読み取ったバージョンへの参照とともに**書き込む**

読み取りと書き込みの間に他の誰かがファイルを変更していた場合、書き込みは失敗します——見ていない変更を上書きすることはできません。`_rev`トークンは、あなたが現在の状態を確認したことの証明です。

### 仕組み

1. `content get`は出力に`_rev`トークンを含めてアイテムを返します
2. その`_rev`を`--rev`経由で`content update`に渡し戻します
3. サーバーは、読み取り以降にアイテムが変更されているかをチェックし、変更されていれば**409 Conflict**を返します
4. 更新が成功すると、以降の編集のために新しい`_rev`が返されます

### `_rev`トークンとは何か

不透明なbase64文字列です。パースせず、そのまま渡し戻してください。

### CLIのワークフロー

CLIは更新時に`--rev`を**必須**とします。典型的なワークフローは以下の通りです。

```bash
# 1. Read the item — note the _rev in the output
npx emdash content get posts 01ABC123
# Output includes: _rev: MToyMDI2LTAyLTE0...

# 2. Update with the _rev you received — auto-publishes by default
npx emdash content update posts 01ABC123 \
  --rev MToyMDI2LTAyLTE0... \
  --data '{"title": "New Title"}'
# Output shows updated item with new _rev
```

`--rev`なしで更新しようとすると、CLIはコマンドを拒否します。これにより、常に何を上書きしようとしているかを把握できます。

### 競合の処理

読み取りと書き込みの間に他の誰かがアイテムを更新していた場合:

```
EmDashApiError: Content has been modified since last read (version conflict)
  status: 409
  code: CONFLICT
```

解決方法: `get`で再読み込みし、新しい状態を確認したうえで、最新の`_rev`を使って`update`してください。

### `_rev`が必要な操作はどれか

`update`のみです。それ以外の操作はすべて冪等または非破壊的です。

| コマンド            | `--rev`は必要か? | 理由                             |
| ------------------- | ---------------- | -------------------------------- |
| `content create`    | 不要             | まだ何も存在しないため           |
| `content update`    | **必要**         | 既存データを上書きするため       |
| `content delete`    | 不要             | ソフトデリートで、元に戻せるため |
| `content publish`   | 不要             | 冪等なステータス変更             |
| `content unpublish` | 不要             | 冪等なステータス変更             |
| `content schedule`  | 不要             | メタデータのみを変更するため     |
| `content restore`   | 不要             | ゴミ箱から復元するため           |
