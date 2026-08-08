---
name: emdash-cli
description: コンテンツ、スキーマ、メディアなどを管理するためにEmDash CLIを使用します。実行中のEmDashインスタンスとコマンドラインからやり取りする必要があるとき——コンテンツの作成、コレクションの管理、メディアのアップロード、型の生成、CMS操作のスクリプト化など——にこのスキルを使用してください。
---

# EmDash CLI

EmDash CLI(`emdash`、通常は`npx emdash`で実行)はEmDash CMSインスタンスを管理します。コマンドは2つのカテゴリに分かれます。

- **ローカルコマンド** — SQLiteファイルを直接操作し、サーバーの起動は不要: `init`、`dev`、`seed`、`export-seed`、`secrets`、`doctor`
- **リモートコマンド** — HTTP経由で実行中のEmDashインスタンスと通信: `types`、`login`、`logout`、`whoami`、`content`、`schema`、`media`、`search`、`taxonomy`、`menu`、`plugin`

## 認証

リモートコマンドは認証情報を自動的に解決します。

1. `--token`フラグ
2. `EMDASH_TOKEN`環境変数
3. `emdash login`から保存された認証情報
4. Dev bypass(localhostのみ——トークン不要)

ローカルの開発サーバーの場合は、コマンドを実行するだけで認証は自動的に処理されます。リモートインスタンスの場合は、まず`emdash login --url https://my-site.pages.dev`を実行してください。

## クイックリファレンス

### データベースのセットアップ

マイグレーションとシードの適用はランタイム内部で自動的に行われます——別途init/seedの手順は不要です。開発サーバーを起動する(またはデプロイする)だけで、最初のリクエストで保留中のマイグレーションが実行され、データベースが空であればバンドルされたシードが適用されます。

```bash
# Start dev server (runs migrations, applies seed on empty DB, starts Astro)
npx emdash dev

# Start dev server and generate types from remote
npx emdash dev --types

# Export an existing database as a seed file
# (the runtime auto-discovers .emdash/seed.json on first boot;
# `mkdir -p` because the directory may not exist yet)
mkdir -p .emdash
npx emdash export-seed > .emdash/seed.json
npx emdash export-seed --with-content > .emdash/seed.json
```

### 型の生成

```bash
# Generate types from local dev server
npx emdash types

# Generate from remote
npx emdash types --url https://my-site.pages.dev

# Custom output path
npx emdash types --output src/types/cms.ts
```

既定では`.emdash/types.ts`(TypeScriptインターフェース)と`.emdash/schema.json`を書き出します。
(このリポジトリがtsconfigでincludeする`emdash-env.d.ts`はEmDashインテグレーションがdevサーバー
起動時に自動生成するもの。型を更新したいときはdevサーバーを起動し直すのが手軽。)

### 認証

```bash
# Login (OAuth Device Flow)
npx emdash login --url https://my-site.pages.dev

# Check current user
npx emdash whoami

# Logout
npx emdash logout

# デプロイ用の暗号化鍵(EMDASH_ENCRYPTION_KEY)を生成する
npx emdash secrets generate
```

### コンテンツのCRUD

このCLIはエージェント向けに設計されています。createとupdateはデフォルトで自動的にpublishされるため、エージェントはドラフトを管理することなく読み取り後書き込みの一貫性を得られます。

```bash
# List content
npx emdash content list posts
npx emdash content list posts --status published --limit 10

# Get a single item (Portable Text fields converted to markdown)
# Returns draft data if a pending draft exists
npx emdash content get posts 01ABC123
npx emdash content get posts 01ABC123 --raw        # skip PT->markdown conversion
npx emdash content get posts 01ABC123 --published   # ignore pending drafts

# Create content (auto-publishes by default)
npx emdash content create posts --data '{"title": "Hello", "body": "# World"}'
npx emdash content create posts --file post.json --slug hello-world
npx emdash content create posts --draft --data '...'  # keep as draft
cat post.json | npx emdash content create posts --stdin

# Update (requires --rev from a prior get, auto-publishes by default)
npx emdash content update posts 01ABC123 --rev MToyMDI2... --data '{"title": "Updated"}'
npx emdash content update posts 01ABC123 --rev MToyMDI2... --draft --data '...'  # keep as draft

# Delete (soft delete)
npx emdash content delete posts 01ABC123

# Lifecycle
npx emdash content publish posts 01ABC123
npx emdash content unpublish posts 01ABC123
npx emdash content schedule posts 01ABC123 --at 2026-03-01T09:00:00Z
npx emdash content restore posts 01ABC123
```

### スキーマ管理

```bash
# List collections
npx emdash schema list

# Get collection with fields
npx emdash schema get posts

# Create collection
npx emdash schema create articles --label Articles --description "Blog articles"

# Delete collection
npx emdash schema delete articles --force

# Add field
npx emdash schema add-field posts body --type portableText --label "Body Content"
npx emdash schema add-field posts featured --type boolean --required

# Remove field
npx emdash schema remove-field posts featured
```

フィールドタイプ(16種): `string`、`text`、`url`、`slug`、`number`、`integer`、`boolean`、`datetime`、`select`、`multiSelect`、`portableText`、`image`、`file`、`reference`、`json`、`repeater`。詳細は`search_docs`(Field Types Reference)を参照してください。

### メディア

```bash
# List media
npx emdash media list
npx emdash media list --mime image/png

# Upload
npx emdash media upload ./photo.jpg --alt "A sunset" --caption "Bristol, 2026"

# Get / delete
npx emdash media get 01MEDIA123
npx emdash media delete 01MEDIA123
```

### 検索

```bash
npx emdash search "hello world"
npx emdash search "hello" --collection posts --limit 5
```

### タクソノミー

```bash
npx emdash taxonomy list
npx emdash taxonomy terms categories
npx emdash taxonomy add-term categories --name "Tech" --slug tech
npx emdash taxonomy add-term categories --name "Frontend" --parent 01PARENT123
```

### メニュー

```bash
npx emdash menu list
npx emdash menu get primary
```

## ドラフトと公開

CLIはデフォルトで`create`と`update`時に自動公開します。つまり以下の通りです。

- **`create`**はアイテムを作成し、即座に公開します
- **`update`**はアイテムを更新し、ドラフトリビジョンが作成された場合は公開します
- **`get`**は保留中のドラフトが存在する場合(例: 管理UIからの変更)、ドラフトデータを返します

自動公開をスキップするにはcreate/updateで`--draft`を使用してください。保留中のドラフトを無視するにはgetで`--published`を使用してください。

リビジョンをサポートするコレクションは、編集内容をドラフトリビジョンとして保存します。CLIはこれを透過的に処理するため、エージェントはコレクションがリビジョンを使用しているかどうかを知る必要はありません。

## JSON出力

すべてのリモートコマンドは機械可読な出力のために`--json`をサポートしています。標準出力がパイプされている場合は自動的に有効になります。

```bash
# Pipe to jq
npx emdash content list posts --json | jq '.items[].slug'

# Use in scripts
ID=$(npx emdash content create posts --data '{"title":"Hello"}' --json | jq -r '.id')
```

## 編集フロー

コンテンツ編集の仕組み——Portable Text/markdown変換、`_rev`トークン、rawモード——の詳細については**[EDITING-FLOW.md](./EDITING-FLOW.md)**を参照してください。
