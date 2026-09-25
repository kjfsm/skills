# これまで当ててきたパッチ

EmDash サイトに当ててきたパッチの記録。新しく当てたとき、作り直したとき、外したときに更新する。

今どのパッチが当たっているかは、各サイトの `patches/` と `pnpm-workspace.yaml` の `patchedDependencies` を見る。ここに残すのは、**なぜ当てるか・何を変えるか・どこまで追ったか** である。

## 目次

- [`@emdash-cms/admin`: 日時フィールドのタイムゾーン](#emdash-cmsadmin-日時フィールドのタイムゾーン)(2026-07-21〜2026-09-23、0.39.0 で上流が直した)
- [`emdash`: Cloudflare Access 認証が、リクエストのたびにセッションを KV へ書き込む](#emdash-cloudflare-access-認証がリクエストのたびにセッションを-kv-へ書き込む)(2026-09-17〜)

## `@emdash-cms/admin`: 日時フィールドのタイムゾーン

- **当て始めた日:** 2026-07-21
- **外した日:** 2026-09-23(0.39.1 へ上げたとき)。上流 #3146(0.39.0)で、日時フィールドがサイト設定のタイムゾーン(`manifest.timezone`)で表示・入力するようになった。パッチで `+09:00` 付きのまま保存された値は、同じ版のコアマイグレーションが UTC の ISO 文字列へ正規化する
- **直すファイル:** `dist/index.js`

### 当てる理由

管理画面の日時フィールド(`<input type="datetime-local">`)が、値を **UTC のまま** 読み書きする。

- **表示:** 保存値(`2026-09-17T03:00:00.000Z`)の先頭16文字(`2026-09-17T03:00`)を、そのまま入力欄に入れる。
- **保存:** 入力値の末尾に `:00.000Z` を付けるだけである。

そのため、日本時間の 12:00 のつもりで入れた値が UTC の 12:00 として保存され、9 時間ずれる。サイト設定にタイムゾーン(`settings.timezone`)があっても、このフィールドは使っていない。

日時フィールド(イベントの日時など)に UTC 以外の時刻で入力するサイトなら当てる。すべて UTC で運用するサイトなら要らない。

### 当てる内容

1. `toDatetimeLocalInputValue` と `fromDatetimeLocalInputValue` に、第2引数 `timeZone`(既定 `"UTC"`)を足す。
   - **表示するとき:** 保存値を `Date` にし、`timeZone` のオフセットを足した壁時計の時刻を `YYYY-MM-DDTHH:mm` で返す。
   - **保存するとき:** 入力値を `timeZone` の壁時計の時刻として読み、そのオフセット付きの ISO 文字列(`2026-09-17T12:00:00+09:00`)で返す。夏時間の境目でずれないよう、オフセットは求めた時刻でもう一度計算し直す。
2. オフセットは `Intl.DateTimeFormat("en-US", { timeZone, hourCycle: "h23", … }).formatToParts(date)` から組み立てる(`getTimeZoneOffsetMs`)。`+HH:mm` への整形は `formatOffset`。
3. 呼び出し側の `SubFieldInput`(リピーターの中の日時)と `FieldRenderer`(通常の日時フィールド)で、サイト設定を読んで渡す:

   ```js
   const { data: fieldSettings } = useQuery({ queryKey: ["settings"], queryFn: fetchSettings, staleTime: Infinity });
   const fieldTimeZone = fieldSettings?.timezone || "UTC";
   // …
   value: toDatetimeLocalInputValue(value, fieldTimeZone),
   onChange: (e) => handleChange(fromDatetimeLocalInputValue(e.target.value, fieldTimeZone)),
   ```

   `queryKey: ["settings"]` は管理画面の設定ページと同じキーなので、取得は1回で済む。

### 上流

- **状況:** 該当する issue は見当たらない(2026-09-17 時点)。
- **近いもの:** #2773(保存値をそのまま保存していて SQL の並び順が壊れる)と #2896(`content.schedule()` が UTC に正規化しない)。どちらも保存側の話で、入力欄の表示は扱っていない。
- **外せる条件:** 上流の日時フィールドが、サイトのタイムゾーンで表示・入力するようになったとき。

### 作り直しの履歴

毎回、中身は同じで、当たる行番号だけが動いた。

| 日付              | 版      | メモ                                                         |
| ----------------- | ------- | ------------------------------------------------------------ |
| 2026-07-21        | 0.29 系 | 導入。キーは版なし                                           |
| 2026-07-25〜08-06 | 0.31.1  | `ERR_PNPM_PATCH_FAILED` で気づいて作り直し、版付きキーにした |
| 2026-08-29〜09-01 | 0.35.0  |                                                              |
| 2026-09-08        | 0.36.0  |                                                              |
| 2026-09-14        | 0.37.0  |                                                              |
| 2026-09-16        | 0.38.0  |                                                              |
| 2026-09-23        | 0.39.1  | 外した(上流 #3146)                                           |

## `emdash`: Cloudflare Access 認証が、リクエストのたびにセッションを KV へ書き込む

- **当て始めた日:** 2026-09-17(0.38.0)
- **直すファイル:** `dist/astro/middleware/auth.mjs` の `handleExternalAuth`(上流では `packages/core/src/astro/middleware/auth.ts`)

### 当てる理由

Cloudflare Access 認証(`auth: access({ … })`)を使うと、`/_emdash` へのリクエストのたびに次の行が無条件に実行される。

```js
session?.set("user", { id: user.id });
```

- Astro の `session.set()` は、値が同じでも変更ありとして扱い、リクエストの終わりに `storage.setItem` で保存し直す(`astro/dist/core/session/runtime.js`)。
- Cloudflare アダプターはセッションを KV(自動で作られる `SESSION` バインディング)に置く。
- そのため、**管理画面の API 呼び出し1回ごとに、KV の書き込みが1回発生する。**

Workers の無料プランの KV の書き込みは、**アカウント全体で1日 1,000 回** である。超えると、その日の残りは KV への書き込みが失敗する(00:00 UTC にリセット)。

**実際に起きたこと(2026-09-16):**

- アカウントの KV の書き込みが 1,219 回になり、上限を超えた。
- 内訳は、Access 認証を使うサイトの SESSION が 577 回(OG 画像の一括生成をした1時間だけで 306 回)、同じサイトのオブジェクトキャッシュ(CACHE)が 482 回、同じアカウントのほかのサービスが約 160 回。
- 集計は Cloudflare GraphQL の `kvOperationsAdaptiveGroups` を、`namespaceId`・`actionType`・`datetimeHour` ごとに取った。

**当てる条件:** Access 認証を使うサイトなら当てる。passkey・OAuth(Google / GitHub)・magic link でログインするサイトには要らない。これらがセッションに書き込むのはログインの完了時だけで、passkey のサイトで管理画面を開いたときも、SESSION の読み取り 13 回に対して書き込みは 1 回だった。

### 当てる内容

上の行を、セッションの `user` の ID が違うときだけ `set` する形に変える。

```js
/** [patched: …] Astro persists the session on every set(), even with an unchanged value — skip it so each authenticated request does not cost a KV write. */
if ((await resolveSessionUser(session))?.id !== user.id) session?.set("user", { id: user.id });
```

- **`resolveSessionUser` を使う理由:** 同じファイルがすでに import している関数で、セッションの読み取りが止まってもリクエストを巻き込まない(#1274 の対策)。新しい import を足すと、`dist` のチャンク名が版ごとに変わるので上げたときに壊れる。
- **KV の読み取りは増えない:** Astro はセッションを1リクエストに1回しかストレージから読まない。その読み取りは、EmDash のミドルウェアの冒頭ですでに済んでいる。クッキー `astro-session` が無いときは、ストレージを読まずに `set` へ進む。
- **セッションが期限切れや不在のとき:** 今までどおり `set` される。

**効果(本番で確認、2026-09-17):** Access 認証は dev では passkey に切り替わるため、本番で比べた。

| 版                                 | SESSION の読み取り | SESSION の書き込み |
| ---------------------------------- | ------------------ | ------------------ |
| パッチあり                         | 51 回              | 1 回               |
| パッチ前の版へ一時的にロールバック | 41 回              | 35 回              |

集計の反映は数分遅れ、直後は読み取りも 0 に見えた。

### 上流

- **状況:** 報告なし(2026-09-17 時点)。0.40.0(2026-09-25)でも同じ書き方のまま。
- **近いもの:**
  - #733(匿名アクセスでのセッションの KV **読み取り**。解決済み)
  - #2054(Access 認証がリクエストのたびにユーザー名を上書きする。未解決。書き込み先は D1 で、名前が食い違うときだけ起きる)
- **外せる条件:** 上流の `handleExternalAuth` が、同じユーザーのときに `session.set` を呼ばなくなったとき。

### 作り直しの履歴

| 日付       | 版     | メモ                             |
| ---------- | ------ | -------------------------------- |
| 2026-09-17 | 0.38.0 | 導入                             |
| 2026-09-23 | 0.39.1 | 上流は同じ書き方のまま。作り直し |
| 2026-09-25 | 0.40.0 | 上流は同じ書き方のまま。作り直し |

### 残っている課題

オブジェクトキャッシュ(`kvCache`)の書き込みは、このパッチでは減らない。コンテンツを変えるとキャッシュの世代(`em:epoch:*`)が進み、次の表示で作り直されるので、編集が集中する日に増える。
