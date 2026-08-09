---
name: local-mcp-access
description: ローカルのEmDash devサーバーのMCPエンドポイント(/_emdash/api/mcp)をブラウザなしで叩く(dev-bypass経由でPATを発行、Bearer専用)。`emdash-site-local`コネクタが401/未認証のときの復旧もこれ。プラグイン自身の管理設定をBlock Kitの`form_submit`/`block_action`経由で読み書きする方法、および`wrangler d1 execute`(ローカル/`--remote`)でMCPが公開していない情報を直接SQLで読む方法もカバーする。
---

# ローカルMCPアクセス(ブラウザ不要)

> MCPサーバーの一次情報源は
> [reference/mcp-server](https://docs.emdashcms.com/reference/mcp-server/)(エンドポイント、
> 認証方式、OAuthディスカバリ、スコープ表、全ツールのパラメータ)と
> [guides/ai-tools](https://docs.emdashcms.com/guides/ai-tools/)。ツールの一覧や引数を知りたいなら
> そちらを読むこと。
>
> ここに書くのは、**公式と食い違う認証の実際**と、公式に載っていない回避手順だけ。

用途別ナビゲーション: PAT発行が目的なら「手順」節だけ、プラグイン設定の読み書きが
目的なら該当節だけ、D1の直接参照が目的なら最後の節だけ読めばよい。全文を読む必要はない。

## 公式の「セッションクッキーも使える」は信じないこと

`/_emdash/api/mcp` は実際には**Bearerトークン専用**である(emdashのソース内
`packages/core/src/astro/middleware/auth.ts` を確認して判明: このミドルウェアは
MCPエンドポイントに対してセッション/クッキー認証を明示的に参照せず、有効な管理者の
セッションクッキーがあっても `401 NOT_AUTHENTICATED` を返す)。そのためブラウザログイン
や dev-bypass セッションだけでは**不十分**——Personal Access Token(PAT、`ec_pat_*`)が必要になる。
公式のMCP Server Referenceには「Session cookies (from the admin UI) also work」と書かれているが、
このミドルウェアのバージョンには当てはまらない。

朗報としては、認証プロバイダーが設定されていない `localhost`/`127.0.0.1` 上であれば、
そのPATは素のHTTP呼び出しだけで自分で発行できる——ブラウザも人間によるOAuth承認も不要。

## このプロジェクトの`.mcp.json`にローカルコネクタが登録されている場合

リポジトリルートの `.mcp.json` を確認し、`http://127.0.0.1:4321`(またはそれに類する
loopback URL)を指すエントリを探す——慣例として `-local` サフィックスが付く。例:

```json
"emdash-site-local": {
  "type": "http",
  "url": "http://127.0.0.1:4321/_emdash/api/mcp",
  "headers": { "Authorization": "Bearer ${EMDASH_LOCAL_PAT}" }
}
```

`${EMDASH_LOCAL_PAT}` はClaude Codeの環境変数展開記法である——生のトークンは
このファイル(gitにコミットされる)には一切書き込まれない。この変数が設定済みで有効な
場合、MCPツールはネイティブに(`mcp__<entry-name>__*`として)表示される——curlは不要で、
そのまま使い始めてよい。

このプロジェクトの `.mcp.json` にまだそのようなエントリが存在しない場合、再接続すべき
対象は何もない——下記の手動curl手順をそのまま使うこと。

同じファイル内で `-local` サフィックスが**付いていない**他のエントリ(例: `emdash-site`)
は、このloopback devサーバーではなくデプロイ済み/本番URLである——触る前に下記の
「本番に対してこれを使わないこと」を参照すること。

**ローカルコネクタが見つからない・未認証・呼び出しが401になる場合**: 環境変数が
まだ設定されていない、あるいはそれが指すPATが失効している(例: `.wrangler/` が
削除された——下記の注記を参照)。対処法:

1. 下記のステップ1〜2で新しいPATを発行する。
2. Claude Codeが動いているシェル(または該当プロセスが環境変数を読む場所)で
   `export EMDASH_LOCAL_PAT=ec_pat_...` を実行する。
3. MCPサーバーを再接続する(例: `/mcp` で再接続、またはセッションを再起動)ことで
   新しい環境変数を反映させる——`.mcp.json` の変数展開はコネクタ確立時に行われ、
   呼び出しごとには行われない。

現在のコンテキストで再接続ができない場合は、下記のステップ3にフォールバックする
(`Authorization` ヘッダーにトークンを直接載せた素のcurl)——コネクタの登録方法に
関係なく動作する。

## 前提条件

- EmDashのdevサーバーが起動していること(このリポジトリでは `npx emdash dev`
  または `npm run dev`、デフォルトは `http://127.0.0.1:4321`)。
- devサーバーと同じマシン/サンドボックスから呼び出していること
  (`localhost` のみ——この手順全体はdev限定の抜け道であり、非ローカルの
  インスタンスに対しては一切機能しない)。

## 本番に対してこれを使わないこと

この手順全体は**ビルドされていないAstro devサーバー**(`pnpm dev` / `astro dev`)
に対してのみ機能する。emdashのソース `packages/core/src/astro/routes/api/setup/dev-bypass.ts`
のハンドラは最初にこのチェックを行う:

```ts
if (!import.meta.env.DEV) {
  return apiError("FORBIDDEN", "Dev bypass is only available in development mode", 403);
}
```

`import.meta.env.DEV` はビルド済み/デプロイ済みのインスタンス(Cloudflare Workers、
Pagesなど)ではコンパイル時に`false`へ除去される。そのため `/_emdash/api/setup/dev-bypass`
はホストに関わらず本番では**常に** `403 FORBIDDEN` を返す——同等の抜け道は存在せず、
このスキルは本番のMCPコネクタに対して提供できるものがない。

`.mcp.json` の `emdash-site` エントリ(`emdash-site-local` とは異なるデプロイ済みURL)
には、正規の方法で発行したPATが必要になる: 本番の管理パネルに実際にログインして
(パスキー/OAuthなど、そのサイトの `authProviders` に応じた方法で)
`/_emdash/admin/settings/api-tokens` でトークンを作成するか、
`emdash login --url https://<production-url>` を実行する(本物のOAuth Device
Flow——localhostの場合と異なり、人間がブラウザで承認する必要がある。localhostでは
`emdash login` が黙ってdev-bypassを使う)。このスキルの手順を本番URLに対して
再利用しようとしないこと——設計上、本番では通用しない。

## 手順

### 1. dev-bypassのセッションクッキーを取得する

```bash
curl -s -c /tmp/emdash-cookies.txt \
  "http://127.0.0.1:4321/_emdash/api/setup/dev-bypass?redirect=/_emdash/admin"
```

これはサイトに実際の認証プロバイダーが設定されておらず、かつリクエスト先が
loopbackアドレスである場合にのみ機能する——何の対話もなしにAdminロールの
セッション(`dev@emdash.local`、role 50)を発行する。`emdash login` が
`localhost` に対して自動的に行うのもこれと同じ処理である。

### 2. そのセッションを使ってREST API経由でPATを発行する

```bash
curl -s -b /tmp/emdash-cookies.txt \
  -H "Content-Type: application/json" \
  -H "X-EmDash-Request: 1" \
  -X POST http://127.0.0.1:4321/_emdash/api/admin/api-tokens \
  -d '{"name": "agent-local", "scopes": ["admin"]}'
```

- `X-EmDash-Request: 1` は状態を変更するセッション認証APIコールに必須である
  (軽量なCSRFガード——ブラウザはクロスオリジンでカスタムヘッダーを付けられないため、
  素の `curl` からこれを送るのは問題ない)。
- このエンドポイントはセッションユーザーがAdmin(role ≥ 50)であることを要求する——
  dev-bypassのセッションはすでにこれを満たしている。
- これはlocalhostの外に出ないため、細かいスコープ(`content:read`/`content:write`など)
  を列挙する代わりに `admin` スコープ(フルアクセス)をリクエストしてよい。
- レスポンスの `data.token`(`ec_pat_...`)は**一度だけ**表示される——必ず記録すること。
- 人間が手動でこれを行いたい場合、管理UI上の相当機能は
  `http://127.0.0.1:4321/_emdash/admin/settings/api-tokens` である。

### 3. そのトークンでMCPを呼び出す

```bash
curl -s \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer ec_pat_..." \
  -X POST http://127.0.0.1:4321/_emdash/api/mcp \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

任意のMCP JSON-RPC呼び出しに対して `method`/`params` を入れ替えればよい。例:
`{"method":"tools/call","params":{"name":"content_list","arguments":{"collection":"posts","limit":1}}}`

## 注記

- トンネルも外部コネクタもクロスバウンダリのネットワーキングも不要——これは
  devサーバーが動いているのと同じ環境からの、純粋なloopback HTTPである。
- 発行したPATは長期間有効であり、ここでは何も自動的に失効させない。片付けたい
  場合は `DELETE /_emdash/api/admin/api-tokens/:id`(作成レスポンスからトークンの
  `id` を得るか、同じセッションで `GET` して一覧取得する)で無効化できる——
  使い捨てのローカルサンドボックスであれば任意。
- devサーバーのローカル状態が消去された場合(例: ローカルのD1/SQLiteデータを
  保持する `.wrangler/` の削除)、以前発行したPATは動作しなくなる
  (`401 INVALID_TOKEN`——セッションだけでなくトークンの行自体が消えている)。
  その場合は単にステップ1〜2をやり直して新しいPATを発行すればよく、他に
  変えるべきことはない。

## ここから先は分岐する

- **プラグイン自身の設定を読む / 書く**(Block Kit の `/admin` ルート、`form_submit` / `block_action`)→ [`PLUGIN-SETTINGS.md`](PLUGIN-SETTINGS.md)
- **MCP が公開していない情報を直接SQLで読む**(`wrangler d1 execute`、テーブル種別、シークレットの扱い)→ [`D1-SQL.md`](D1-SQL.md)
