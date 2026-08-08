---
name: creating-plugins
description: フック、ストレージ、設定、管理UI、APIルート、Portable Textブロックタイプを備えたEmDash CMSプラグインを作成する。EmDashプラグインのビルド・スキャフォールド・実装を求められた場合や、カスタムブロックタイプ・管理ページ・コンテンツフックなどのプラグイン機能を作成する場合にこのスキルを使用する。APIの一次情報源は公式ドキュメントで、このスキルは公式が扱っていないnpm配布形式と実地の落とし穴を扱う。
---

# EmDashプラグインの作成

## このスキルの読み方

**一次情報源は公式ドキュメント <https://docs.emdashcms.com/> である。** フック一覧、`ctx`のAPI、
ストレージ、Block Kit、capabilities、マニフェスト、公開手順はすべて公式にある。MCPサーバー
(`https://docs.emdashcms.com/mcp`)を接続していれば`search_docs`でも引ける。

このスキルに書いてあるのは次の2つだけ:

1. **公式が扱っていないこと** — npmパッケージとして配る`format: "standard"`ディスクリプタ形式、
   Block Kitの未文書化ブロック
2. **実地で踏んだ落とし穴**

フックのシグネチャやストレージAPIを調べたいなら、まず公式を読むこと。

## 公式ドキュメントの該当ページ

