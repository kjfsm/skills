# Astro + React + Tailwind の相互運用

shadcn/ui(React製、`src/shadcn/ui/`)を`.astro`ファイルから使う際に踏みやすい落とし穴と、Tailwind CSS v4の構文について。

## `.astro`からReactコンポーネントへの子要素は文字列化される

`.astro`ファイル内でReactコンポーネントに子要素を渡すと、AstroはそれをReactの仮想DOMノードにせず**プレーンな文字列(レンダリング済みHTML)としてパースする**。`@astrojs/react`の公式ドキュメントに明記されている。

> Children passed into a React component from an Astro component are parsed as plain strings, not React nodes.

これが原因で、Radix UIの`asChild`パターン(`Slot.Root`で単一の子React要素をクローンし、`className`/`data-*`をマージする実装)は**エラーを出さずに静かに失敗する**。実際に検証したところ、

```astro
<Badge asChild variant="outline">
  <a href="/foo">Test Label</a>
</Badge>
```

の出力は`<a href="/foo">Test Label</a>`のみで、Badgeが付与するはずの`className`や`data-slot`が一切乗らなかった(Button の`asChild`でも同様)。`Slot.Root`は子要素が本物のReact要素であることを前提にクローン処理をするため、文字列化された子要素には何もマージできない。

**このプロジェクトでの対処**: `asChild`は使わず、`badgeVariants()`/`buttonVariants()`(`cva`のスタイル関数、`src/shadcn/ui/badge.tsx`・`button.tsx`からexport済み)を`cn()`経由で直接`class`に渡す。

```astro
---
import { badgeVariants } from "@/shadcn/ui/badge";
import { cn } from "@/shadcn/lib/utils";
---

<a href={href} class={cn(badgeVariants({ variant: "outline" }), "px-4 py-1 text-sm")}>
	{label}
</a>
```

`Card`のように子要素をそのまま表示するだけ(`Slot`でクローンしない)のコンポーネントは、文字列化されても見た目上は問題なくレンダリングされるので、この制約に引っかからない。問題になるのは`asChild`/`Slot`のように子要素のpropsを書き換える実装だけ。

**回避策(未検証・実験的)**: `astro.config.mjs`の`react()`インテグレーションに`experimentalReactChildren: true`を渡すと、Astroから常にReactの仮想DOMノードとして子要素を渡すようになる(ランタイムコストありと公式に明記)。理論上はこれで`asChild`も機能するはずだが、このプロジェクトでは有効化していない。

参考: [@astrojs/react インテグレーションガイド](https://docs.astro.build/en/guides/integrations-guide/react/)、[フレームワークコンポーネントガイド](https://docs.astro.build/en/guides/framework-components/)

> **スタイリングのトークンについて**: 色・サイズ・余白は shadcnセマンティックトークン + Tailwind組み込みスケール(`bg-primary` / `text-4xl` / `max-w-6xl` など)で書く。独自CSS変数を参照する `text-(length:--...)` / `max-w-(--...)` のような arbitrary記法は使わない。詳細は `.claude/rules/design-system.md` を参照。

## 補足: `_`始まりのファイル/ディレクトリは`src/pages`のルーティング対象外

Astroは`src/pages`配下で`_`から始まるファイル・ディレクトリをルーティングから除外する(コロケーションされたユーティリティやテストのための慣習)。動作確認用のスクラッチページを`src/pages`直下に置く場合、`_`始まりの名前にすると意図せず404になる。
