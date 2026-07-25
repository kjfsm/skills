# いつモックするか

モックするのは **システムの境界** だけ:

- 外部 API(決済、メールなど)
- データベース(場合による — テスト用 DB を優先する)
- 時刻/乱数
- ファイルシステム(場合による)

モックしないもの:

- 自分自身のクラス/モジュール
- 内部の協力オブジェクト
- 自分が制御しているもの全般

## モックしやすさを見据えた設計

システムの境界では、モックしやすいインターフェースを設計する:

**1. 依存性注入を使う**

外部への依存は内部で生成するのではなく、外から渡す:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. 汎用フェッチャーより SDK スタイルのインターフェースを優先する**

条件分岐を持つ1つの汎用関数の代わりに、外部とのやり取りごとに個別の関数を作る:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

SDK スタイルの意味するところ:
- 各モックが1つの具体的な形だけを返す
- テストのセットアップに条件分岐がない
- どのテストがどのエンドポイントを使っているか見分けやすい
- エンドポイントごとの型安全性
