# スキーマとシードファイル

> シードファイルの全形式(ルート構造、コレクション、タクソノミー、メニュー、リダイレクト、
> ウィジェットエリア、セクション、バイライン、`$media` / `$ref:`、冪等性、バリデーション)は
> [themes/seed-files](https://docs.emdashcms.com/themes/seed-files/)にある。
> フィールドタイプごとのオプションは[reference/field-types](https://docs.emdashcms.com/reference/field-types/)。
> ここに書くのは、公式と食い違う点と、公式に載っていない運用上の罠だけ。

## 目次

- [シードは稼働中サイトのマイグレーション手段ではない](#シードは稼働中サイトのマイグレーション手段ではない)(自動で入るのはスキーマだけ)
- [`supports`は6種類ある](#supportsは6種類ある)(`has_seo` / `routable`)
- [スラッグのルール](#スラッグのルール)
- [フィールドタイプで公式と食い違う点](#フィールドタイプで公式と食い違う点)
- [MCPで作れないフィールド、付けられない属性](#mcpで作れないフィールド付けられない属性)(`repeater`、`widget`)
- [タクソノミー名は後からクエリと突き合わせる](#タクソノミー名は後からクエリと突き合わせる)
- [シードのバリデーションでよく出るエラー](#シードのバリデーションでよく出るエラー)

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

### 自動で入るのはスキーマだけ

最初のリクエストでの自動適用は`includeContent`を付けずに`applySeed`を呼ぶ。コレクション・フィールド・
タクソノミーの定義・メニューなどの構造は入るが、**`content`・バイライン・タクソノミーのタームは入らない。**
空の一覧ページだけが並び、「シードが壊れている」と誤診しやすい。

コンテンツまで入れる経路は3つ:

- セットアップウィザードでサンプルコンテンツを含める
- dev-bypass(`/_emdash/api/setup/dev-bypass`)を踏む —— 既定で含む。`?content=0`で構造だけになる
- CLIで直接流す: `npx emdash seed seed/seed.json -d <DBファイル> --on-conflict update`

CLIの`-d`の既定は`./data.db`で、**Cloudflareアダプタのdevが使うD1とは別物**。devのD1は
`.wrangler/state/v3/d1/miniflare-D1DatabaseObject/*.sqlite`にあるので、パスを明示する。稼働中のdevに
CLIで流すとSQLiteへ直接書くだけでオブジェクトキャッシュは冷えず、流す前に開いた一覧の空の結果が残る
(観測)。`.wrangler/state/v3/{cache,kv}`を消してdevを再起動すると反映される。確認はステータスコードでは
なく描画されたHTMLの中身で行う —— 空の状態でも200が返る。

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

### `seo`だけは別の列`has_seo`に写り、`supports`の更新で巻き戻る

`_emdash_collections`には`supports`(JSON配列)とは別に`has_seo`と`routable`の列がある。効くのは列の側。

| 列         | 効果                                                              |
| ---------- | ----------------------------------------------------------------- |
| `has_seo`  | エントリに`data.seo`(OG画像を含むSEO値)を載せるか                 |
| `routable` | 公開時に「スラッグが空でないこと」を検査するだけ。SEOには効かない |
| 両方       | sitemapに載る条件は`has_seo = 1 AND routable = 1`                 |

- **`supports`だけを送る更新は`has_seo`を`supports.includes("seo")`で計算し直す。** `supports`に`"seo"`を
  含まないのに`has_seo = 1`のコレクションは、別の理由で`supports`を触った瞬間に黙ってSEOを失う。
  `supports`を変えるときは`hasSeo`を必ず添える(`schema_update_collection`もRESTの
  `PUT /_emdash/api/schema/collections/<slug>`も同じ実装を通る)
- OG画像を保ったままsitemapから外したいなら`routable: false`にする。`has_seo`を落とすとOG画像も消える
- シードでは`supports`に`"seo"`を書くのが`has_seo = 1`の表現になる(作成時は`hasSeo ?? supports.includes("seo")`)

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

## MCPで作れないフィールド、付けられない属性

稼働中サイトへ足すとき、MCPの`schema_create_field`だけでは届かないものがある(0.36で確認)。

- **`repeater`はMCPでは作れない。** `type`のenumに`repeater`が無く、`validation`も`subFields` /
  `minItems` / `maxItems`を受け付けない。管理画面のスキーマビルダーが叩いているRESTなら通る:

  ```
  POST /_emdash/api/schema/collections/<collection>/fields
  Authorization: Bearer ec_pat_...
  {
    "slug": "activities", "label": "活動", "type": "repeater",
    "validation": {
      "minItems": 1, "maxItems": 8,
      "subFields": [
        { "slug": "icon", "type": "select", "label": "アイコン", "options": ["code", "game"] },
        { "slug": "name", "type": "string", "label": "名前", "required": true }
      ]
    }
  }
  ```

  - 行数の上下限は`validation.minItems` / `maxItems`(`min` / `max`ではない)
  - サブフィールドの`select`の`options`は**フラットな文字列配列**で、値がそのまま表示ラベルになる
  - サブフィールドに使える型は`string` `text` `url` `number` `integer` `boolean` `datetime` `select` `image`
  - **`required: true`は空配列を防がない。** 列に`NOT NULL DEFAULT`を付けるだけで、配列の長さは見ない。
    1行以上を強制したいなら`minItems`に置く
  - 後から直すのは`PUT /_emdash/api/schema/collections/<collection>/fields/<field>`

- **`widget`は`schema_create_field`では付かない。** 引数に`widget`が無く、`options.widget`に入れても
  `options`の中に入るだけで、EmDashが読むトップレベルの`widget`は空のまま。作った直後に
  `schema_update_field`で`{ "widget": "field-kit:list" }`を送る(RESTのPOSTなら最初から`widget`を渡せる)。
  フィールドを消して作り直す必要はなく、既存の値は残る

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
