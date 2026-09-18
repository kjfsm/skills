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

**primary の colo は D1 の GET API からは分からない** — `running_in_region` は `"APAC"` までしか返さない。クエリ API で1本投げ、`meta` を読む:

```
POST /accounts/{account_id}/d1/database/{database_id}/query   {"sql": "select 1"}
→ meta.served_by_colo: "SIN", meta.served_by_primary: true
```

colo からリージョン値への対応表は、Placement のドキュメントにも無い。自分で当てる(SIN → `aws:ap-southeast-1`):

```jsonc
// wrangler.jsonc
"placement": { "region": "aws:ap-southeast-1" },
```

**止める場所は2つある。** `d1({ binding: "DB" })` から `session` を外すことと、D1 側の read replication を `disabled` にすること(API の `PATCH .../d1/database/{id}` に `{"read_replication": {"mode": "disabled"}}`、またはダッシュボードの Settings → Read replication)。後者は DB の設定なので、コードのデプロイでは変わらない。

エッジの HTML キャッシュは Worker の手前(訪問者の近く)に立つので、HIT したときの速さは Placement では変わらない。

**完了基準:** MISS した応答に `cf-placement: remote-<primary の colo>` が付き、`Server-Timing` の `db.total` が数十 ms に収まっている。

### 2. `routeRules` は公開ルートを1つずつ挙げる

**catch-all を書かない。** `/[...path]` を1本書くと管理画面とAPIが共有エッジキャッシュに載る。理由は下の空振り表の1番。

対象は `src/pages/` の公開ルートだけ。`/search` と 404、自前で `Cache-Control` を出しているルート(`rss.xml` など)は載せない。

`maxAge` は「更新してからサイトに出るまでの遅延」でもある(公式の例は 300 秒)。許せる遅延で決め、`swr` を長く(86400)取って**パージ漏れを時間で吸収する**。`swr` があるので訪問者は待たされない — ただし、エントリが残っているあいだに限る([MISS.md](./MISS.md))。

**完了基準:** `routeRules` のキーがすべて `src/pages` に実在するファイルへ解決する。

### 3. キャッシュから外す経路は2つ書く。置く場所は取得より後

`Astro.cache.set(false)` と明示的な `Cache-Control` の**両方**が要る。片方だけでは外れない(空振り表の3番)。

```astro
// 取得より **後**。`set()` は false 以外の入力で opt-out を解除する。
Astro.cache?.set(false);
Astro.response.headers.set("Cache-Control", "private, no-store");
```

**公式の「`private, no-store` を付けろ」だけでは足りない。** 空振り表の3番を読むこと。

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

**`swr` があっても、アクセスの少ないサイトでは MISS が残る。** 追い出され方、自分でオンにしない限り off の Smart Tiered Cache、MISS をわざと起こして TTFB を分解する測り方は [MISS.md](./MISS.md)。

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

逆向きも成り立つ。`set(false)` はヘッダを付けなくするだけなので、**ヘッダの無い応答は RFC 9111 ヒューリスティック鮮度で2時間保存される**。

だから**両方書く**。役割が違う。

**順序依存がある。** `set(false)` は private な `#disabled` を立てるだけで、**後から `set()` が非 false で呼ばれると解除される**。取得より後、フロントマターの末尾に置くこと。

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

### 6. `Server-Timing` の `cache.hit` / `cache.miss` は KV ではない

加算しているのは `request-cache-*.mjs` — **リクエストスコープのメモ化キャッシュ**である。`object-cache-*.mjs` は metrics を一切触らない。

**同じページを何度叩いても値が動かないのは正常** で、リクエストごとにゼロから数え直すからである。ここを KV のヒット率と読むと、存在しない問題を追うことになる。

**KV のキー単位のヒット/ミスを観測する公式手段は無い。** ログは `import.meta.env.DEV` ガードの中にしかなく、`kvCache()` にデバッグオプションも無い。見るならキーを直接数える:

```bash
wrangler kv key list --binding CACHE --remote
```

読むべきは `db.count`(クエリ本数)と `db.total`(DB合計)で、`db.total == render` ならレンダリング時間はすべてDB待ちである。 `db.last − db.first` が `db.total` に近ければ、クエリは直列に並んでいる。そこで1本あたりの時間(`db.total / db.count`)が数十 ms あるなら、Worker と D1 primary が離れている(手順 1)。

### 7. `Astro.cache.set(cacheHint)` は provider が無いと空振りする

取得層に書いてあっても、`cache.provider` を設定するまで `Astro.cache.enabled` は false で、呼び出しは全部落ちる。**先に書いておいて後から効き始める**性質なので、「もう書いてある」ことは効いていることを意味しない。

## 機構にする

上の空振りはどれも書き忘れても何も言わない。ソース走査型のガードテストで留める。

- `routeRules` のキーが `src/pages` に実在するルートだけであること(catch-all と打ち間違いを同時に捕まえる)
- キャッシュしない経路が `set(false)` と明示的な `Cache-Control` を**2行とも**出していること
- 404 が `Astro.cache.set(false)` を呼んでいること(rewrite 構成)、あるいは `Astro.redirect("/404")` を直接書いていないこと(リダイレクト構成)

**正規表現は行頭に固定する。** 見張る対象の行は、すぐ隣のコメントで理由を説明されている行でもある。緩く書くと散文のほうに当たり、実装を消しても緑のままになる。
