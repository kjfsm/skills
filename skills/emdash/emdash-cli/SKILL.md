---
name: emdash-cli
description: コンテンツ、スキーマ、メディアなどを管理するためにEmDash CLIを使用します。実行中のEmDashインスタンスとコマンドラインからやり取りする必要があるとき——コンテンツの作成、コレクションの管理、メディアのアップロード、型の生成、CMS操作のスクリプト化など——にこのスキルを使用してください。コマンドの一覧は公式ドキュメントにあり、このスキルはエージェントから使う際の挙動の差分を扱います。
---

# EmDash CLI

> **コマンドとフラグの一覧は公式にある。**
> [reference/cli](https://docs.emdashcms.com/reference/cli/) —— `dev` / `types` / `login` / `whoami` /
> `content` / `schema` / `media` / `search` / `taxonomy` / `menu` / `export-seed` / `secrets`、認証の
> 解決順序、共通フラグ、環境変数、終了コード。MCPサーバー(`https://docs.emdashcms.com/mcp`)を
> 接続していれば`search_docs`でも引ける。
>
> ここに書くのは、**公式に載っていない挙動**と、エージェントから叩くときに効いてくる差分だけ。

## エージェント向けに自動公開される

CLIは`create`と`update`でデフォルトで自動公開する。エージェントがドラフト/公開のライフサイクルを
管理しなくても、書いた直後に`get`で読み戻したときに自分の変更が見えるようにするため。

- **`create`** — 作成後に公開する。返るアイテムは`published`
- **`update`** — 更新する。コレクションがリビジョンを使っていてドラフトリビジョンが作られた場合は、
  自動的に公開してドラフトを昇格させる
- **`get`** — 保留中のドラフトがあれば(例: 誰かが管理UIで編集して未公開のまま)、公開済みデータでは
  なく**ドラフトデータ**を返す

自動公開を止めるにはcreate/updateで`--draft`。

## `content get --published`(公式に記載なし)

上記のドラフト優先を打ち消して、公開済みデータだけを見るためのフラグ。公式のCLIリファレンスには
`--raw`しか載っていないが、`--published`も実在する。

```bash
npx emdash content get posts 01ABC123               # ドラフトがあればドラフトを返す
npx emdash content get posts 01ABC123 --published   # 公開済みデータのみ
npx emdash content get posts 01ABC123 --raw         # Portable Text→markdown変換をスキップ
```

## `--rev`は`update`だけの要求

`update`は`get`で得た`_rev`トークンを要求する(楽観的並行性制御。読まずに上書きさせないための仕組み)。
それ以外のコマンドは冪等か非破壊なので不要。

| コマンド            | `--rev`  | 理由                         |
| ------------------- | -------- | ---------------------------- |
| `content create`    | 不要     | まだ何も存在しないため       |
| `content update`    | **必要** | 既存データを上書きするため   |
| `content delete`    | 不要     | ソフトデリートで戻せるため   |
| `content publish`   | 不要     | 冪等なステータス変更         |
| `content unpublish` | 不要     | 冪等なステータス変更         |
| `content schedule`  | 不要     | メタデータのみを変更するため |
| `content restore`   | 不要     | ゴミ箱から復元するため       |

競合すると`409 CONFLICT`が返る。`get`で読み直し、新しい`_rev`で`update`し直す。

## 型生成はdevサーバー再起動のほうが早い

`emdash types`の出力先は`.emdash/types.ts`で、Astroの`tsconfig.json`がincludeしている
`emdash-env.d.ts`は**更新されない**。後者はEmDashインテグレーションがdevサーバー起動時に生成する。
詳細は`building-emdash-site`スキルの`references/configuration.md`(取り込んでいれば
`.agents/skills/building-emdash-site/references/configuration.md`)。

## 編集フロー

Portable Text ⇄ markdownの自動変換、未知ブロックの扱い、rawモードは
**[EDITING-FLOW.md](./EDITING-FLOW.md)** を参照(公式ドキュメントには書かれていない)。
