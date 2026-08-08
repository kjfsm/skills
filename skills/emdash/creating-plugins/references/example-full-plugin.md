# 完全なサンプル: フック・ルート・ストレージを備えたStandardプラグイン

`definePlugin()`でhooks・routes・storageを組み合わせる際の全体像が必要なときのみ読むこと(SKILL.mdの機能一覧・チェックリストで足りる場合はこのファイルは不要)。

```typescript
// src/index.ts — ディスクリプタファクトリ、Viteでビルド時に実行される
import type { PluginDescriptor } from "emdash";

export function submissionsPlugin(): PluginDescriptor {
  return {
    id: "submissions",
    version: "1.0.0",
    format: "standard",
    entrypoint: "@my-org/plugin-submissions/sandbox",
    options: {},
    capabilities: ["content:read"],
    storage: {
      submissions: {
        indexes: ["formId", "status", "createdAt"],
      },
    },
    adminPages: [{ path: "/submissions", label: "Submissions", icon: "list" }],
    adminWidgets: [{ id: "recent-submissions", title: "Recent Submissions", size: "half" }],
  };
}
```

```typescript
// src/sandbox-entry.ts — プラグイン定義、リクエスト時に実行される
import { definePlugin } from "emdash";
import type { PluginContext } from "emdash";

export default definePlugin({
  hooks: {
    "plugin:install": {
      handler: async (_event: any, ctx: PluginContext) => {
        ctx.log.info("Submissions plugin installed");
        await ctx.kv.set("settings:maxSubmissions", 1000);
      },
    },
  },

  routes: {
    submit: {
      public: true, // 認証不要
      handler: async (routeCtx: any, ctx: PluginContext) => {
        const { formId, ...data } = routeCtx.input as Record<string, unknown>;

        const count = await ctx.storage.submissions.count({ formId });
        const max = (await ctx.kv.get<number>("settings:maxSubmissions")) ?? 1000;

        if (count >= max) {
          return { success: false, error: "Submission limit reached" };
        }

        const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        await ctx.storage.submissions.put(id, {
          formId,
          data,
          status: "pending",
          createdAt: new Date().toISOString(),
        });

        return { success: true, id };
      },
    },

    list: {
      handler: async (routeCtx: any, ctx: PluginContext) => {
        const url = new URL(routeCtx.request.url);
        const limit = Math.max(
          1,
          Math.min(parseInt(url.searchParams.get("limit") || "50", 10) || 50, 100),
        );
        const cursor = url.searchParams.get("cursor") || undefined;

        const result = await ctx.storage.submissions.query({
          orderBy: { createdAt: "desc" },
          limit,
          cursor,
        });

        return {
          items: result.items.map((item: any) => ({ id: item.id, ...item.data })),
          cursor: result.cursor,
          hasMore: result.hasMore,
        };
      },
    },

    // ページとウィジェット向けのBlock Kit管理ハンドラ
    admin: {
      handler: async (routeCtx: any, ctx: PluginContext) => {
        const interaction = routeCtx.input as { type: string; page?: string };

        if (interaction.type === "page_load" && interaction.page === "/submissions") {
          const result = await ctx.storage.submissions.query({
            orderBy: { createdAt: "desc" },
            limit: 50,
          });
          return {
            blocks: [
              { type: "header", text: "Submissions" },
              {
                type: "table",
                blockId: "submissions-table",
                columns: [
                  { key: "formId", label: "Form", format: "text" },
                  { key: "status", label: "Status", format: "badge" },
                  { key: "createdAt", label: "Date", format: "relative_time" },
                ],
                rows: result.items.map((item: any) => item.data),
              },
            ],
          };
        }

        return { blocks: [] };
      },
    },
  },
});
```
