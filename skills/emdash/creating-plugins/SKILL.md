---
name: creating-plugins
description: フック、ストレージ、設定、管理UI、APIルート、Portable Textブロックタイプを備えたEmDash CMSプラグインを作成する。EmDashプラグインのビルド・スキャフォールド・実装を求められた場合や、カスタムブロックタイプ・管理ページ・コンテンツフックなどのプラグイン機能を作成する場合にこのスキルを使用する。
---

# EmDashプラグインの作成

EmDashプラグインは、フック、ストレージ、設定、管理UI、APIルート、カスタムPortable Textブロックタイプによって CMS を拡張する。すべてのプラグインはTypeScriptパッケージである。

## プラグインの種類

EmDashには2つのプラグイン形式がある。

| 種類         | 形式                                                    | 管理UI               | 実行場所                                             |
| ------------ | ------------------------------------------------------- | -------------------- | ---------------------------------------------------- |
| **Standard** | `definePlugin({ hooks, routes })`                       | Block Kit            | Cloudflareではアイソレート内、それ以外はインプロセス |
| **Native**   | `id`+`version`を伴う`createPlugin()` / `definePlugin()` | ReactまたはBlock Kit | 常にホストアイソレート内                             |

**Standardがデフォルトである。** ほとんどのプラグインはこれを使うべきである。Standardプラグインはマーケットプレイスに公開でき、trustedモードとsandboxedモードの両方で動作する。

**Nativeはエスケープハッチである。** ReactベースのAdmin UIコンポーネント、DBへの直接アクセス、カスタムAstroコンポーネントが必要なプラグイン向け。Nativeプラグインは`plugins: []`でのみ動作可能であり、サンドボックス化やマーケットプレイスへの公開はできない。

## プラグインの構造

すべてのプラグインには**異なるコンテキストで実行される**2つの部分がある。

1. **プラグインディスクリプタ**（`PluginDescriptor`）— `index.ts`内のファクトリ関数が返すもの。メタデータ（id、version、capabilities、storage）を宣言する。**Vite上でビルド時に実行される**（`astro.config.mjs`内でインポートされる）。副作用を持たないこと。
2. **プラグイン定義**（`definePlugin()`）— ランタイムロジック（hooks、routes）を含む。**デプロイされたサーバー上でリクエスト時に実行される**。完全なプラグインコンテキスト（`ctx`）にアクセスできる。別ファイル（通常は`sandbox-entry.ts`）に配置される。

これらはまったく異なる環境で実行されるため、**別々のエントリポイント**にする必要がある。

```
my-plugin/
├── src/
│   ├── index.ts            # ディスクリプタファクトリ（Viteでビルド時に実行）
│   ├── sandbox-entry.ts    # definePlugin()を伴うプラグイン定義（デプロイ時に実行）
│   ├── admin.tsx            # 管理UIエクスポート（React）— オプション、Native限定
│   └── astro/               # サイト側レンダリング用コンポーネント — オプション、Native限定
│       └── index.ts         # `blockComponents`をエクスポートする必要がある
├── package.json
└── tsconfig.json
```

## 最小構成のプラグイン（Standard形式）

最もシンプルなプラグイン -- フックのみ。

```typescript
// src/index.ts — ディスクリプタファクトリ、Viteでビルド時に実行される
import type { PluginDescriptor } from "emdash";

export function myPlugin(): PluginDescriptor {
  return {
    id: "my-plugin",
    version: "1.0.0",
    format: "standard",
    entrypoint: "@my-org/my-plugin/sandbox",
    options: {},
  };
}
```

```typescript
// src/sandbox-entry.ts — プラグイン定義、リクエスト時に実行される
import { definePlugin } from "emdash";
import type { PluginContext } from "emdash";

export default definePlugin({
  hooks: {
    "content:afterSave": {
      handler: async (event: any, ctx: PluginContext) => {
        ctx.log.info(`Saved ${event.collection}/${event.content.id}`);
      },
    },
  },
});
```

