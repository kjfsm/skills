# フックリファレンス

フックを使うと、プラグインはイベントに応じてコードを実行できる。`definePlugin({ hooks })`で宣言する。

## シグネチャ

```typescript
async (event: EventType, ctx: PluginContext) => ReturnType;
```

## 設定

シンプルなハンドラ、または完全な設定のいずれかで記述できる。

```typescript
// シンプル
hooks: {
	"content:afterSave": async (event, ctx) => {
		ctx.log.info("Saved");
	}
}

// 完全な設定
hooks: {
	"content:afterSave": {
		priority: 100,      // 値が小さいほど先に実行される（デフォルト: 100）
		timeout: 5000,      // 最大実行時間（ミリ秒、デフォルト: 5000）
		dependencies: [],   // 先に実行される必要があるプラグインID
		errorPolicy: "abort", // "abort" | "continue"
		handler: async (event, ctx) => {
			ctx.log.info("Saved");
		}
	}
}
```

## ライフサイクルフック

### `plugin:install`

初回インストール時に一度だけ実行される。デフォルト値のシードに使う。

```typescript
"plugin:install": async (_event, ctx) => {
	await ctx.kv.set("settings:enabled", true);
	await ctx.storage.items!.put("default", { name: "Default" });
}
```

Event: `{}`
Returns: `void`

### `plugin:activate`

プラグインが有効化されたとき（インストール後または再有効化時）に実行される。

```typescript
"plugin:activate": async (_event, ctx) => {
	ctx.log.info("Activated");
}
```

Event: `{}`
Returns: `void`

### `plugin:deactivate`

プラグインが無効化されたとき（削除ではない）に実行される。

```typescript
"plugin:deactivate": async (_event, ctx) => {
	ctx.log.info("Deactivated");
}
```

Event: `{}`
Returns: `void`

### `plugin:uninstall`

プラグインが削除されたときに実行される。`event.deleteData`がtrueの場合のみデータを削除すること。

```typescript
"plugin:uninstall": async (event, ctx) => {
	if (event.deleteData) {
		const result = await ctx.storage.items!.query({ limit: 1000 });
		await ctx.storage.items!.deleteMany(result.items.map(i => i.id));
	}
}
```

Event: `{ deleteData: boolean }`
Returns: `void`

## コンテンツフック

### `content:beforeSave`

保存前に実行される。変更後のコンテンツを返すか、変更しない場合はvoidを返すか、キャンセルする場合はthrowする。

```typescript
"content:beforeSave": async (event, ctx) => {
	const { content, collection, isNew } = event;

	if (collection === "posts" && !content.title) {
		throw new Error("Posts require a title");
	}

	// 変換
	if (content.slug) {
		content.slug = content.slug.toLowerCase().replace(/\s+/g, "-");
	}

	return content;
}
```

Event: `{ content: Record<string, unknown>, collection: string, isNew: boolean }`
Returns: `Record<string, unknown> | void`

### `content:afterSave`

保存成功後に実行される。副作用のみ（ロギング、通知、同期など）。

