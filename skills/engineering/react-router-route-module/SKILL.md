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

**middleware が決めるのは「そのルートに入れるか」。** 読めるが書き込みだけ制限したい画面は
middleware に寄せない — ルートごと止めると、読む手段まで奪ってしまう。その場合の強制点は
**action の入口**（分岐の前）で、`loader` は制限せず、画面はフラグで出し分ける。

| やりたいこと                     | 強制点            |
| -------------------------------- | ----------------- |
| このロールはこの画面に入れない   | `middleware`      |
| 画面は見せるが、この操作はさせない | `action` の入口 |

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

分岐が 3 つあって 1 つにしかチェックが無い、という形は grep では見つけにくい。intent ごとに
**「この操作は誰ができるか」を並べて読む**こと。片方向だけ守られている非対称
（「組織から外すのは管理者だけ、なのに組織に入れるのは誰でも」）は、たいてい書き忘れである。

## レイアウトが持つ値を配下のコンポーネントへ渡す

祖先の loader が持っている値を、深いところのコンポーネントが要るときの選択肢は 2 つ。

**`<Outlet context>` + `useOutletContext<T>()`** — 組み込みで、ルート ID の文字列に依存しない。
既定でこちらを採る。ドキュメント（`useOutletContext` の JSDoc）の形をそのまま写す:

```tsx
type ContextType = { user: User | null };

export default function Dashboard() {
  return <Outlet context={{ user } satisfies ContextType} />;
}

export function useUser() {
  return useOutletContext<ContextType>();
}
```

写すべきところが 3 つある。

- **`satisfies` を付けてインラインで渡す。** メモ化しない — レイアウトが再レンダーすれば
  `<Outlet>` 配下はどのみち再レンダーするので、値の同一性を保っても何も止まらない
  （消費側を `React.memo` で止めている、という計測された理由があるときだけ考える）。
- **hook は中身の名前で呼ぶ。** `useUser()` → `const { user } = useUser()`。
  "abilities" のような自分で作った傘の名詞を被せない。
- **hook を用意して、キャストをそこに閉じる。** `useOutletContext<T>()` の戻り値はキャストで、
  実体は `null` 既定の React context。渡し忘れても型は通るので、渡す側の `satisfies` と
  受け取る側の 1 か所で挟む。渡し忘れは既定値に倒さずその場で落とす — 倒すと「値が
  無いだけ」の見た目になり、判定を間違えたのか配線を忘れたのかが区別できない。

ドキュメントは hook を**親のルートモジュールから** export している。そこへ寄せられない事情が
2 つある。当てはまるなら、別の client-safe なモジュールに置いて理由を書く。

- **親が 2 つ以上ある**（本番とデモ、など同じ形のルート木が並ぶ）。子は片方だけを名指しできない。
- **親のルートモジュールがサーバ専用モジュールを import している。** 型だけなら消えるが、
  hook は**値**なので、そこから import するとサーバのコードがクライアントのバンドルに入る。

読めるのは **`<Outlet>` の子孫だけ**。`<Outlet>` の外側に置いたもの（サイドバーなど）は読めない
ので、そこにも同じ値が要るなら props で渡すか、両方の祖先になる場所から配る。

**`useRouteLoaderData("routes/…")`** — 祖先や兄弟の loader データを ID で名指しする。次のときだけ
選ぶ: 値が要る場所が `<Outlet>` の子孫でない、あるいは Provider を通らない経路がある。

- **ID は文字列**なので、ファイルを動かすとリンクが切れるのに型は通る。ルートを移す予定が
  あるなら避ける。
- マッチしていなければ `undefined` が返る。同じコンポーネントを **複数のルート木**（本番と
  デモ、など）で使い回している場合、木の数だけ呼んで合成することになり、そのコンポーネントが
  「木が何本あるか」を知ってしまう。

## ガードのテスト

- **middleware は loader を直接呼ぶテストでは走らない。** ガードは名指しで呼ぶ
  （`middleware[0](args, next)`）。loader 経由のテストしか無い状態で強制を loader から
  middleware へ移すと、テストは緑のまま素通りするようになる。
- **拒否される側を必ず撃つ。** 通る側だけのテストは何も固定しない — 判定基準は
  「**ガードの中身を空にしたら赤くなるか**」。実際に一度空にして確かめる。
  今どのロールも拒否されないなら、そのルートに届かないロールで branch を撃つ。
- **GET と POST を撃ち分けても意味は無い。** ガードが `context` しか読まないなら、メソッドを
  変えても通る道は同じ。「middleware が action の手前も通る」ことを保証しているのは
  React Router であって、そのテストではない。

## 落とし穴

- 画面遷移しない操作（`useFetcher`）の結果は route の `actionData` には載らない。トーストで
  返すか、fetcher 側で受ける。