`astro.config.mjs`でインポートされるのはディスクリプタである。`entrypoint`フィールドは`definePlugin()`のデフォルトエクスポートを含むモジュールを指す。Standardプラグインの場合、これは`package.json`の`./sandbox`エクスポートとなる。

Native形式との主な違い。

- `definePlugin()`に`id`、`version`、`capabilities`を含めない -- それらはディスクリプタ側にある
- `definePlugin()`は型推論を提供する恒等関数である
- フックハンドラは`(event, ctx)`という2引数パターンを使う
- ルートハンドラは`(routeCtx, ctx)`という2引数パターンを使う
- ファクトリ関数ではなく`default`としてエクスポートする

## プラグインID規則

- 小文字英数字とハイフンのみ
- シンプル形式（`my-plugin`）またはスコープ付き（`@my-org/my-plugin`）
- インストール済みの全プラグインの中で一意であること

## 登録

ディスクリプタは`astro.config.mjs`（Viteコンテキスト）でインポートされる。

```typescript
import { myPlugin } from "@my-org/my-plugin";

export default defineConfig({
  integrations: [
    emdash({
      plugins: [myPlugin()], // インプロセスで実行
      // または
      sandboxed: [myPlugin()], // Cloudflare上のアイソレートで実行
    }),
  ],
});
```

Standardプラグインはどちらの配列でも動作する。Nativeプラグインは`plugins: []`でのみ動作する。

## Trustedモード vs Sandboxedモード

EmDashには2つの実行モードがある。プラグインコードはどちらも同一で、変わるのは強制の有無だけである。

|                          | Trusted                                             | Sandboxed                                                       |
| ------------------------ | --------------------------------------------------- | --------------------------------------------------------------- |
| **実行場所**             | メインプロセス                                      | 分離されたV8アイソレート（Dynamic Worker Loader）               |
| **インストール方法**     | `astro.config.mjs`（コード変更 + デプロイ）         | 管理UI（マーケットプレイスからワンクリック）                    |
| **Capabilities**         | 参考情報扱い（強制されない）                        | ランタイムでRPCブリッジ経由で強制される                         |
| **リソース制限**         | なし                                                | CPU 50ms、サブリクエスト10件、ウォールタイム30秒、メモリ約128MB |
| **ネットワークアクセス** | 無制限                                              | ブロックされる。`allowedHosts`を伴う`ctx.http`経由のみ          |
| **データアクセス**       | データベースへのフルアクセス                        | 宣言されたcapabilitiesにスコープされる                          |
| **Node.js API**          | フルアクセス                                        | 利用不可（V8アイソレートのみ）                                  |
| **利用可能な環境**       | 全プラットフォーム                                  | Cloudflare Workersのみ                                          |
| **適した用途**           | ファーストパーティコード、レビュー済みnpmパッケージ | サードパーティ拡張、マーケットプレイスプラグイン                |

### Trustedモード

Trustedプラグインは、`astro.config.mjs`に追加されたnpmパッケージまたはローカルファイルである。Astroサイトとインプロセスで実行される。

- **Capabilitiesはドキュメンテーション目的のみである。** `["content:read"]`を宣言することは意図の明示にはなるが強制はされない -- プラグインはプロセスへのフルアクセスを持つ。
- 信頼できるソースからのみインストールすること。悪意あるTrustedプラグインはアプリケーションコードと同等のアクセス権を持つ。

### Sandboxedモード

