# CONTEXT.md の形式

テンプレートは **形** の見本である。書く言語はリポジトリの既存文書に合わせる — 見本が英語であることは、英語で書く理由にならない。

## 構造

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## ルール

- **明確な立場を取る。** 同じ概念に複数の言葉が存在する場合、最善のものを選び、他を `_Avoid_` の下に列挙する。
- **定義は引き締める。** 最大でも1〜2文。それが _何であるか_ を定義し、_何をするか_ は定義しない。
- **このプロジェクトのコンテキストに固有の用語だけを含める。** 一般的なプログラミングの概念(タイムアウト、エラー型、ユーティリティのパターン)は、プロジェクトがそれを多用していても含めない。用語を追加する前に問う: これはこのコンテキスト固有の概念か、それとも一般的なプログラミングの概念か? 前者だけが該当する。
- 自然なまとまりが生まれるときは **用語をサブ見出しの下にグループ化する**。すべての用語が1つのまとまった領域に属するなら、フラットなリストで構わない。

## 単一コンテキストと複数コンテキストのリポジトリ

**単一コンテキスト(ほとんどのリポジトリ):** リポジトリのルートに `CONTEXT.md` を1つ。

**複数コンテキスト:** リポジトリのルートにある `CONTEXT-MAP.md` が、各コンテキストとその場所、互いの関係を列挙する:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

このスキルはどちらの構造が当てはまるかを推定する:

- `CONTEXT-MAP.md` が存在すれば、それを読んでコンテキストを見つける
- ルートの `CONTEXT.md` だけが存在すれば、単一コンテキスト
- どちらも存在しなければ、最初の用語が解決したときにルートの `CONTEXT.md` を遅延生成する

複数のコンテキストが存在する場合は、今の話題がどれに関係するかを推定する。不明な場合は尋ねる。
