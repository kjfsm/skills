# Service Worker を入れるとき

オフラインの1枚・Web Push・バッジ・自前のインストールボタンが要ると決めたときだけ読む。**溜めるのはビルド成果物(JS/CSS)とオフラインの1枚だけで、画面(HTML)と API の応答は溜めない。** Cache API はオリジン単位なので、サインインした本人あての画面を溜めると、サインアウトした端末に前の人の中身が残る。

## 形: vite-plugin-pwa の `injectManifest`

```ts
// vite.config.ts
VitePWA({
  strategies: "injectManifest",
  srcDir: "app",
  filename: "sw.js",
  registerType: "prompt",
  injectRegister: null, // 登録は更新バナーの側で行う
  manifest: false, // manifest とアイコンは public/ のまま(SKILL.md の 3. 4.)
  devOptions: { enabled: false },
  injectManifest: { globPatterns: ["**/*.{js,css}"] },
});
```

| 設定                                    | 外すと何が壊れるか                                                                                                                                                                                                                                       |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `injectManifest`(`generateSW` ではない) | `generateSW` の既定はナビゲーションに precache した HTML を返し、Worker の締め出しを SW が素通りさせる                                                                                                                                                   |
| `globPatterns` に `html` を入れない     | 既定は `**/*.{js,css,html}` で `index.html` が黙って入る。SPA の入口が `run_worker_first` に当たっていると、サインインしていない端末では `/signin` への 302 が返って **install ごと失敗し、SW が一度も登録されない**。サインイン済みの手元では再現しない |
| `registerType: "prompt"`                | 勝手に入れ替わって読みかけ・書きかけの画面を捨てる                                                                                                                                                                                                       |
| `devOptions.enabled: false`             | 手元の変更が古い写しに隠される                                                                                                                                                                                                                           |

**precache の一覧が `sw.js` に焼き込まれることだけが、更新検知を成立させている。** ビルド成果物のハッシュが `sw.js` の中身に現れるので、配り直すたびにブラウザが新しい SW を見つける。手書きの `sw.js` は1バイトも変わらず、何度配っても更新が届かない。

## `sw.js` の骨組み

```js
import { precacheAndRoute } from "workbox-precaching";

const CACHE = "<app>-offline-v1"; // offline の1枚を差し替えたら上げる(install は sw.js が変わったときしか走らない)
const OFFLINE_URL = "/offline"; // Workers の assets は /offline.html を /offline へ 307 で寄せ、cache.add() はリダイレクトを受け取らない

precacheAndRoute(self.__WB_MANIFEST);

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.add(new Request(OFFLINE_URL, { cache: "reload" })))
      .catch(() => undefined), // 落とすと fetch ハンドラを持つ SW が居なくなり、beforeinstallprompt も消える
  );
  // skipWaiting() はここで呼ばない — 待機中の SW が生まれず、更新バナーを出す相手が居なくなる
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k.startsWith("<app>-") && k !== CACHE).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("message", (event) => {
  if (event.data?.type === "SKIP_WAITING") self.skipWaiting(); // 利用者が「更新」を押したときだけ
});

// navigate だけを拾う。/api/ の失敗まで拾うと、画面が JSON の代わりに HTML を受け取る
self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return;
  event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));
});
```

`wrangler.jsonc` の `assets.run_worker_first` から、manifest・アイコンに加えて `!/sw.js` `!/offline` `!/offline.html` を名指しで外す — 外さないと Worker の締め出しが先に立ち、サインインしていない端末では SW も offline の1枚も取れない。`/offline.html` も外すのは、`html_handling` の既定が `/offline` への 307 をそこで返すためである。

画面の側は `virtual:pwa-register/react` の `useRegisterSW` が登録と `needRefresh` を持ち、それを受けて更新バナーを出す。押されたら `registration.waiting` に `{ type: "SKIP_WAITING" }` を送って読み直す。待機中の SW が見えない窓(登録を掴む前に開いた窓)は、送らずに読み直すだけにする。

## Web Push を足すなら

- **`push` を受けたら必ず `showNotification` する。** iOS は表示しない push を許さず、続くと購読が取り消される。送るかどうかはサーバー側で決め終えておく
- iOS の Web Push はホーム画面に追加したアプリでだけ動く(16.4 以降)
- 購読の前に、いま動いている SW が push を扱える版かを `postMessage` で確かめる — 古い版が受けると表示しない push になる

## 確かめ方

SKILL.md の 5. に加えて、**サインインしていない新しいプロファイル** で本番ビルドを開き、DevTools の Application → Service Workers で `activated` になること、Cache Storage に HTML が1枚も無いこと(offline の1枚を除く)を見る。配り直したあとに更新バナーが出ることも1度確かめる。
