# プラグイン自身の設定を読み書きする

コアMCPが公開していない、**そのプラグイン自身の設定**に手を伸ばすときに開く。
前提は `SKILL.md` の手順2で発行した Bearer PAT である。

## プラグイン設定の読み取り(MCPでは公開されていない)

コアMCPサーバーのツール(`content_*`、`schema_*`、`settings_*`、
`media_*`、`menu_*`、`taxonomy_*`、`revision_*`、`search`)はemdashコアに
固定でハードコードされており、特定プラグイン自身の設定を読むためのツールは
存在しない。それを読むには、上記ステップ2のBearer PATを使ってプラグインの
Block Kit管理ルートを直接呼び出す:

```bash
curl -s \
  -H "Authorization: Bearer ec_pat_..." \
  http://127.0.0.1:4321/_emdash/api/plugins/<plugin-id>/admin
```

これは管理ページの現在のBlock Kit JSONを返す(フィールドの値は保存済みの設定を
反映するが、`secret_input` フィールドは実際の値を一切返さない——locale、
ドロップダウンの選択状態、算出済みのステータス文言といった非シークレットな
状態のみ)。URLパスは、プラグインのmanifestが `admin.pages[].path` で
何を宣言していても常に `/admin` である(そのpathはWeb UI上のサイドバーリンクに
のみ使われる)。

このルートはセッションクッキーで呼ぶ場合は通常 `X-EmDash-Request: 1` という
CSRFヘッダーを要求する点に注意——だがBearerトークン認証のリクエストはこの
チェックを完全にスキップする(トークンはクッキーのような環境依存の資格情報では
ないため)ので、ここでは追加のヘッダーは不要である。

## プラグイン設定の書き込み(Block Kitの`form_submit` / `block_action`)

同じ `/admin` ルートは状態を変更するインタラクションも受け付ける——素の
`GET` は暗黙的に `page_load` を送信したことになる。フォームを送信したり
ボタンをクリックしたりするには、プラグインのルートハンドラが期待する
`BlockInteraction` の形をしたJSONボディを `POST` する:

```bash
curl -s \
  -H "Authorization: Bearer ec_pat_..." \
  -H "Content-Type: application/json" \
  -X POST http://127.0.0.1:4321/_emdash/api/plugins/<plugin-id>/admin \
  -d '{"type":"form_submit","action_id":"<フォームブロックのsubmit.action_id>","values":{"<フィールドのaction_id>":"<値>", ...}}'
```

- フォームの送信ボタンなら `type` は `"form_submit"`、単体のボタン
  (フォームを持たない「Fetch」アクションなど)なら `"block_action"` になる。
- `action_id` は*直前の* `page_load`/レスポンスにあった `submit.action_id`
  (フォームの場合)またはボタン自身の `action_id`(block_actionの場合)と
  一致していなければならない——action_idは動的な場合がある(既存行を編集する
  `save_mapping_0` と、新規追加する `save_mapping_new` のように)ので、
  不明な場合は先に再度 `GET` して確認すること。
- `values` のキーはフォームフィールド自身の `action_id` であり、ラベルではない。
- レスポンスは再レンダリングされたブロックツリー全体と、任意で
  `data.toast: {message, type}` を返す——`toast.type === "success"` を確認する
  (または `banner`/`stats` ブロックを読む)ことで、そのアクションが実際に
  何かを行ったか確認すること。不正な形のリクエストでも、エラーなしに
  *変化のない*ページがそのまま `200` で返ってくることが多いため。
- `X-EmDash-Request` ヘッダーは不要(Bearer認証がこのCSRFチェックを
  スキップする)。
- プラグインが期待する正確なaction_idと値の形を推測せずに知るには、
  インストール済みのソースを読むこと——sandboxedプラグインはバンドル済みの
  `dist/plugin.mjs` を `node_modules/.pnpm/<pkg>@<version>_.../node_modules/<pkg>/dist/plugin.mjs`
  以下に同梱している(`realpath node_modules/<scope>/<pkg>` で実体パスを
  解決すること、pnpmは別の場所にシンボリックリンクしている)。minifyされているが、
  `grep`/`python3 -c` でaction_idの文字列リテラル(例: `save_mapping_`)を
  検索すれば、そのハンドラの分岐と `values` から読み取っている正確なキーが
  見つかる。

> **注意**: 状態変更のPOSTボディをヘルパーのサブプロセス(例: `node -e ...`)で
> 組み立てる場合、素の `source .env` は不十分——`export` の付かない `KEY=value` 行は
> シェルローカル変数を設定するだけで子プロセスからは見えず、`JSON.stringify` が
> `undefined` フィールドを黙って省略した結果、リクエストは(200・エラーなしで)
> 「成功」したように見えて実際には何も保存されない。`set -a; source .env; set +a` を
> 使い、送信前にペイロードへ期待値が入っているか目視確認すること。
