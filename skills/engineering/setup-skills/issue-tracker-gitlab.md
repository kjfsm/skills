# イシュートラッカー: GitLab

このリポジトリのイシューとスペック(PRD)は GitLab の issue として存在する。すべての操作に [`glab`](https://gitlab.com/gitlab-org/cli) CLI を使う。

## 規約

- **イシューを作成する**: `glab issue create --title "..." --description "..."`。複数行の description には heredoc を使う。エディタを開くには `--description -` を渡す。
- **イシューを読む**: `glab issue view <number> --comments`。機械可読な出力には `-F json` を使う。
- **イシューを列挙する**: `glab issue list -F json` を、適切な `--label` フィルタとともに使う。
- **イシューにコメントする**: `glab issue note <number> --message "..."`。GitLab はコメントを「note」と呼ぶ。
- **ラベルを付ける/外す**: `glab issue update <number> --label "..."` / `--unlabel "..."`。複数のラベルはカンマ区切りか、フラグを繰り返すことで指定できる。
- **クローズする**: `glab issue close <number>`。`glab issue close` はクローズ時のコメントを受け付けないので、先に `glab issue note <number> --message "..."` で説明を投稿してからクローズする。
- **マージリクエスト**: GitLab は PR を「merge request」と呼ぶ。`glab mr create`、`glab mr view`、`glab mr note` などを使う — `gh pr ...` と同じ形で、`pr` の代わりに `mr`、`comment`/`--body` の代わりに `note`/`--message` を使う。

リポジトリは `git remote -v` から推定する — クローンの中で実行すると `glab` が自動的にこれを行う。

## トリアージの対象としてのマージリクエスト

**MR を要望の受け口として扱う: いいえ。** _(このリポジトリが外部のマージリクエストを機能要望として扱う場合は `yes` に設定する。`/triage` がこのフラグを読む。)_

`yes` に設定されている場合、MR は `glab mr` の相当コマンドを使い、イシューと同じラベルと状態で扱われる:

- **MR を読む**: `glab mr view <number> --comments`、差分は `glab mr diff <number>`。
- **トリアージ対象の外部 MR を列挙する**: `glab mr list -F json` を実行し、作者がプロジェクトのメンバー/オーナーではない MR(メンテナーの進行中の作業ではなく、コントリビューターの MR)だけを残す。
- **コメント/ラベル付け/クローズ**: `glab mr note`、`glab mr update --label`/`--unlabel`、`glab mr close`。

GitHub と異なり、GitLab は issue と MR を別々に採番するので、どちらの対象を指しているかメンテナーが分かっていれば `#42` は曖昧にならない。

## スキルが「イシュートラッカーへ公開する」と言うとき

GitLab の issue を作成する。

## スキルが「関連するチケットを取得する」と言うとき

`glab issue view <number> --comments` を実行する。

## Wayfinding 操作

`/wayfinder` が使う。**マップ** は単一の issue であり、チケットはその **子** issue である。

- **マップ**: `wayfinder:map` ラベルの付いた単一の issue で、Notes / Decisions-so-far / Fog の本文を保持する。`glab issue create --label wayfinder:map`。(ネイティブな epic を持つ GitLab のプランでは、代わりに epic がマップを保持してもよい。ラベル付きの issue はどのプランでも動作する。)
- **子チケット**: description の先頭に `Part of #<map>` を持ち、`wayfinder:<type>` ラベル(`research`/`prototype`/`grilling`/`task`)を持つ issue。引き受けられると、そのチケットはマップを進めている開発者に割り当てられる。
- **ブロッキング**: GitLab の **ネイティブなブロッキングリンク** — 正典であり、UI 上に可視化される表現。`/blocked_by #<n>` のクイックアクションを note として投稿して追加する(`glab issue note <child> --message "/blocked_by #<blocker>"`)。ネイティブなブロッキングリンクは Premium/Ultimate の機能である。無料プラン(または利用できない場合)では、description の先頭にある `Blocked by: #<n>, #<n>` の行にフォールバックする。すべてのブロッカーがクローズされると、そのチケットはブロック解除される。
- **フロンティアの問い合わせ**: マップの子に絞った `glab issue list -F json` を実行し、開いているブロッカーがある(開いている issue へのネイティブな `blocked_by` リンク(`glab api projects/:id/issues/:iid/links`)、あるいは `Blocked by` の行に開いている issue がある)ものや、担当者が付いているものを除外する。マップ上の順序が先のものが優先される。
- **引き受ける**: `glab issue update <n> --assignee @me` — そのセッションの最初の書き込み。
- **解決する**: `glab issue note <n> --message "<answer>"`、続けて `glab issue close <n>`、それからマップの Decisions-so-far にコンテキストポインタ(要点+リンク)を追記する。
