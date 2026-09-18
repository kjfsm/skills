# byline はオブジェクトキャッシュに乗らない

[SKILL.md](./SKILL.md) の空振り 5 の具体。

公式の「What gets cached」はコンテンツクエリ・サイト設定・メニュー・taxonomy用語を挙げ、**byline は入っていない**。実装でも `getBylineBySlug()` は `requestCached()` だけを通り、`cachedQuery` を呼ばない。

`CacheNamespace.BYLINES` は存在するが、byline を保存するためではなく**コンテンツクエリのキーに畳み込む epoch** である。byline を編集するとコンテンツのキャッシュは飛ぶが、byline 自体は毎回DBを引く。

レイアウトから全ページで byline を読む構成なら、サイト側で載せられる:

```ts
return cachedQuery({
  namespace: CacheNamespace.BYLINES,
  key: `operator:${slug}`,
  load: () => getBylineBySlug(slug),
});
```

無効化は書かなくてよい(`BYLINES` の epoch は EmDash 自身が bump する)。TTL も省けば `defaultTtl` に乗る。**`cachedQuery` は公開エクスポートだが公式ドキュメントには無い** — 壊れたら元の呼び出しに戻せる形に閉じておく。
