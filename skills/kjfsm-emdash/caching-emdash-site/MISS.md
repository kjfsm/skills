# エッジキャッシュの MISS

**`swr: 86400` はエントリが1日残ることを約束しない。** アクセスの少ないサイトでは、colo ごとのキャッシュから数分で追い出される。実測では、温めて7分後に同じ KIX から叩くと、ページによって `UPDATING`(即返る)と `MISS`(SSR を丸ごと待つ)に分かれた。匿名訪問の約4割が `miss`/`expired` だった。「しばらく経ってからの初回が遅い」の正体はたいていこれで、[SKILL.md](./SKILL.md) の手順 1 がそのときの待ち時間を決める。

ゾーン側の **Smart Tiered Cache は、自分でオンにしない限り off のまま**である(実際のゾーンで off だった)。Worker の設定画面にある「Cache」(`wrangler.jsonc` の `"cache"`)とは別の設定で、あちらが有効でもこちらは off のままになる。colo の MISS を上位のキャッシュで拾わせるにはオンにする(Free プランでも使える。MISS がどれだけ減るかはまだ測っていない):

```
PATCH /zones/{zone_id}/cache/tiered_cache_smart_topology_enable   {"value": "on"}
```

MISS をわざと起こして測るには、クエリ文字列を付ける。`routeRules` は pathname だけを見て当たる一方、Cloudflare のキャッシュキーにはクエリが入る。

`Server-Timing` に出るのは middleware から内側だけである。**TTFB と `mw` の差**が、往復と isolate の起動にかかった時間になる。Placement の後でも、isolate が冷えているときは TTFB が 1 秒を超える(`mw` は 150 ms 程度)。