```typescript
"content:afterSave": async (event, ctx) => {
	const { content, collection, isNew } = event;
	ctx.log.info(`${isNew ? "Created" : "Updated"} ${collection}/${content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string, isNew: boolean }`
Returns: `void`

### `content:beforeDelete`

削除前に実行される。キャンセルする場合は`false`を、許可する場合は`true`またはvoidを返す。

```typescript
"content:beforeDelete": async (event, ctx) => {
	if (event.collection === "pages" && event.id === "home") {
		ctx.log.warn("Cannot delete home page");
		return false;
	}
	return true;
}
```

Event: `{ id: string, collection: string }`
Returns: `boolean | void`

### `content:afterDelete`

削除成功後に実行される。

```typescript
"content:afterDelete": async (event, ctx) => {
	ctx.log.info(`Deleted ${event.collection}/${event.id}`);
	await ctx.storage.cache!.delete(`${event.collection}:${event.id}`);
}
```

Event: `{ id: string, collection: string }`
Returns: `void`

### `content:afterPublish`

コンテンツが公開された（ドラフトから公開済みに昇格した）後に実行される。副作用のみ。

```typescript
"content:afterPublish": async (event, ctx) => {
	ctx.log.info(`Published ${event.collection}/${event.content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string }`
Returns: `void`

### `content:afterUnpublish`

コンテンツが非公開化された（ドラフトに戻された）後に実行される。副作用のみ。

```typescript
"content:afterUnpublish": async (event, ctx) => {
	ctx.log.info(`Unpublished ${event.collection}/${event.content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string }`
Returns: `void`

### `content:afterRestore`

ゴミ箱にあったコンテンツが復元された後に実行される。副作用のみ。

```typescript
"content:afterRestore": async (event, ctx) => {
	ctx.log.info(`Restored ${event.collection}/${event.content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string }`
Returns: `void`

### `content:afterSchedule`

コンテンツが将来の公開に向けてスケジュールされた後に実行される。副作用のみ。

```typescript
"content:afterSchedule": async (event, ctx) => {
	ctx.log.info(`Scheduled ${event.collection}/${event.content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string }`
Returns: `void`

### `content:afterUnschedule`

スケジュールされたコンテンツが解除された後に実行される。副作用のみ。

```typescript
"content:afterUnschedule": async (event, ctx) => {
	ctx.log.info(`Unscheduled ${event.collection}/${event.content.id}`);
}
```

Event: `{ content: Record<string, unknown>, collection: string }`
Returns: `void`

## メディアフック

### `media:beforeUpload`

アップロード前に実行される。変更後のファイル情報を返すか、変更しない場合はvoidを返すか、キャンセルする場合はthrowする。

```typescript
"media:beforeUpload": async (event, ctx) => {
	const { file } = event;

	if (!file.type.startsWith("image/")) {
		throw new Error("Only images allowed");
	}

	if (file.size > 10 * 1024 * 1024) {
		throw new Error("Max 10MB");
	}

	return { ...file, name: `${Date.now()}-${file.name}` };
}
```

Event: `{ file: { name: string, type: string, size: number } }`
Returns: `{ name: string, type: string, size: number } | void`

### `media:afterUpload`

アップロード成功後に実行される。

```typescript
"media:afterUpload": async (event, ctx) => {
	ctx.log.info(`Uploaded ${event.media.filename}`, { id: event.media.id });
}
```

Event: `{ media: { id: string, filename: string, mimeType: string, size: number | null, url: string, createdAt: string } }`
Returns: `void`

## メールフック

メールフックには特定のcapabilityが必要である。必要なcapabilityがない場合、フックは黙ってスキップされる。

### `email:beforeSend`

**必須:** `hooks.email-events:register` capability。

メール配送前に実行される。変更後のメッセージを返すか、配送をキャンセルする場合は`false`を返す。ハンドラは連鎖しており、各ハンドラは前のハンドラの出力を受け取る。

```typescript
definePlugin({
  id: "email-footer",
  capabilities: ["hooks.email-events:register"],
  hooks: {
    "email:beforeSend": async (event, ctx) => {
      return { ...event.message, text: event.message.text + "\n\n-- Sent via EmDash" };
    },
  },
});
```

Event: `{ message: EmailMessage, source: string }`
Returns: `EmailMessage | false`

### `email:deliver`

**必須:** `hooks.email-transport:register` capability。**排他フック** -- 有効なプロバイダは常に1つのみ。

メールトランスポート（Resend、SMTP、SESなど）を実装する。管理者が「設定 > メール」で選択する。

```typescript
definePlugin({
  id: "emdash-resend",
  capabilities: ["hooks.email-transport:register", "network:request"],
  allowedHosts: ["api.resend.com"],
  hooks: {
    "email:deliver": {
      exclusive: true,
      handler: async ({ message }, ctx) => {
        const apiKey = await ctx.kv.get("settings:apiKey");
        await ctx.http!.fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: { Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({ to: message.to, subject: message.subject, text: message.text }),
        });
      },
    },
  },
});
```

Event: `{ message: EmailMessage, source: string }`
Returns: `void`

### `email:afterSend`

**必須:** `hooks.email-events:register` capability。

配送成功後に実行される。ファイア・アンド・フォーゲット方式 -- エラーはログに記録されるが伝播しない。

```typescript
definePlugin({
  id: "email-logger",
  capabilities: ["hooks.email-events:register"],
  hooks: {
    "email:afterSend": async (event, ctx) => {
      ctx.log.info(`Email sent to ${event.message.to}`, { source: event.source });
    },
  },
});
```

Event: `{ message: EmailMessage, source: string }`
Returns: `void`

## Cronフック

### `cron`

スケジュールに従って実行される。`plugin:activate`内で`ctx.cron.schedule()`を使ってスケジュールを設定する。

```typescript
definePlugin({
  id: "cleanup",
  hooks: {
    "plugin:activate": async (_event, ctx) => {
      await ctx.cron!.schedule("daily-cleanup", { schedule: "0 2 * * *" });
    },
    cron: async (event, ctx) => {
      if (event.name === "daily-cleanup") {
        // ... クリーンアップ処理
      }
    },
  },
});
```

Event: `{ name: string, data?: Record<string, unknown> }`
Returns: `void`

## 公開ページフック

公開ページフックを使うと、プラグインは公開サイトページのレンダリング結果に貢献できる。テンプレート側は`<EmDashHead>`、`<EmDashBodyStart>`、`<EmDashBodyEnd>`コンポーネントを通じてこれらの貢献をオプトインする。

### `page:metadata`

`<head>`に型付きメタデータ -- metaタグ、OGプロパティ、canonical/alternateリンク、JSON-LD -- を追加する。trustedモード・sandboxedモードの両方で動作する。

コアが検証し、重複排除し（先勝ち）、レンダリングする構造化された貢献を返す。プラグインはこのフックを通じて生のHTMLを発行することはない。

```typescript
"page:metadata": async (event, ctx) => {
	if (event.page.kind !== "content") return null;

	return [
		{ kind: "meta", name: "author", content: "My Blog" },
		{
			kind: "jsonld",
			id: `schema:${event.page.content?.collection}:${event.page.content?.id}`,
			graph: {
				"@context": "https://schema.org",
				"@type": "BlogPosting",
				headline: event.page.pageTitle ?? event.page.title,
				description: event.page.description,
			},
		},
	];
}
```

Event: `{ page: PublicPageContext }`
Returns: `PageMetadataContribution | PageMetadataContribution[] | null`

貢献タイプ。

- `{ kind: "meta", name: string, content: string, key?: string }` — `<meta name="..." content="...">`
- `{ kind: "property", property: string, content: string, key?: string }` — `<meta property="..." content="...">`（OpenGraph）
- `{ kind: "link", rel: "canonical" | "alternate", href: string, hreflang?: string, key?: string }` — `<link>`タグ（HTTP/HTTPS URLのみ）
- `{ kind: "jsonld", id?: string, graph: object | object[] }` — `<script type="application/ld+json">`

重複排除ルール: キーごとに最初の貢献が優先される。Canonicalはシングルトンである。

### `page:fragments`（Trusted限定）

`head`、`body:start`、`body:end`に生のHTML、スクリプト、マークアップを追加する。**Trustedプラグイン限定。** Sandboxedプラグインはこのフックを登録できない -- マニフェストスキーマによって拒否される。

```typescript
"page:fragments": async (event, ctx) => {
	return [
		{
			kind: "external-script",
			placement: "head",
			src: "https://www.googletagmanager.com/gtm.js?id=GTM-XXXXX",
			async: true,
		},
		{
			kind: "html",
			placement: "body:start",
			html: '<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-XXXXX" height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>',
		},
	];
}
```

Event: `{ page: PublicPageContext }`
Returns: `PageFragmentContribution | PageFragmentContribution[] | null`

貢献タイプ。

- `{ kind: "external-script", placement, src, async?, defer?, attributes?, key? }`
- `{ kind: "inline-script", placement, code, attributes?, key? }`
- `{ kind: "html", placement, html, key? }`

配置場所: `"head"`、`"body:start"`、`"body:end"`

## 実行順序

1. `priority`の値が小さいほど先に実行される
2. 優先度が同じ場合はプラグインの登録順
3. `dependencies`配列は優先度に関わらず順序を強制する

## エラー処理

- `errorPolicy: "abort"`（デフォルト） — パイプラインが停止し、操作が失敗する可能性がある
- `errorPolicy: "continue"` — エラーはログに記録され、残りのフックは実行され続ける

重要度の低い操作（アナリティクス、通知、外部同期など）には`"continue"`を使う。

## クイックリファレンス

| フック                    | トリガー               | 必要なCapability                 | 戻り値                           |
| ------------------------- | ---------------------- | -------------------------------- | -------------------------------- |
| `plugin:install`          | 初回インストール       | —                                | `void`                           |
| `plugin:activate`         | プラグイン有効化       | —                                | `void`                           |
| `plugin:deactivate`       | プラグイン無効化       | —                                | `void`                           |
| `plugin:uninstall`        | プラグイン削除         | —                                | `void`                           |
| `content:beforeSave`      | 保存前                 | `content:write`                  | 変更後のコンテンツまたは`void`   |
| `content:afterSave`       | 保存後                 | `content:read`                   | `void`                           |
| `content:beforeDelete`    | 削除前                 | `content:read`                   | キャンセルする場合`false`        |
| `content:afterDelete`     | 削除後                 | `content:read`                   | `void`                           |
| `content:afterPublish`    | 公開後                 | `content:read`                   | `void`                           |
| `content:afterUnpublish`  | 非公開化後             | `content:read`                   | `void`                           |
| `content:afterRestore`    | 復元後                 | `content:read`                   | `void`                           |
| `content:afterSchedule`   | スケジュール後         | `content:read`                   | `void`                           |
| `content:afterUnschedule` | スケジュール解除後     | `content:read`                   | `void`                           |
| `media:beforeUpload`      | アップロード前         | —                                | 変更後のファイル情報または`void` |
| `media:afterUpload`       | アップロード後         | —                                | `void`                           |
| `email:beforeSend`        | メール送信前           | `hooks.email-events:register`    | 変更後のメッセージまたは`false`  |
| `email:deliver`           | メール配送             | `hooks.email-transport:register` | `void`（排他）                   |
| `email:afterSend`         | メール送信後           | `hooks.email-events:register`    | `void`                           |
| `cron`                    | スケジュールタスク発火 | —                                | `void`                           |
| `page:metadata`           | ページレンダリング     | —                                | メタデータの貢献                 |
| `page:fragments`          | ページレンダリング     | —（Trusted限定）                 | フラグメントの貢献               |

</content>
