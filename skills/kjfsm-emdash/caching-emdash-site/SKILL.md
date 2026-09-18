---
name: caching-emdash-site
description: EmDash + Cloudflare のサイトに Workers Cache でエッジHTMLキャッシュを入れる。本番のTTFBが遅い・しばらく経ってからの初回表示が遅いとき、D1 のリードレプリカや Worker の Placement を決めるとき、`routeRules` や `cacheCloudflare()` を設定するとき、キャッシュから外したい経路(検索・404・管理画面)があるとき、MCPや管理画面で更新したのにサイトに出ないとき、`Server-Timing` の `cache.hit`/`cache.miss` を読むときに使う。公式に無い落とし穴と、公式の素直な読みが実装と食い違う箇所だけを扱う。
---

# EmDash サイトのキャッシュ

> **設定手順の一次情報源は公式にある。**
> [Deploy to Cloudflare](https://docs.emdashcms.com/deployment/cloudflare/) /
> [Object Cache](https://docs.emdashcms.com/deployment/object-cache/) /
> [Database Options](https://docs.emdashcms.com/deployment/database/)。
> `wrangler.jsonc` の `"cache"`、`cacheCloudflare()`、`routeRules` の書き方はあちらを読む。

このスキルが持つのは **空振り** — 書いたのに効かない操作の一覧である。ここに並ぶ落とし穴は形が1つしかない: **無効化したつもりの記述が、無効化していない。** 型もビルドもテストも何も言わない。

キャッシュは3層あり、混同すると調査が空転する。

| 層                                | どこ            | 何を持つ           |
| --------------------------------- | --------------- | ------------------ |
| Workers Cache(`routeRules`)       | Worker の手前   | HTML 応答まるごと  |
| オブジェクトキャッシュ(`kvCache`) | Worker の中、KV | DBクエリの結果     |
| `requestCache`                    | 1リクエスト内   | 同一呼び出しの重複 |

## 手順

### 1. Worker を D1 primary の隣へ寄せる。リードレプリカは使わない

公式([Deploy to Cloudflare](https://docs.emdashcms.com/deployment/cloudflare/) の Targeted Placement)の推奨は、**Worker を D1 primary の近くで走らせ、`session` は既定の `"disabled"` のまま、read replica を有効にしない**ことである。**`session: "auto"` + read replica で訪問者の近くから読む構成は、この推奨とは逆**である。

エッジキャッシュが MISS したときの遅さは、ほぼここで決まる。EmDash の SSR は D1 へ**直列に**10往復前後する。実測(primary が SIN、Worker が KIX、`session: "auto"`、read replication `auto`)では、1往復 80–90 ms が積み上がって `db.total` 878 ms / 10 本になった。**read replication を有効にしていても速くならなかった。** Placement で SIN に寄せると、同じページで 10–47 ms になる。**エラーは何も出ない。**

**この手順は [PLACEMENT.md](./PLACEMENT.md) を読んでから進める** — 下の完了基準に要る primary の colo の調べ方(D1 の GET API では分からない)と `placement` のリージョン値、止める場所が2つあること(`session` と、D1 側の read replication)はそちらにある。

エッジの HTML キャッシュは Worker の手前(訪問者の近く)に立つので、HIT したときの速さは Placement では変わらない。

**完了基準:** MISS した応答に `cf-placement: remote-<primary の colo>` が付き、`Server-Timing` の `db.total` が数十 ms に収まっている。

### 2. `routeRules` は公開ルートを1つずつ挙げる

**catch-all を書かない。** `/[...path]` を1本書くと管理画面とAPIが共有エッジキャッシュに載る。理由は下の空振り表の1番。

対象は `src/pages/` の公開ルートだけ。`/search` と 404、自前で `Cache-Control` を出しているルート(`rss.xml` など)は載せない。

`maxAge` は「更新してからサイトに出るまでの遅延」でもある(公式の例は 300 秒)。許せる遅延で決め、`swr` を長く(86400)取って**パージ漏れを時間で吸収する**。`swr` があるので訪問者は待たされない — ただし、エントリが残っているあいだに限る([MISS.md](./MISS.md))。

**完了基準:** `routeRules` のキーがすべて `src/pages` に実在するファイルへ解決する。

### 3. キャッシュから外す判断は middleware に置き、`set(false)` だけ呼ぶ

ページのフロントマターではなく、**`await next()` の後**で決める(順序依存は空振り表の3番)。**ヘッダは書かない。**

```ts
export const onRequest = defineMiddleware(async (context, next) => {
  const response = await next();
  // 200・304 以外(rewrite で描かれる 404 を含む)と /search。304 は条件付きリクエストの再検証なので外さない
  if (mustNotStore(response.status, context.url.pathname)) context.cache?.set(false);
  return response;
});
```

`set(false)` だけで足りるのは、`@astrojs/cloudflare`(14.x)が cache provider の有効なとき、`Cloudflare-CDN-Cache-Control` の無い応答に自分で `no-store` を付けるからである(`dist/utils/response.js` の `applyCloudflareResponseHeaders`)。

**`Cache-Control` を書き足さない。** EmDash の `/_emdash/oauth/authorize` が返す `Response.redirect()` はヘッダが immutable で、`headers.set()` が `TypeError` を投げて **OAuth 認可が 500 になる**(dev で再現、[kjfsm/euphoric-band-site#160](https://github.com/kjfsm/euphoric-band-site/pull/160))。

**レイアウトでヒントを立てるなら `routeRules` に載ったルートに限る。** レイアウトは `await next()` が返ったあと、ストリーミングの中で描かれるので、立てると middleware で断った `/search` が `public` に戻る。

`Astro.rewrite()` で描かれる 404 は pathname が `/blog/存在しないslug` のままなので、`/blog/[slug]` のルールを**継承する**。`Astro.redirect("/404")` で返す構成なら、その 302 が同じ理由でキャッシュされる。

### 4. `toolbar` を `"client"` にする

`false` にしない。理由は空振り表の2番。

### 5. 本番へ出して測る

`provideCache` は development で常に `NoopAstroCache` を返す。**dev では一切効かないので、ローカルでは何も確認できない。**

```bash
curl -sS -D - -o /dev/null -H 'Accept: text/html' https://例.com/ | grep -i 'cf-cache-status\|server-timing'
```

2回叩いて `MISS` → `HIT` になり、キャッシュしない経路が `BYPASS` であることを見る。命中時は `Server-Timing` の値が毎回同一になる — ヘッダごとキャッシュから返っている証拠である。

**完了基準:** 管理画面(`/_emdash/admin`)が `BYPASS` であることを確かめている。ここが `HIT` なら catch-all を書いている。

**`swr` があっても、アクセスの少ないサイトでは MISS が残る。** 追い出され方、自分でオンにしない限り off の Smart Tiered Cache、MISS をわざと起こして TTFB を分解する測り方、Placement の後に残る遅さの2つの型は [MISS.md](./MISS.md)。

## 空振りの一覧

### 1. `private, no-store` は `routeRules` に踏み越えられる

**公式の優先順**([CDN-Cache-Control](https://developers.cloudflare.com/cache/concepts/cdn-cache-control/))。Cloudflare がキャッシュ判定に読むのは、上から最初に在るもの**1つだけ**である。

1. Cache Rules の `set_cache_control`(ダッシュボード側)
2. `Cloudflare-CDN-Cache-Control`
3. `CDN-Cache-Control`
4. `Cache-Control`

**2 は下流へ proxy されない** — 「a header only used to control Cloudflare」。3 は間に他のCDNが居る場合のために通される。**だから 2 が効いていても `curl` には映らず、4 だけが見える。**

当たった `routeRules` は 2 として載る。適用は無条件で、既存のヘッダを見ない(`astro/dist/core/cache/runtime/cache.js` の `APPLY_HEADERS` は `response.headers.set` するだけ)。自分で書いた `private, no-store` は 4 なので、順位で負ける。

そして EmDash の request-context middleware は `/_emdash` を**早期 return** するので、管理UIとAPIは route cache の opt-out を通らない。自前で出している `private, no-store` だけが頼りで、それが上書きされる。

`routeRules` は**全リクエストの pathname に対して**マッチされる。実在しないパスへのルールも同じ理由で危険側に倒れる。

### 2. `toolbar: false` は編集用応答の保護を落とす

公式の表は `false` を「ツールバーとブートストラップを描かない」としか書いていない。実装ではこの枝の中で opt-out している:

```js
if (isEditor && toolbarMode !== false) {
  return injectToolbar(response, toolbarHtml, routeCache); // ← ここで opt-out + no-store
}
```

`false` にすると、`emdash-edit-mode` クッキーを持った編集者への**編集用マークアップが opt-out されないまま共有キャッシュに載りうる**。ツールバーが不要でも `"client"` を選ぶ。

preview トークン経由の下書きは別途 opt-out されているので漏れない。

### 3. `private, no-store` はキャッシュを止めない

**公式は「session-dependent なものには `private, no-store` を付けろ」と書いているが、それだけでは止まらない。** 実測: `routeRules` にも載せていない検索ページが、`private, no-store` を返しながら `cf-cache-status: HIT` になる。

provider の `setHeaders` は `["public"]` を**常に先頭へ積む**:

```js
const directives = [];
if (extraDirectives) directives.push(...extraDirectives); // ["public"]
if (options.maxAge !== void 0) directives.push(`max-age=${options.maxAge}`);
return directives.length > 0 ? directives.join(", ") : void 0;
```

`maxAge` が無くても `Cloudflare-CDN-Cache-Control: public` が出る。1番の優先順のとおり、これは `Cache-Control` に勝ち、**しかも下流へ proxy されないので `curl` からは見えない**。

`APPLY_HEADERS` は「`maxAge` 未定義 かつ タグ0件」なら早期 return するが、**描画中に `cacheHint` が1つでも set されるとそこを抜ける**。EmDash は本番の全リクエストで `lastModified` を set し(`applyBuildValidator`。prerender と dev は除く)、取得層も `cacheHint` を set する。つまり**普通のページはまず抜ける**。

だから止めるのは `set(false)` の側で、`Cache-Control` は要らない(手順 3)。応答を複製してから書けば投げないが、1番の優先順でエッジが読むのはアダプタの `Cloudflare-CDN-Cache-Control` なので、得るものが無い。アダプタのそれは cache provider が有効なときだけで、外した構成ではヘッダの無い応答が RFC 9111 ヒューリスティック鮮度で2時間保存されうる — **provider を外すなら、そのときだけ middleware で `new Response(response.body, response)` に複製してから `no-store` を書く。**

**順序依存がある。** `set(false)` は private な `#disabled` を立てるだけで、**後から `set()` が非 false で呼ばれると解除される**。フロントマターの末尾でも足りない(次の段落)。`await next()` の後の middleware に置く。

**`Astro.cache.enabled` は安全網にならない。** あれは `set(false)` が触らない素のフィールドなので、取得層によくある `if (astro.cache?.enabled) astro.cache.set(cacheHint)` というガードは opt-out を尊重しない。レイアウトやコンポーネントがページのフロントマターより後に取得すれば、黙って再有効化される。同じ指摘が
[emdash#1882](https://github.com/emdash-cms/emdash/issues/1882) にある --
「ideally after `await next()` so downstream/page-level cache hints cannot re-enable caching」。
あの issue は編集ツールバー入りHTMLが `private, no-store` 付きで Workers Cache に入った報告で、
**同じ失敗モードである**。

### 4. MCP 経由の公開はエッジをパージしない

`astro/routes/api/mcp.mjs` に `cache` の参照が**1つも無い**。MCP ツールは `handleContentPublish()` を直接叩く。パージを呼ぶのは `astro/routes/api/content/` 配下のAPIルートだけで、そこを通る管理画面と REST は即時に反映される。

一方 `invalidateCollectionCache()` は ContentRepository 層にあるので、**MCP でも KV(オブジェクトキャッシュ)は飛ぶ**。エッジのHTMLだけが取り残される。この食い違いは外から見えない。

**taxonomy / メニュー / サイト設定 / byline の変更は、経路を問わずエッジをパージしない。**

反映までの上限は `maxAge` だけではない。KV の epoch 伝播が最大60秒乗る(公式)。さらに `swr` があるので「待てば自分の画面に出る」とは限らない — `maxAge` 切れ後の最初のアクセスは古い版を受け取り、取得は背景で走る。**確認は待ってから2回読み込む。**

### 5. byline はオブジェクトキャッシュに乗らない

公式の「What gets cached」に byline は無く、実装でも毎回DBを引く。レイアウトから全ページで読む構成なら、サイト側で `cachedQuery` に載せられる — [BYLINE.md](./BYLINE.md)。

### 6. `Server-Timing` の `cache.hit` / `cache.miss` は KV ではない

加算しているのは `request-cache-*.mjs` — **リクエストスコープのメモ化キャッシュ**である。`object-cache-*.mjs` は metrics を一切触らない。

**同じページを何度叩いても値が動かないのは正常** で、リクエストごとにゼロから数え直すからである。ここを KV のヒット率と読むと、存在しない問題を追うことになる。

**KV のキー単位のヒット/ミスを観測する公式手段は無い。** ログは `import.meta.env.DEV` ガードの中にしかなく、`kvCache()` にデバッグオプションも無い。見るならキーを直接数える:

```bash
wrangler kv key list --binding CACHE --remote
```

読むべきは `db.count`(クエリ本数)と `db.total`(DB合計)で、`db.total == render` ならレンダリング時間はすべてDB待ちである。 `db.last − db.first` が `db.total` に近ければ、クエリは直列に並んでいる。そこで1本あたりの時間(`db.total / db.count`)が数十 ms あるなら、Worker と D1 primary が離れている(手順 1)。

**KV の待ちは `db.total` に入らない。** `mw` が大きいのに `db.total` が小さければ、時間は KV の読み取りに消えている([MISS.md](./MISS.md))。

### 7. `Astro.cache.set(cacheHint)` は provider が無いと空振りする

取得層に書いてあっても、`cache.provider` を設定するまで `Astro.cache.enabled` は false で、呼び出しは全部落ちる。**先に書いておいて後から効き始める**性質なので、「もう書いてある」ことは効いていることを意味しない。

## 機構にする

上の空振りはどれも書き忘れても何も言わない。ソース走査型のガードテストで留める。

- `routeRules` のキーが `src/pages` に実在するルートだけであること(catch-all と打ち間違いを同時に捕まえる)
- middleware が `await next()` の**後**で `set(false)` を呼んでいること
- その middleware が応答ヘッダを書いていないこと(`Response.redirect()` で投げる)。これは「無いこと」の検査なので、**行頭に固定した `^\s*const \w+ = await next\(\);` から後ろだけを切り出して**見る — 全文に当てると、理由を書いた冒頭の JSDoc に当たって正しい実装が赤になる。式は変数名に依存させない(`\.headers\.(?:set|append|delete)\(`)
- 404 を status で見分けていること(rewrite 構成では pathname が元のまま)、あるいは `Astro.redirect("/404")` を直接書いていないこと(リダイレクト構成)

**正規表現は行頭に固定する。** 見張る対象の行は、すぐ隣のコメントで理由を説明されている行でもある。緩く書くと散文のほうに当たり、実装を消しても緑のままになる。
