# APIルート

プラグインルートは、StandardプラグインとNativeプラグインの両方で、またtrustedモードとsandboxedモードの両方で動作する。Sandboxedプラグインのルートは、sandboxランナーの`invokeRoute()` RPCを介して呼び出される。

プラグインルートは`/_emdash/api/plugins/<plugin-id>/<route-name>`にRESTエンドポイントを公開する。

## ルートの定義

```typescript
import { definePlugin } from "emdash";
import { z } from "astro/zod";

definePlugin({
  id: "forms",
  version: "1.0.0",

  routes: {
    // シンプルなルート
    status: {
      handler: async (ctx) => {
        return { ok: true };
      },
    },

    // 入力バリデーションを伴うルート
    submissions: {
      input: z.object({
        formId: z.string().optional(),
        limit: z.number().default(50),
        cursor: z.string().optional(),
      }),
      handler: async (ctx) => {
        const { formId, limit, cursor } = ctx.input;
        const result = await ctx.storage.submissions!.query({
          where: formId ? { formId } : undefined,
          orderBy: { createdAt: "desc" },
          limit,
          cursor,
        });
        return {
          items: result.items,
          cursor: result.cursor,
          hasMore: result.hasMore,
        };
      },
    },

    // ネストしたパス
    "settings/save": {
      input: z.object({
        enabled: z.boolean().optional(),
        apiKey: z.string().optional(),
      }),
      handler: async (ctx) => {
        for (const [key, value] of Object.entries(ctx.input)) {
          if (value !== undefined) {
            await ctx.kv.set(`settings:${key}`, value);
          }
        }
        return { success: true };
      },
    },
  },
});
```

## ルートURL

| プラグインID | ルート名        | URL                                      |
| ------------ | --------------- | ---------------------------------------- |
| `forms`      | `status`        | `/_emdash/api/plugins/forms/status`      |
| `forms`      | `submissions`   | `/_emdash/api/plugins/forms/submissions` |
| `seo`        | `settings/save` | `/_emdash/api/plugins/seo/settings/save` |

## ハンドラコンテキスト

```typescript
interface RouteContext<TInput = unknown> extends PluginContext {
  input: TInput; // バリデーション済みの入力
  request: Request; // 元のリクエスト
  plugin: { id: string; version: string };
  storage: Record<string, StorageCollection>;
  kv: KVAccess;
  content?: ContentAccess; // capabilityが宣言されている場合
  media?: MediaAccess;
  http?: HttpAccess;
  log: LogAccess;
}
```

## 入力バリデーション

Zodスキーマを使う。不正な入力は400を返す。

```typescript
routes: {
	create: {
		input: z.object({
			title: z.string().min(1).max(200),
			email: z.string().email(),
			priority: z.enum(["low", "medium", "high"]).default("medium"),
			tags: z.array(z.string()).optional(),
		}),
		handler: async (ctx) => {
			// ctx.inputは型付けされバリデーション済みである
			const { title, email, priority } = ctx.input;
			// ...
		},
	},
}
```

入力ソース。

- **POST/PUT/PATCH** — リクエストボディ（JSON）
- **GET/DELETE** — URLクエリパラメータ

## 戻り値

JSONシリアライズ可能な値を任意に返せる。レスポンスは常に`Content-Type: application/json`となる。

```typescript
return { success: true, data: items }; // オブジェクト
return items; // 配列
return 42; // プリミティブ
```

## エラー

エラーレスポンスを返すにはthrowする。

```typescript
throw new Error("Item not found"); // { error: "Item not found" }を伴う500

// カスタムステータスコード
throw new Response(JSON.stringify({ error: "Not found" }), {
  status: 404,
  headers: { "Content-Type": "application/json" },
});
```

## HTTPメソッド

ルートはすべてのメソッドに応答する。`ctx.request.method`をチェックする。

```typescript
handler: async (ctx) => {
  switch (ctx.request.method) {
    case "GET":
      return await ctx.storage.items!.get(ctx.input.id);
    case "DELETE":
      await ctx.storage.items!.delete(ctx.input.id);
      return { deleted: true };
    default:
      throw new Response("Method not allowed", { status: 405 });
  }
};
```

## よくあるパターン

### 設定のCRUD

```typescript
routes: {
	settings: {
		handler: async (ctx) => {
			const settings = await ctx.kv.list("settings:");
			const result: Record<string, unknown> = {};
			for (const entry of settings) {
				result[entry.key.replace("settings:", "")] = entry.value;
			}
			return result;
		},
	},
	"settings/save": {
		handler: async (ctx) => {
			// EmDashはリクエストボディを一度だけパースし、ctx.inputとして公開する。
			// ctx.request.json()を呼ばないこと -- ボディストリームはすでに消費済みである。
			const input = ctx.input as Record<string, unknown>;
			for (const [key, value] of Object.entries(input)) {
				if (value !== undefined) await ctx.kv.set(`settings:${key}`, value);
			}
			return { success: true };
		},
	},
}
```

### ページネーション付き一覧

```typescript
routes: {
	list: {
		input: z.object({
			limit: z.number().min(1).max(100).default(50),
			cursor: z.string().optional(),
			status: z.string().optional(),
		}),
		handler: async (ctx) => {
			const { limit, cursor, status } = ctx.input;
			const result = await ctx.storage.items!.query({
				where: status ? { status } : undefined,
				orderBy: { createdAt: "desc" },
				limit,
				cursor,
			});
			return {
				items: result.items.map((item) => ({ id: item.id, ...item.data })),
				cursor: result.cursor,
				hasMore: result.hasMore,
			};
		},
	},
}
```

### 外部APIプロキシ

`network:request` capabilityと`allowedHosts`が必要。

```typescript
definePlugin({
  capabilities: ["network:request"],
  allowedHosts: ["api.weather.example.com"],

  routes: {
    forecast: {
      input: z.object({ city: z.string() }),
      handler: async (ctx) => {
        const apiKey = await ctx.kv.get<string>("settings:apiKey");
        if (!apiKey) throw new Error("API key not configured");

        const response = await ctx.http!.fetch(
          `https://api.weather.example.com/forecast?city=${ctx.input.city}`,
          { headers: { "X-API-Key": apiKey } },
        );

        if (!response.ok) throw new Error(`API error: ${response.status}`);
        return response.json();
      },
    },
  },
});
```

## 管理UIからの呼び出し

```typescript
import { usePluginAPI } from "@emdash-cms/admin";

const api = usePluginAPI();
const data = await api.get("status");
await api.post("settings/save", { enabled: true });
```

## 外部からの呼び出し

```bash
curl https://your-site.com/_emdash/api/plugins/forms/submissions?limit=10

curl -X POST https://your-site.com/_emdash/api/plugins/forms/create \
  -H "Content-Type: application/json" \
  -d '{"title": "Hello"}'
```

プラグインルートには組み込みの認証機能はない。管理者専用ルートは、管理者セッションミドルウェアによって保護される。
</content>