| 調べたいこと                        | 公式ページ                                                                                                                                                            |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| プラグイン形式の選択                | [creating-plugins/choosing-a-format](https://docs.emdashcms.com/plugins/creating-plugins/choosing-a-format/)                                                          |
| 最初のプラグイン                    | [creating-plugins/your-first-plugin](https://docs.emdashcms.com/plugins/creating-plugins/your-first-plugin/)                                                          |
| マニフェスト(`emdash-plugin.jsonc`) | [creating-plugins/manifest](https://docs.emdashcms.com/plugins/creating-plugins/manifest/)                                                                            |
| フック(全種類・シグネチャ・設定)    | [reference/hooks](https://docs.emdashcms.com/reference/hooks/)                                                                                                        |
| APIルート                           | [creating-plugins/api-routes](https://docs.emdashcms.com/plugins/creating-plugins/api-routes/)                                                                        |
| ストレージ / KV / 設定              | [creating-plugins/storage](https://docs.emdashcms.com/plugins/creating-plugins/storage/) ・ [settings](https://docs.emdashcms.com/plugins/creating-plugins/settings/) |
| Block Kit                           | [creating-plugins/block-kit](https://docs.emdashcms.com/plugins/creating-plugins/block-kit/)                                                                          |
| Capabilities とセキュリティ         | [creating-plugins/capabilities](https://docs.emdashcms.com/plugins/creating-plugins/capabilities/)                                                                    |
| バンドルと公開                      | [creating-plugins/publishing](https://docs.emdashcms.com/plugins/creating-plugins/publishing/)                                                                        |
| React管理UI(native限定)             | [creating-native-plugins/react-admin](https://docs.emdashcms.com/plugins/creating-native-plugins/react-admin/)                                                        |
| Portable Textブロック               | [creating-native-plugins/portable-text-components](https://docs.emdashcms.com/plugins/creating-native-plugins/portable-text-components/)                              |

## 公式が扱っていない第3の形式: npm配布の`format: "standard"`

公式ドキュメントはプラグインを **sandboxed**(`emdash-plugin.jsonc` + `src/plugin.ts`、`emdash-plugin`
CLIでバンドルしてマーケットプレイスに公開)と **native**(`definePlugin()`ディスクリプタ、npm +
`astro.config.mjs`)の2つとして説明している。

実装にはもう1つ、両者の中間にあたる`format: "standard"`のディスクリプタがある。**マーケットプレイスに
出さず、npmパッケージ(あるいはワークスペース内のパッケージ)として自分のサイトに配りたいときはこれを使う。**

|          | 公式のsandboxed             | **standard(この形式)**                            | 公式のnative             |
| -------- | --------------------------- | ------------------------------------------------- | ------------------------ |
| 宣言     | `emdash-plugin.jsonc`       | `PluginDescriptor` + `format: "standard"`         | `PluginDescriptor`(既定) |
| 実装     | `src/plugin.ts`             | `definePlugin({ hooks, routes })`をdefault export | `createPlugin(options)`  |
| 配布     | マーケットプレイス(.tar.gz) | npm                                               | npm                      |
| 置き場所 | `sandboxed: []`             | `plugins: []`・`sandboxed: []`のどちらでも可      | `plugins: []`のみ        |

ハンドラの中身のコードは公式のsandboxedとまったく同じ(同じ`SandboxedPlugin`型、同じフック名、同じ
`PluginContext`)。**したがってフック・ルート・ストレージの書き方は公式のsandboxed向けドキュメントを
そのまま読めばよい。** 違うのは外側の宣言だけ。

### 2つのエントリポイントを分ける

ディスクリプタとプラグイン定義は**異なるコンテキストで実行される**ため、別ファイルにする。

1. **ディスクリプタ**(`src/index.ts`)— `astro.config.mjs`からインポートされ、**Vite上でビルド時に**
   実行される。メタデータ(id、version、capabilities、storage)を宣言するだけ。副作用を持たせないこと。
2. **プラグイン定義**(`src/sandbox-entry.ts`)— `entrypoint`から**デプロイ先サーバー上でリクエスト時に**
   ロードされる。`ctx`にアクセスできるのはこちら。

```
my-plugin/
├── src/
│   ├── index.ts            # ディスクリプタファクトリ(ビルド時)
│   └── sandbox-entry.ts    # definePlugin({ hooks, routes })(実行時)
├── package.json
└── tsconfig.json
```

```typescript
// src/index.ts
import type { PluginDescriptor } from "emdash";

export function myPlugin(): PluginDescriptor {
  return {
    id: "my-plugin", // 小文字英数字とハイフン。URLの1セグメントに入るので他の文字は不可
    version: "1.0.0",
    format: "standard", // 省略すると "native" 扱いになる
    entrypoint: "@my-org/my-plugin/sandbox",
    options: {}, // standardでは使われない(設定はKVから読む)
    capabilities: ["content:read", "network:request"],
    allowedHosts: ["api.example.com"], // network:request には必須。ワイルドカード可
    storage: { events: { indexes: ["timestamp"] } },
    adminPages: [{ path: "/settings", label: "Settings", icon: "settings" }],
  };
}
```

```typescript
// src/sandbox-entry.ts
import { definePlugin } from "emdash";
import type { PluginContext } from "emdash";

export default definePlugin({
  hooks: {
    "content:afterSave": {
      handler: async (event, ctx: PluginContext) => {
        ctx.log.info(`Saved ${event.collection}/${event.content.id}`);
      },
    },
  },
  routes: {
    // ルートハンドラは (routeCtx, ctx) の2引数。routeCtx が input/request を持つ
    status: {
      handler: async (_routeCtx, ctx) => ({ ok: true, plugin: ctx.plugin.id }),
    },
  },
});
```

```json
// package.json — entrypoint が指すエクスポートを用意する
{
  "exports": {
    ".": "./src/index.ts",
    "./sandbox": "./src/sandbox-entry.ts"
  }
}
```

```javascript
// astro.config.mjs
emdash({
  plugins: [myPlugin()], // インプロセス実行
  // sandboxed: [myPlugin()],  // Cloudflareのアイソレート実行(同じコードのまま動く)
});
```

`plugins: []`(trusted)ではcapabilitiesも`PluginContextFactory`が同じように解釈するが、隔離もリソース制限も
無い。`sandboxed: []`ではサンドボックスランナーが強制する。差は
[choosing-a-format](https://docs.emdashcms.com/plugins/creating-plugins/choosing-a-format/)にある表のとおり。

### nativeが必要になる条件

React製の管理ページ、Portable Textブロックの**サイト側レンダリング**コンポーネント(`componentsEntry`)、
`page:fragments`による生HTML/スクリプト注入のいずれかが要るときだけ`format: "native"`にする
(`plugins: []`専用になる)。ブロックタイプの**宣言**自体はディスクリプタの`portableTextBlocks`でstandardからも
できる —— nativeが要るのはレンダリングコンポーネントを同梱する場合。

## 実地の落とし穴

1. **ルートハンドラで`ctx.request.json()`を呼ばない。** EmDashはリクエストボディを一度だけパースして
   `routeCtx.input`として渡す。ハンドラ側で読もうとするとボディストリームが消費済みで失敗する。
   `input`にZodスキーマを付ければ型付きで受け取れる。

2. **Block Kitの管理ルートは常に`admin`という名前。** マニフェスト/ディスクリプタの`adminPages[].path`が
   何であれ、管理画面がインタラクションを投げる先は`/_emdash/api/plugins/<plugin-id>/admin`で、`path`は
   サイドバーのリンクにしか使われない。ページを出し分けるには`interaction.page`を見る。

3. **バックエンドコードでNode.js組み込みモジュール(`fs`、`path`、`child_process`など)を使わない。**
   Web APIで書く。使うとサンドボックス実行に載せられなくなり、バンドル時の検証でも弾かれる。

4. **プラグインルートはデフォルトで認証必須。** 匿名で叩けるようにするには明示的に`public: true`を
   付ける(その場合CSRFチェックも外れるので入力を必ず検証する)。

## リファレンスドキュメント

- **[references/block-kit.md](references/block-kit.md)** — 公式のBlock Kitページに載っていないブロック
  (`chart` / `banner` / `meter` / `code`)と要素(`checkbox` / `radio` / `date_input` / `combobox` /
  `repeater` / `media_picker`)の構文
