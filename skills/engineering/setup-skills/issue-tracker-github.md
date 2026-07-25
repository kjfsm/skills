# イシュートラッカー: GitHub

このリポジトリのイシューとスペック(PRD)は GitHub の issue として存在する。すべての操作に `gh` CLI を使う。

## 規約

- **イシューを作成する**: `gh issue create --title "..." --body "..."`。複数行の本文には heredoc を使う。
- **イシューを読む**: `gh issue view <number> --comments`。コメントは `jq` でフィルタし、ラベルも取得する。
- **イシューを列挙する**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` を、適切な `--label` と `--state` フィルタとともに使う。
- **イシューにコメントする**: `gh issue comment <number> --body "..."`
- **ラベルを付ける/外す**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **クローズする**: `gh issue close <number> --comment "..."`

リポジトリは `git remote -v` から推定する — クローンの中で実行すると `gh` が自動的にこれを行う。

## トリアージの対象としてのプルリクエスト

**PR を要望の受け口として扱う: いいえ。** _(このリポジトリが外部の PR を機能要望として扱う場合は `yes` に設定する。`/triage` がこのフラグを読む。)_

`yes` に設定されている場合、PR は `gh pr` の相当コマンドを使い、イシューと同じラベルと状態で扱われる:

- **PR を読む**: `gh pr view <number> --comments`、差分は `gh pr diff <number>`。
- **トリアージ対象の外部 PR を列挙する**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` を実行し、`authorAssociation` が `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` のものだけを残す(`OWNER`/`MEMBER`/`COLLABORATOR` は除外する)。
- **コメント/ラベル付け/クローズ**: `gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub は issue と PR で番号空間を共有しているので、裸の `#42` はどちらの可能性もある — `gh pr view 42` で解決を試み、失敗したら `gh issue view 42` にフォールバックする。

## スキルが「イシュートラッカーへ公開する」と言うとき

GitHub の issue を作成する。

## スキルが「関連するチケットを取得する」と言うとき

`gh issue view <number> --comments` を実行する。

## Wayfinding 操作

`/wayfinder` が使う。**マップ** は単一の issue であり、チケットはその **子** issue である。

- **マップ**: `wayfinder:map` ラベルの付いた単一の issue で、Notes / Decisions-so-far / Fog の本文を保持する。`gh issue create --label wayfinder:map`。
- **子チケット**: GitHub のサブイシュー(sub-issues エンドポイントへの `gh api`)としてマップにリンクされた issue。サブイシューが有効になっていない場合は、マップ本文のタスクリストに子を追加し、子の本文の先頭に `Part of #<map>` を置く。ラベル: `wayfinder:<type>`(`research`/`prototype`/`grilling`/`task`)。引き受けられると、そのチケットはマップを進めている開発者に割り当てられる。
- **ブロッキング**: GitHub の **ネイティブなイシュー依存関係** — 正典であり、UI 上に可視化される表現。`gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` でエッジを追加する。`<blocker-db-id>` はブロッカーの数値の **データベース id**(`gh api repos/<owner>/<repo>/issues/<n> --jq .id`。`#number` や `node_id` では _ない_)。GitHub は `issue_dependencies_summary.blocked_by`(開いているブロッカーのみ — その場でのゲート)を報告する。dependencies が使えない場合は、子の本文の先頭にある `Blocked by: #<n>, #<n>` の行にフォールバックする。すべてのブロッカーがクローズされると、そのチケットはブロック解除される。
- **フロンティアの問い合わせ**: マップの開いている子(`gh issue list --state open` を、マップのサブイシュー/タスクリストに絞って)を列挙し、開いているブロッカーがある(`issue_dependencies_summary.blocked_by > 0`、あるいは `Blocked by` の行に開いている issue がある)ものや、担当者が付いているものを除外する。マップ上の順序が先のものが優先される。
- **引き受ける**: `gh issue edit <n> --add-assignee @me` — そのセッションの最初の書き込み。
- **解決する**: `gh issue comment <n> --body "<answer>"`、続けて `gh issue close <n>`、それからマップの Decisions-so-far にコンテキストポインタ(要点+リンク)を追記する。
