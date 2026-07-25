# イシュートラッカー: ローカル Markdown

このリポジトリのイシューとスペック(PRD として知られているかもしれない)は、`.scratch/` 内のマークダウンファイルとして存在する。

## 規約

- 機能ごとに1ディレクトリ: `.scratch/<feature-slug>/`
- スペックは `.scratch/<feature-slug>/spec.md`
- 実装イシューはチケットごとに1ファイル、`.scratch/<feature-slug>/issues/<NN>-<slug>.md` に `01` から番号を振る — まとめた1つのチケットファイルは決して使わない
- トリアージの状態は各イシューファイルの先頭近くにある `Status:` 行に記録する(ロール文字列は `triage-labels.md` を参照)
- コメントと会話の履歴は、ファイルの末尾にある `## Comments` の見出しの下に追記する

## スキルが「イシュートラッカーへ公開する」と言うとき

`.scratch/<feature-slug>/` 配下に新しいファイルを作成する(必要ならディレクトリも作成する)。

## スキルが「関連するチケットを取得する」と言うとき

参照されたパスのファイルを読む。ユーザーは通常、パスかイシュー番号を直接渡す。

## Wayfinding 操作

`/wayfinder` が使う。**マップ** はファイルであり、チケットごとに1つの **子** ファイルを持つ。

- **マップ**: `.scratch/<effort>/map.md` — Notes / Decisions-so-far / Fog の本文。
- **子チケット**: `.scratch/<effort>/issues/NN-<slug>.md` に `01` から番号を振り、本文に問いを書く。`Type:` 行がチケットの種類(`research`/`prototype`/`grilling`/`task`)を、`Status:` 行が `claimed`/`resolved` を記録する。
- **ブロッキング**: 先頭近くにある `Blocked by: NN, NN` の行。そこに列挙されたすべてのファイルが `resolved` になると、そのチケットはブロック解除される。
- **フロンティア**: `.scratch/<effort>/issues/` を走査し、開いていて、ブロックされておらず、まだ誰にも引き受けられていないファイルを探す。番号が若いものが優先される。
- **引き受ける**: 作業を始める前に `Status: claimed` を設定して保存する。
- **解決する**: `## Answer` の見出しの下に答えを追記し、`Status: resolved` を設定し、それから `map.md` のマップの Decisions-so-far にコンテキストポインタ(要点+リンク)を追記する。
