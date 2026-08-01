---
name: migrate-to-shoehorn
description: テストファイル内の `as` 型アサーションを @total-typescript/shoehorn へ移行する。ユーザーが shoehorn について言及した場合、テスト内の `as` を置き換えたい場合、または部分的なテストデータが必要な場合に使う。
---

# Shoehorn への移行

## なぜ shoehorn か

`shoehorn` を使うと、TypeScript の型チェックを満たしたままテストに部分的なデータを渡せる。`as` アサーションを型安全な代替手段に置き換える。

**テストコード限定。** 本番コードでは絶対に shoehorn を使わないこと。

テストにおける `as` の問題点。

- 使わないよう教育されている
- ターゲットの型を手動で指定する必要がある
- 意図的に間違ったデータを渡すための二重 as(`as unknown as Type`)

## インストール

```bash
npm i @total-typescript/shoehorn
```

## 移行パターン

### 必要なプロパティが少ない大きなオブジェクト

移行前:

```ts
type Request = {
  body: { id: string };
  headers: Record<string, string>;
  cookies: Record<string, string>;
  // ...20 more properties
};

it("gets user by id", () => {
  // Only care about body.id but must fake entire Request
  getUser({
    body: { id: "123" },
    headers: {},
    cookies: {},
    // ...fake all 20 properties
  });
});
```

移行後:

```ts
import { fromPartial } from "@total-typescript/shoehorn";

it("gets user by id", () => {
  getUser(
    fromPartial({
      body: { id: "123" },
    }),
  );
});
```

### `as Type` → `fromPartial()`

移行前:

```ts
getUser({ body: { id: "123" } } as Request);
```

移行後:

```ts
import { fromPartial } from "@total-typescript/shoehorn";

getUser(fromPartial({ body: { id: "123" } }));
```

### `as unknown as Type` → `fromAny()`

移行前:

```ts
getUser({ body: { id: 123 } } as unknown as Request); // wrong type on purpose
```

移行後:

```ts
import { fromAny } from "@total-typescript/shoehorn";

getUser(fromAny({ body: { id: 123 } }));
```

## 使い分け

| 関数            | 用途                                                          |
| --------------- | ------------------------------------------------------------- |
| `fromPartial()` | 型チェックを通る部分的なデータを渡す                          |
| `fromAny()`     | 意図的に間違ったデータを渡す(オートコンプリートは維持)        |
| `fromExact()`   | 完全なオブジェクトを強制する(後で fromPartial に切り替え可能) |

## ワークフロー

1. **要件を確認する** - ユーザーに聞く:
   - どのテストファイルで `as` アサーションが問題になっているか?
   - 一部のプロパティしか重要でない大きなオブジェクトを扱っているか?
   - エラーテストのために意図的に間違ったデータを渡す必要があるか?

2. **インストールと移行**:
   - [ ] インストール: `npm i @total-typescript/shoehorn`
   - [ ] `as` アサーションのあるテストファイルを検索: `grep -r " as [A-Z]" --include="*.test.ts" --include="*.spec.ts"`
   - [ ] `as Type` を `fromPartial()` に置き換える
   - [ ] `as unknown as Type` を `fromAny()` に置き換える
   - [ ] `@total-typescript/shoehorn` からの import を追加する
   - [ ] 型チェックを実行して検証する
