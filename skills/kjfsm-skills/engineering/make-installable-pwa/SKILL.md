---
name: make-installable-pwa
description: Web アプリ(主に Cloudflare Workers の Vite React SPA)を、ホーム画面へインストールできる PWA にする — manifest・アイコン・iOS 向けの meta を足し、Service Worker は既定で入れない。「PWA にして」「ホーム画面に追加できるように」「アプリとしてインストールできるように」と頼まれたとき、manifest やアプリのアイコンを作るとき、Service Worker を入れるか決めるとき、インストールできない・`Page.getInstallabilityErrors` が空にならないときに使う。standalone での見た目(safe area・100vh・ステータスバー)は `mobile-native` が持つ。
---

# ホーム画面へインストールできるようにする

**インストールに要るのは manifest とアイコンと数行の meta であって、Service Worker ではない。** SW は入れた瞬間からキャッシュと更新検知を抱え、その壊れ方(古い画面が居座る、締め出しを素通りする、更新が届かない)はインストールできないことより高くつく。

## 1. Service Worker を入れるか決める

**既定は入れない。** 根拠(2026-10 時点の一次資料):

- Chromium はメニューからのインストールに fetch ハンドラ付きの SW を要求しない(モバイル 108 / デスクトップ 112 以降)— [developer.chrome.com, 2023-12-05](https://developer.chrome.com/blog/update-install-criteria)
- ただし同じ記事は「インストールのプロンプト(`beforeinstallprompt`)の判定はまだ fetch ハンドラを要する」と書く。新しい [web.dev の条件一覧(2024-09-19)](https://web.dev/articles/install-criteria) には SW が無く、どちらが今の挙動かは確定していない
- iOS は `beforeinstallprompt` に対応せず、ホーム画面への追加に SW は要らない(MDN)。iOS 16.4 以降は Safari 以外のブラウザの共有メニューからも追加できる

| アプリが要るもの                               | SW                                                                                                          |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 入れるだけ(ブラウザのメニュー・iOS の共有から) | **入れない**                                                                                                |
| 自前の「インストール」ボタン                   | fetch ハンドラだけの最小の SW を検討する(上の未確定のため。入れる前に実機で試す)                            |
| Web Push だけ                                  | **push だけの SW**(fetch もキャッシュも持たない) → [`SERVICE-WORKER.md`](SERVICE-WORKER.md) の「push だけ」 |
| オフラインの1枚                                | キャッシュを持つ SW → [`SERVICE-WORKER.md`](SERVICE-WORKER.md) の「キャッシュも持つ」                       |

**メニューからのインストールのためだけに、何もしない fetch ハンドラを足さない。** 上の Chromium の版以降、その条件に入っていない。

**同期やサーバー側の生成物(PDF・検索結果)が無いと何もできないアプリは、オフライン対応を求められても一度押し返す** — 圏外で出せるのは「圏外です」の1枚だけで、そのために SW の壊れ方を全部引き受けることになる。

**完了基準: 入れるか入れないかと、その理由を1行で言えること。** 入れないなら 2. から、入れるなら `SERVICE-WORKER.md` を読んでから 2. へ進む(manifest とアイコンはどちらでも同じ)。

## 2. ユーザーに3つだけ確かめる

1つの質問にまとめて聞く。

- **アイコンの図柄** — lucide のアイコン名で。アプリの中で既に使っている lucide があればそれを候補に挙げる
- **地の色** — 既定はアプリの primary(Tailwind / shadcn なら `--primary` の値)。グリフは白抜き
- **`name` と `short_name`** — `short_name` はホーム画面のラベルになり、長いと端末が切る

**完了基準: 3つが決まり、地の色が `#rrggbb` で手元にある。**

## 3. アイコンを起こす

**描画は `@resvg/resvg-js`(MPL-2.0)で行い、`sharp` は使わない。** sharp の本体は Apache-2.0 だが、同梱の libvips が LGPL-3.0 である。**対象リポジトリの `AGENTS.md`(や `LICENSE`・依存の方針)にライセンス条件があれば、resvg と lucide(ISC)をそれに照らしてから入れる。** 条件が resvg も弾くなら、止めてユーザーに聞く。

1. `pnpm add -D @resvg/resvg-js`
2. [`templates/generate-icons.mjs`](templates/generate-icons.mjs) を読み、対象の `scripts/generate-icons.mjs` に写す。`BRAND` に地の色を、`GLYPH` にグリフを入れる。グリフは node_modules を読めなくても取れる:
   ```sh
   gh api repos/lucide-icons/lucide/contents/icons/<name>.svg -H 'Accept: application/vnd.github.raw'
   ```
   外側の `<svg>` を剥がし、中の `<path>` などだけを貼る(`stroke` などの属性はひな形の `<g>` が持つ)
3. `package.json` に `"icons:generate": "node scripts/generate-icons.mjs"` を足して走らせる

出るのは4枚。**形が2系統ある** — `any` は角丸の地にグリフ、`maskable` と `apple-touch-icon` は端末がマスクを掛けるので**全面を塗り**、グリフをセーフゾーン(中央 80% の円)の内側に収める(`fraction` 0.5〜0.6)。ひな形の表がその割り当てを持つ。**`"purpose": "any maskable"` の1枚で兼ねない** — どちらに描いても、片方では欠けるか余白が出る。

アイコンは端末がインストールした時点で写しを持つので、差し替えがいつ届くかはブラウザ次第である。差し替えを確実に拾わせたいなら、ファイル名に版を付けて URL ごと変える(`icon-512-v2.png`)。

**完了基準: `public/icons/` に4枚ができ、4枚とも Read で開いて、グリフが欠けず中央にあるのを目で確かめた。**

## 4. manifest と index.html

`public/manifest.webmanifest`:

```json
{
  "id": "/",
  "name": "<name>",
  "short_name": "<short_name>",
  "description": "<1文>",
  "lang": "ja",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#ffffff",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    {
      "src": "/icons/icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

Chromium がインストールに要るのは: `name` か `short_name`、192 と 512 のアイコン、`start_url`、`display`(`fullscreen` / `standalone` / `minimal-ui` / `window-controls-overlay`)、`prefer_related_applications` が無いか `false`。`id` は無くても通るが、後で `start_url` を変えたときに別アプリ扱いされるので最初に固定する。`start_url` はサインイン後の画面(`/app` など)にしてよい。`theme_color` と `background_color` はページ最上部の色(多くは明るい側の背景)に合わせる。

`index.html` の `<head>`:

```html
<link rel="manifest" href="/manifest.webmanifest" />
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
<!-- iOS 16.3 以前は manifest の display を読まない -->
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
```

**React Router の framework mode では `index.html` が無い。** `app/root.tsx` の `links` に manifest と `apple-touch-icon` を、`Layout` の `<head>` に meta を書く。vite-plugin-pwa の HTML への差し込みもここには効かないので、SW を入れる場合も manifest のリンクは自分で書く。

`apple-touch-icon` を置くのは、iOS 15.3 以前が manifest のアイコンを読まずこれだけを見るからである。**`theme-color` は明暗2本**(`mobile-native` §10)。standalone ではブラウザの枠が消えてノッチの下まで画面になるので、固定ヘッダや下部バーがあるなら `viewport-fit=cover` と safe area(同 §7)も合わせて見る。

**完了基準: manifest に上の必須項目がすべてあり、`index.html`(または `root.tsx`)に4行と theme-color 2本がある。**

## 5. 本番ビルドで確かめる

dev サーバーではなく本番ビルドで確かめる — `public/` の配り方と Worker の経路が本番と同じになるのはこちらである。`@cloudflare/vite-plugin` を使っていれば `vite preview` は Worker ごと動く。

```sh
pnpm build && pnpm vite preview --port 4173 &
curl -sI http://localhost:4173/manifest.webmanifest   # 200 / application/manifest+json
node ${CLAUDE_SKILL_DIR}/scripts/check-installable.mjs http://localhost:4173/
```

`check-installable.mjs` は対象リポジトリで走らせる(Playwright をそこから解決する)。Chromium の CDP で `Page.getAppManifest` と `Page.getInstallabilityErrors` を読み、manifest・manifest のアイコン・`apple-touch-icon` を **Cookie なしで** 取り直す。失敗があれば1行ずつ出して exit 1。Playwright が無ければ `/kjfsm-skills:setup-playwright`。**CDP を手で叩いて代えない** — Playwright の既定の headless shell は、`display: "browser"` の manifest にも `Page.getInstallabilityErrors` が空を返す(スクリプトは `channel: "chromium"` の永続プロファイルで開いてこれを避けている。`playwright install chromium` が要る)。

**Cookie なしで取り直すのは、Worker の締め出しを見るためである。** `wrangler.jsonc` の `assets.run_worker_first` が `/*` や HTML を Worker に回している構成では、manifest とアイコンも Worker を通る。そこにサインインの締め出しがあると、サインインしていない端末には `/signin` への 302 が返り、**開発者の手元(サインイン済み)では再現しない形で** インストールできなくなる。`run_worker_first` に当たるなら、`!/manifest.webmanifest` と `!/icons/*` を名指しで外す。

リポジトリに Playwright の E2E があるなら、manifest とアイコンが Cookie なしで 200 を返すことはそこに固定してよい — 締め出しの経路を後から変えたときに落ちる。

**完了基準: `check-installable.mjs` が exit 0 で、`run_worker_first` の有無とその扱いを1行で言える。**

## 6. 実機で確かめることを PR に残す

実機でしか分からないものは、確かめていないと明記して PR の「マージ後に確かめること」に載せる。

- **iOS(iPad / iPhone)**: Safari で本番を開き、共有 →「ホーム画面に追加」。アイコンが出ること、standalone で開くこと、**サインインが通って戻ってくること**
- **Android の Chrome**: メニューの「アプリをインストール」が出ること、maskable のアイコンが欠けないこと

サインインを独立に確かめるのは、iOS の standalone では **別オリジンの IdP(OAuth)へ移るとアプリ内ブラウザで開き、Cookie がホーム画面のアプリと分かれる** ことがあるからである。サインインは済んだのにアプリ側はサインインしていない、という形で戻らない。外部 IdP を使うアプリでは必ず挙げる。

**完了基準: PR 本文に上の確認項目があり、手元で確かめたこと(5.)と分けて書かれている。**
