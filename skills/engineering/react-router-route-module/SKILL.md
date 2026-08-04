---
name: react-router-route-module
description: React Router（framework mode）の route module に何をどの export へ置くかの規律。認可ガードを足すとき、loader と action に同じチェックを書いているとき、レイアウトが持つ値を配下のコンポーネントへ渡したいとき、`useRouteLoaderData` と `<Outlet context>` のどちらを使うか迷ったときに使う。
---

# React Router の route module に何をどこへ置くか

framework mode の route module は、`middleware` / `loader` / `action` / `Component` という並びの
export に、サーバの仕事とクライアントの仕事を同居させる。**どれをどの export に置くか**を外すと、
型もテストも通ったまま穴が開く — 画面は正しく見えるのに、リクエストは通る。

## 一次情報の場所

推測で API を書かない。middleware まわりはバージョンで扱いが変わるので、まずインストール済みの
バージョンを確認する。

```bash
node -e "console.log(require('react-router/package.json').version)"
```

| 何を知りたいか                          | 見る場所                                             |
| --------------------------------------- | ---------------------------------------------------- |
| middleware の実行順・引数・`next()`     | https://reactrouter.com/how-to/middleware            |
| route module が持てる export の一覧     | https://reactrouter.com/start/framework/route-module |
| `<Outlet context>` / `useOutletContext` | https://reactrouter.com/api/hooks/useOutletContext   |
| `useRouteLoaderData`                    | https://reactrouter.com/api/hooks/useRouteLoaderData |

## 認可の強制点は middleware

**強制点は 1 つにする。** middleware はサーバで走り、**loader と action の両方の手前**を通る。
ここに置けば、GET でフォームを開く経路も POST で送る経路も、同じ判定を必ず通る。

```ts
export const middleware: Route.MiddlewareFunction[] = [
  ({ context }) => {
    if (!canDoIt(context.get(membershipContext).role)) throw redirect("/dashboard");
  },
];
```

- **middleware はレイアウト専用ではない。葉ルートにも書ける。** 1 ルートだけに効く権限なら、
  そのルートに書く。共有したくなってからレイアウトへ上げる。
- **loader と action に同じチェックが 2 回書いてあったら、middleware へ寄せる合図。**
  2 箇所あるということは、片方だけ直る日が来るということ。
- 同じ権限を複数ルートで共有するなら、URL を増やさないレイアウトルート（`routes.ts` なら
  `layout()`、ファイル規約なら `_layout.tsx`）に上げて、配下をその境界の内側に置く。
  1 ルートのうちは構造を足さない。
- middleware は `context.set()` でリクエストスコープの値を配れる。loader は `context.get()` で
  受け取る。同じものを loader ごとに引き直さない。

## 画面で隠すのは強制ではない

ボタンを隠しても、URL を直接開けば loader は動き、フォームを組み立てて POST すれば action は動く。
**「隠す」と「止める」は別の作業**で、止める方を書き忘れても画面は正しく見えるので気づかない。

権限フラグを grep して、**消費点が UI にしかないもの**を疑う。

```bash
rg 'canCreateRequest'
# → サイドバーの出し分け 1 箇所だけ。作成を実行する route は誰も見ていない = 穴
```

同じ形が、1 つの route の中の intent 分岐にも現れる。action の入口ではなく分岐の内側に
権限チェックが散っていると、チェックの手前で `return` する分岐が 1 つ紛れ込んだだけで抜ける。
**チェックは分岐の前に 1 回**。

## レイアウトが持つ値を配下のコンポーネントへ渡す

祖先の loader が持っている値を、深いところのコンポーネントが要るときの選択肢は 2 つ。

**`<Outlet context={value} />` + `useOutletContext<T>()`** — 組み込みで、ルート ID の文字列に
依存しない。既定でこちらを採る。

- 値をインラインのオブジェクトリテラルで渡さない（レンダーのたびに別物になり、消費側が
  再レンダーする）。`useMemo` で固定する。
- `useOutletContext<T>()` はキャストで、渡す側との一致は型で保証されない。渡す側に
  `context={value satisfies T}` を書かせて、provider 側だけでも守る。
- 読めるのは **`<Outlet>` の子孫だけ**。`<Outlet>` の外側に置いたもの（サイドバーなど）は
  読めないので、そこにも同じ値が要るなら props で渡すか、両方の祖先になる場所から配る。

**`useRouteLoaderData("routes/…")`** — 祖先や兄弟の loader データを ID で名指しする。次のときだけ
選ぶ: 値が要る場所が `<Outlet>` の子孫でない、あるいは Provider を通らない経路がある。

- **ID は文字列**なので、ファイルを動かすとリンクが切れるのに型は通る。ルートを移す予定が
  あるなら避ける。
- マッチしていなければ `undefined` が返る。同じコンポーネントを **複数のルート木**（本番と
  デモ、など）で使い回している場合、木の数だけ呼んで合成することになり、そのコンポーネントが
  「木が何本あるか」を知ってしまう。

## 落とし穴

- **`middleware` を足したら、その route の統合テストが権限を通る形になっているか確かめる。**
  loader を直接呼ぶテストは middleware を通らないので、緑のまま穴を見逃す。
- 画面遷移しない操作（`useFetcher`）の結果は route の `actionData` には載らない。トーストで
  返すか、fetcher 側で受ける。
