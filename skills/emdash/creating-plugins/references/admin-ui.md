# 管理UI

プラグインは、Reactページとダッシュボードウィジェットによって管理パネルを拡張する。

## エントリポイント

`src/admin.tsx`からページとウィジェットをエクスポートする。

```typescript
// src/admin.tsx
import { SettingsPage } from "./components/SettingsPage";
import { ReportsPage } from "./components/ReportsPage";
import { StatusWidget } from "./components/StatusWidget";

// パスをキーとするページ（末尾のスラッシュは任意のため、/settingsと/settings/のどちらも解決される）
export const pages = {
  "/settings": SettingsPage,
  "/reports": ReportsPage,
};

// IDをキーとするウィジェット（admin.widgetsのIDと一致させる必要がある）
export const widgets = {
  status: StatusWidget,
};
```

プラグイン定義内で参照する。

```typescript
definePlugin({
  id: "my-plugin",
  version: "1.0.0",

  admin: {
    entry: "@my-org/my-plugin/admin",
    pages: [
      { path: "/settings", label: "Settings", icon: "settings" },
      { path: "/reports", label: "Reports", icon: "chart" },
    ],
    widgets: [{ id: "status", title: "Status", size: "half" }],
  },
});
```

ページは`/_emdash/admin/plugins/<plugin-id>/<path>`にマウントされる。

## ページ

Reactコンポーネント。プラグインのルートを呼び出すには`usePluginAPI()`を使う。

```typescript
// src/components/SettingsPage.tsx
import { useState, useEffect } from "react";
import { usePluginAPI } from "@emdash-cms/admin";

export function SettingsPage() {
	const api = usePluginAPI();
	const [settings, setSettings] = useState<Record<string, unknown>>({});
	const [saving, setSaving] = useState(false);

	useEffect(() => {
		api.get("settings").then(setSettings);
	}, []);

	const handleSave = async () => {
		setSaving(true);
		await api.post("settings/save", settings);
		setSaving(false);
	};

	return (
		<div>
			<h1>Settings</h1>
			<label>
				Site Title
				<input
					type="text"
					value={settings.siteTitle || ""}
					onChange={(e) => setSettings({ ...settings, siteTitle: e.target.value })}
				/>
			</label>
			<button onClick={handleSave} disabled={saving}>
				{saving ? "Saving..." : "Save"}
			</button>
		</div>
	);
}
```

## ウィジェット

一目で情報が分かるダッシュボードカード。

```typescript
// src/components/StatusWidget.tsx
import { useState, useEffect } from "react";
import { usePluginAPI } from "@emdash-cms/admin";

export function StatusWidget() {
	const api = usePluginAPI();
	const [data, setData] = useState({ count: 0 });

	useEffect(() => {
		api.get("status").then(setData);
	}, []);

	return (
		<div className="widget-content">
			<div className="score">{data.count}</div>
		</div>
	);
}
```

### ウィジェットのサイズ

| サイズ  | 幅                   |
| ------- | -------------------- |
| `full`  | ダッシュボードの全幅 |
| `half`  | 半幅                 |
| `third` | 3分の1幅             |

## usePluginAPI()

ルートURLにプラグインIDを自動的に前置する。

```typescript
const api = usePluginAPI();

const data = await api.get("status"); // GET /.../plugins/<id>/status
await api.post("settings/save", { enabled: true }); // POST（bodyあり）
const result = await api.get("history?limit=50"); // クエリパラメータ
```

## 管理コンポーネント

`@emdash-cms/admin`のビルド済みコンポーネント。

```typescript
import { Card, Button, Input, Select, Toggle, Table, Loading, Alert } from "@emdash-cms/admin";
```

## 自動生成される設定

プラグインが設定のみを必要とする場合、カスタムページの作成は不要である -- `settingsSchema`を使えばEmDashがフォームを自動生成する。

```typescript
admin: {
	settingsSchema: {
		apiKey: { type: "secret", label: "API Key" },
		enabled: { type: "boolean", label: "Enabled", default: true },
	}
}
```

## ビルド設定

管理UIコンポーネントには別のビルドエントリが必要である。

```typescript
// tsdown.config.ts
export default {
  entry: {
    index: "src/index.ts",
    admin: "src/admin.tsx",
  },
  format: "esm",
  dts: true,
  external: ["react", "react-dom", "emdash", "@emdash-cms/admin"],
};
```

重複バンドルを避けるため、Reactと`@emdash-cms/admin`はexternalに指定しておくこと。

## プラグインディスクリプタ

ディスクリプタ（ファクトリ関数が返すもの）は管理UI関連のメタデータも宣言する。

```typescript
export function myPlugin(options = {}): PluginDescriptor {
  return {
    id: "my-plugin",
    entrypoint: "@my-org/my-plugin",
    version: "1.0.0",
    options,
    adminEntry: "@my-org/my-plugin/admin",
    adminPages: [{ path: "/settings", label: "Settings", icon: "settings" }],
    adminWidgets: [{ id: "status", title: "Status", size: "half" }],
  };
}
```

</content>