Sandboxedプラグインは、[Dynamic Worker Loader](https://developers.cloudflare.com/workers/runtime-apis/bindings/worker-loader/)を介してCloudflare Workers上の分離されたV8アイソレートで実行される。各プラグインは自身専用のアイソレートを持つ。

- **Capabilitiesは強制される。** プラグインが`["content:read"]`を宣言している場合、呼び出せるのは`ctx.content.get()`と`ctx.content.list()`のみである。`ctx.content.create()`を呼び出そうとすると権限エラーがスローされる。
- **ネットワークはデフォルトでブロックされる。** 直接の`fetch()`呼び出しは失敗する。プラグインは`allowedHosts`に対して検証を行う`ctx.http.fetch()`を使わなければならない。
- **ストレージはスコープされる。** プラグインは自身のKVとストレージコレクションにのみアクセスできる。
- **管理UIはBlock Kitを使う。** SandboxedプラグインはUIをJSONブロックとして記述する -- ブラウザ内でプラグインのJavaScriptは一切実行されない。[Block Kitリファレンス](./references/block-kit.md)を参照。
- **Portable Textブロックタイプは使えない。** PTブロックはサイト側レンダリング用のAstroコンポーネント（`componentsEntry`）を必要とし、これはビルド時にnpmからロードされる。Sandboxedプラグインはランタイムにインストールされるためコンポーネントを同梱できない。PTブロックはNativeプラグイン限定の機能である。
- **ルートは動作する。** Standardプラグインのルートは、sandboxランナーの`invokeRoute()` RPCを介してtrusted・sandboxedいずれのモードでも利用可能である。

サンドボックス化はNode.jsでは利用できない。Cloudflare以外のプラットフォームでは、すべてのプラグインがtrustedモードで実行される。

### 両モード向けの開発

同一のコードを書く。ローカルではtrustedモードで開発する（イテレーションが速く、デバッグが容易）。コード変更なしでプロダクションではsandboxedモードにデプロイできる。Standard形式では、同じエントリポイントが両モードに対応するため、別のsandboxエントリは不要である。

```typescript
// src/sandbox-entry.ts -- trusted・sandboxedいずれのモードでも動作する
import { definePlugin } from "emdash";
import type { PluginContext } from "emdash";

export default definePlugin({
  hooks: {
    "content:afterSave": {
      handler: async (event: any, ctx: PluginContext) => {
        // Trusted: ディスクリプタがnetwork:requestを宣言しているためctx.httpが存在する
        // Sandboxed: ctx.httpが存在し、RPCブリッジ経由で強制される
        if (!ctx.http) return;
        await ctx.http.fetch("https://api.analytics.example.com/track", {
          method: "POST",
          body: JSON.stringify({ contentId: event.content.id }),
        });
      },
    },
  },
});
```

サンドボックス互換性のための重要な制約: バックエンドコードでは**Node.jsの組み込みモジュール**（`fs`、`path`、`child_process`など）を使わないこと。代わりにWeb APIを使う。

## Capabilities

Capabilitiesは`ctx`上で利用可能なAPIを制御する。プラグインが必要とするものは常に宣言すること -- trustedモードであっても、意図を明示するものであり、sandboxed実行では必須となる。

| Capability                       | 付与される機能                                                            | `ctx`のプロパティ |
| -------------------------------- | ------------------------------------------------------------------------- | ----------------- |
| `content:read`                   | `ctx.content.get()`、`ctx.content.list()`                                 | `content`         |
| `content:write`                  | `ctx.content.create()`、`ctx.content.update()`、`ctx.content.delete()`    | `content`         |
| `media:read`                     | `ctx.media.get()`、`ctx.media.list()`                                     | `media`           |
| `media:write`                    | `ctx.media.getUploadUrl()`、`ctx.media.delete()`                          | `media`           |
| `network:request`                | `ctx.http.fetch()`（`allowedHosts`に制限される）                          | `http`            |
| `network:request:unrestricted`   | `ctx.http.fetch()`（無制限 — ユーザー設定のURL向け）                      | `http`            |
| `users:read`                     | `ctx.users.get()`、`ctx.users.list()`、`ctx.users.getByEmail()`           | `users`           |
| `email:send`                     | `ctx.email.send()` — パイプライン経由でメールを送信する                   | `email`           |
| `hooks.email-transport:register` | `email:deliver`排他フック（トランスポートプロバイダ）を登録できる         | —                 |
| `hooks.email-events:register`    | `email:beforeSend` / `email:afterSend`フックを登録できる                  | —                 |
| `hooks.page-fragments:register`  | `page:fragments`フック（ページへのスクリプト/スタイルの注入）を登録できる | —                 |

ストレージ（`ctx.storage`）とKV（`ctx.kv`）は**常に利用可能**であり、capabilityは不要である。自動的にプラグインにスコープされる。

**メール関連のcapabilitiesは明確に区別される。**

- `email:send` — メールを_消費する_（`ctx.email.send()`を呼び出す）プラグイン向け
- `hooks.email-transport:register` — メールを_配送する_（Resend、SMTPなどのトランスポートを実装する）プラグイン向け
- `hooks.email-events:register` — メールを_観察・変換する_（ミドルウェアフック）プラグイン向け

```typescript
// ディスクリプタ内（index.ts）
export function myPlugin(): PluginDescriptor {
  return {
    id: "my-plugin",
    version: "1.0.0",
    format: "standard",
    entrypoint: "@my-org/my-plugin/sandbox",
    options: {},
    capabilities: ["content:read", "network:request"],
    allowedHosts: ["api.example.com", "*.googleapis.com"], // ワイルドカード対応
  };
}
```

マーケットプレイスのプラグインをインストールする際、管理者にはプラグインがアクセスできる内容を列挙したcapability同意ダイアログが表示される。ユーザーはインストール前に承認する必要がある。

## マーケットプレイスへの公開

Standardプラグインは、ワンクリックインストールのためにEmDashマーケットプレイスに公開できる。

```bash
emdash plugin bundle --dir packages/plugins/my-plugin  # .tar.gzを作成
emdash plugin login                                      # GitHub経由で認証
emdash plugin publish --tarball dist/my-plugin-1.0.0.tar.gz
```

バンドル形式、検証、セキュリティ監査の詳細は[公開リファレンス](./references/publishing.md)を参照。

## パッケージのエクスポート

EmDashが各エントリポイントをロードできるよう`package.json`のexportsを設定する。

```json
{
  "name": "@my-org/my-plugin",
  "type": "module",
  "exports": {
    ".": "./src/index.ts",
    "./sandbox": "./src/sandbox-entry.ts",
    "./admin": "./src/admin.tsx"
  },
  "peerDependencies": {
    "emdash": "^0.1.0"
  }
}
```

| エクスポート  | コンテキスト       | 用途                                                                          |
| ------------- | ------------------ | ----------------------------------------------------------------------------- |
| `"."`         | Vite（ビルド時）   | ディスクリプタファクトリ -- `astro.config.mjs`でインポートされる              |
| `"./sandbox"` | サーバー（実行時） | `definePlugin({ hooks, routes })` -- `entrypoint`によって実行時にロードされる |
| `"./admin"`   | ブラウザ           | 管理ページ/ウィジェット向けのReactコンポーネント（Nativeプラグインのみ）      |
| `"./astro"`   | サーバー（SSR）    | サイト側のブロックレンダリング用Astroコンポーネント（Nativeプラグインのみ）   |

`"."`エクスポートにはディスクリプタが含まれる。`"./sandbox"`エクスポートには実装が含まれる。ディスクリプタの`entrypoint`フィールドは`"./sandbox"`を指す。`./admin`と`./astro`のエクスポートはNative形式のプラグインでのみ含める。

## プラグイン機能

各機能はオプションである。プラグインに必要なものだけを追加する。

| 機能                     | 場所                              | Standard | Native | 用途                                                        |
| ------------------------ | --------------------------------- | -------- | ------ | ----------------------------------------------------------- |
| **フック**               | `definePlugin({ hooks })`         | Yes      | Yes    | コンテンツ/メディア/ライフサイクルイベントへの反応          |
| **ストレージ**           | ディスクリプタの`storage`         | Yes      | Yes    | インデックス付きクエリを持つドキュメントコレクション        |
| **KV**                   | フック/ルート内の`ctx.kv`         | Yes      | Yes    | 内部状態用のキーバリューストア                              |
| **APIルート**            | `definePlugin({ routes })`        | Yes      | Yes    | `/_emdash/api/plugins/<id>/<route>`にあるRESTエンドポイント |
| **管理ページ**           | Block Kitの`admin`ルート          | Yes      | Yes    | Block Kit（JSONブロック）による管理ページ                   |
| **ウィジェット**         | Block Kitの`admin`ルート          | Yes      | Yes    | Block Kitによるダッシュボードカード                         |
| **React管理UI**          | `admin.entry` + Reactエクスポート | No       | Yes    | Reactベースの管理ページ/ウィジェット（Native限定）          |
| **PTブロック**           | `admin.portableTextBlocks`        | No       | Yes    | Portable Textエディタ内のカスタムブロックタイプ             |
| **サイトコンポーネント** | `componentsEntry`                 | No       | Yes    | サイト上でブロックをレンダリングするAstroコンポーネント     |

構文の詳細は各リファレンスファイルを参照。**今のタスクに関係するファイルだけを読むこと**(全referenceを一括で読み込まない)。

- **[フックリファレンス](./references/hooks.md)** — すべてのフックタイプ、シグネチャ、設定
- **[ストレージと設定](./references/storage.md)** — コレクション、KV、設定スキーマ
- **[管理UI](./references/admin-ui.md)** — ページ、ウィジェット、エントリポイントの構造
- **[APIルート](./references/api-routes.md)** — ルートハンドラ、バリデーション、コンテキスト
- **[Block Kit](./references/block-kit.md)** — サンドボックス化されたプラグイン向けの宣言的UI（Slack Block Kitに類似しているが同一ではない）
- **[Portable Textブロック](./references/portable-text-blocks.md)** — カスタムブロックタイプ + フロントエンドレンダリング
- **[公開](./references/publishing.md)** — バンドル形式、検証、マーケットプレイスへの公開
- **[完全なサンプル](./references/example-full-plugin.md)** — hooks・routes・storageを組み合わせたStandardプラグインの全体例。機能一覧とチェックリストだけで実装できる場合は読まなくてよい

## プラグインコンテキスト

すべてのフックとルートは`ctx`（PluginContext）を受け取る。

```typescript
interface PluginContext {
  plugin: { id: string; version: string };
  storage: Record<string, StorageCollection>; // 宣言済みコレクション
  kv: KVAccess; // キーバリューストア
  log: LogAccess; // 構造化ロガー
  content?: ContentAccess; // "content:read" capabilityがある場合
  media?: MediaAccess; // "media:read" capabilityがある場合
  http?: HttpAccess; // "network:request" capabilityがある場合
  users?: UserAccess; // "users:read" capabilityがある場合
  cron?: CronAccess; // 常に利用可能 — プラグインにスコープされる
  email?: EmailAccess; // "email:send" capabilityがあり、かつプロバイダが設定されている場合
}
```

Capabilitiesは（Standard形式の場合`definePlugin()`ではなく）**ディスクリプタ**で宣言する。

```typescript
// ディスクリプタ内
export function myPlugin(): PluginDescriptor {
  return {
    id: "my-plugin",
    version: "1.0.0",
    format: "standard",
    entrypoint: "@my-org/my-plugin/sandbox",
    options: {},
    capabilities: ["content:read", "network:request"],
    allowedHosts: ["api.example.com"],
    storage: { events: { indexes: ["timestamp"] } },
  };
}
```

## 出力チェックリスト

Standard形式のプラグインを作成する場合、以下を提供すること。

1. **`src/index.ts`** -- ディスクリプタファクトリ（Viteでビルド時に実行）
2. **`src/sandbox-entry.ts`** -- デフォルトエクスポートとしての`definePlugin({ hooks, routes })`（リクエスト時に実行）
3. **`package.json`** -- `"."`（ディスクリプタ）と`"./sandbox"`（実装）のエクスポートを含む
4. **`tsconfig.json`** -- 標準的なTypeScript設定

Native形式のプラグイン（React管理UI、PTブロック、Astroコンポーネント）の場合、以下も提供すること。

5. **`src/admin.tsx`** -- Reactコンポーネントを含む管理エントリポイント
6. **`src/astro/index.ts`** -- ブロックコンポーネントのエクスポート（PTブロックがある場合）
</content>
