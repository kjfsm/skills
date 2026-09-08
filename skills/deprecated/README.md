# Deprecated

もう使っていないスキル。

- **[batch-grill-me](./batch-grill-me/SKILL.md)** — ラウンド単位で設計ツリーを進めるインタビュー。中身は `grilling` 本体に取り込まれたので、別スキルとしては不要になった。
- **[design-an-interface](./design-an-interface/SKILL.md)** — 並列サブエージェントを使い、モジュールに対して根本的に異なる複数のインターフェース設計を生成する。
- **[new-session](./new-session/SKILL.md)** — worktree と tmux で独立したセッションを立ち上げる。Claude Code の `--worktree` / `--tmux` が同じことをするようになったので、手製の `-wt` サイブリングと tmux 起動は残すと組み込みから逸れる方へ誘導する。
- **[qa](./qa/SKILL.md)** — ユーザーが会話形式でバグを報告し、エージェントが GitHub イシューを作成するインタラクティブな QA セッション。
- **[request-refactor-plan](./request-refactor-plan/SKILL.md)** — ユーザーへのインタビューを通じて小さなコミット単位のリファクタ計画を作成し、GitHub イシューとして登録する。
- **[ubiquitous-language](./ubiquitous-language/SKILL.md)** — 現在の会話から DDD スタイルのユビキタス言語グロッサリーを抽出する。
