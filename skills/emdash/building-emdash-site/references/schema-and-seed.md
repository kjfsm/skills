# スキーマとシードファイル

> シードファイルの全形式(ルート構造、コレクション、タクソノミー、メニュー、リダイレクト、
> ウィジェットエリア、セクション、バイライン、`$media` / `$ref:`、冪等性、バリデーション)は
> [themes/seed-files](https://docs.emdashcms.com/themes/seed-files/)にある。
> フィールドタイプごとのオプションは[reference/field-types](https://docs.emdashcms.com/reference/field-types/)。
> ここに書くのは、公式と食い違う点と、公式に載っていない運用上の罠だけ。

## シードは稼働中サイトのマイグレーション手段ではない

これが最大の罠。`.emdash/seed.json` / `package.json#emdash.seed` / `seed/seed.json`のシードはビルドに
インライン化され、**データベースが空でセットアップウィザードが完了していない場合に、最初のリクエスト時にのみ**
適用される。

**この「最初のリクエスト時のみ」という制約は、コンテンツだけでなくコレクション定義・フィールドなど
スキーマ全体に及ぶ。** 一度DBが初期化された(空でなくなった)後は、`seed/seed.json`に新しいコレクション・
フィールド・コンテンツを追加してデプロイしても、既存インスタンスには自動反映されない —— コードと本番の
スキーマがズレたままになる。

稼働中のインスタンスへスキーマ変更やコンテンツを反映するには、次のいずれかで直接操作する:

- 管理画面
- CLI(`emdash schema create-collection`などのリモートコマンド)
- 接続済みMCPツール(`schema_create_collection` / `schema_create_field` / `content_create`など)

考え方は[deployment/schema-evolution](https://docs.emdashcms.com/deployment/schema-evolution/)を参照。

## `supports`は6種類ある

公式のSeed File Formatは`"drafts"`と`"revisions"`しか挙げていないが、実際に受け付けるのは次の6つ。

| Support      | 説明                          |
| ------------ | ----------------------------- |
| `drafts`     | 下書き/公開ワークフロー       |
| `revisions`  | リビジョン履歴                |
| `preview`    | 下書きの署名付きプレビューURL |
| `scheduling` | 公開日時の予約                |
| `search`     | 全文検索インデックス          |
| `seo`        | 管理画面のSEOメタフィールド   |

省略した場合の既定は`["drafts", "revisions"]`。

## スラッグのルール

コレクションとフィールドのスラッグは`/^[a-z][a-z0-9_]*$/`(先頭は英小文字、以降は英小文字・数字・
アンダースコア)かつ**63文字以内**。63はPostgresの識別子長制限に合わせたもので、公式ドキュメントには
書かれていない。ハイフンは使えない(タクソノミー名やタームのスラッグでは使える)。

## フィールドタイプで公式と食い違う点

- **`image` / `file`のランタイム値は`src`であって`url`ではない。**
  `image` → `{ id, src?, alt?, width?, height?, provider?, previewUrl?, meta? }`、
  `file` → `{ id, src?, filename?, mimeType?, size?, provider?, meta? }`。
  公式のField Types Referenceは`url`と書いているが、テンプレートから読めるのは`src`。
- **`select`の選択肢は`validation.options`に入れる。** `defaultValue`と併用する:

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

- Seed File Formatの「Field Types」表は`date` / `email`を挙げ、`select` / `multiSelect` / `repeater`を
  落としているが、実装が受け付けるのは[reference/field-types](https://docs.emdashcms.com/reference/field-types/)の
  16種のほう(`string` `text` `url` `slug` `number` `integer` `boolean` `datetime` `select` `multiSelect`
  `portableText` `image` `file` `reference` `json` `repeater`)。

## タクソノミー名は後からクエリと突き合わせる

シードの`"name"`はそのまま`getTerm(name, slug)` / `getEntryTerms(..., name)` / `where: { name: ... }`の
引数になる。`"category"`と定義したなら`"categories"`ではクエリできず、**エラーなしで空の結果**が返る。
ブログでは慣例的に単数形(`category` / `tag`)を使う。

## シードのバリデーションでよく出るエラー

シードが不正な場合、最初のリクエストが失敗してエラーがログに残る。修正後はdevサーバーを再起動する。

- 画像フィールドに生のURLが指定されている(`$media`を使う)
- 参照フィールドに生のIDが指定されている(`$ref:id`を使う)
- PortableTextが配列でない、または`_type`が欠けている
- 型の不一致(文字列と数値の混在など)
