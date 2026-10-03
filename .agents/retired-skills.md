# 退役したスキル

退役したスキルは削除する(本家と同じ方針)。本文は git 履歴にある。ここに残すのは **なぜ退役したかと、代わりに使うもの** だけである — 書かないと、同じものをもう一度作る。

## 自作・本家から離れていたもの

- **batch-grill-me** — ラウンド単位で設計ツリーを進めるインタビュー。中身は本家の `grilling` に取り込まれた。
- **design-an-interface** — 並列サブエージェントで根本的に異なるインターフェース案を出す。本家 `codebase-design` の DESIGN-IT-TWICE が同じことをする。
- **new-session**(と、それが呼んでいた `session-launcher` エージェント) — worktree つきのバックグラウンドセッションを立て、状態と画面を読んで報告する。立てるのは公式の `claude --bg --name <名前> "<最初の入力>"` の1行で、worktree への隔離はセッションが自分で行い、状態はユーザーが `claude agents`(agent view)の行で見る。実装セッションに固有の部分(最初の入力、Stack の worktree、全文が届いたかの確認)は `launch-implementation-session` が持つ。
- **restart-session** — バックグラウンドセッションを `claude respawn` で立て直し、状態を読んで報告する。自分自身なら別のセッションに頼む。公式の `claude respawn <id>` がそのまま同じことをする — 会話・ID・worktree を残し、走っていたバックグラウンドのシェルコマンドも次のプロセスへ引き継ぐ。自分自身を立て直すときも、ユーザーがシェルで同じ1行を叩けばよい。
- **qa** — 会話で報告されたバグを GitHub イシューにする対話セッション。本家の `triage` を使う。
- **request-refactor-plan** — インタビューから小さなコミット単位のリファクタ計画を作る。本家の `to-spec` → `to-tickets` を使う。
- **setup-pre-commit** — husky + lint-staged の pre-commit を敷く。git hook の層は `/kjfsm-skills:setup-hooks` が持ち、lefthook を既定に pre-commit を1秒未満に保つ — このスキルはどちらの判断とも逆を敷いていた。
- **ubiquitous-language** — 会話から DDD のユビキタス言語の用語集を抽出する。本家の `domain-modeling` が `CONTEXT.md` を保守する。
- **create-tests / rebuild-tests / react-router-worker-tests** — 冒頭が互いの違いの説明で、呼ぶ側はクラスタ全体を知らないと1本を選べず、「壊して確かめる」などが重複していた。`/kjfsm-skills:workers-tests` に統合し、状況ごとの参照ファイル(START / REBUILD / SSR)に分けた。
- **help-skills** — README の一覧の URL を1行返すだけで、interface と中身が同じ大きさだった。`/kjfsm-skills:ask-kjfsm` の冒頭が URL を持つ。

## 本家の写しだったもの(2026-09-23)

訳の配布をやめた(→ [ADR 0006](./adr/0006-depend-on-upstream-ship-translation-separately.md))あとに `misc/` と `in-progress/` に残っていた、本家に同名で存在するスキル。どのプラグインも配らず、検査と `.claude/skills/` の二重表示のコストだけを払っていた。使うなら本家から入れる — `wizard`・`to-questionnaire` は `mattpocock-skills` プラグインが配り、残りは `npx skills add mattpocock/skills --skill <名前>` で届く。

`claude-handoff`、`loop-me`、`setup-ts-deep-modules`、`to-questionnaire`、`wizard`、`writing-beats`、`writing-fragments`、`writing-shape`、`git-guardrails-claude-code`、`migrate-to-shoehorn`、`scaffold-exercises`

## 本家の訳が残っていたもの(2026-09-28)

- **edit-article** — 記事をセクションに分けて書き直す。本家 `personal/edit-article` の訳が1行違いで残っていた。本家も使わないスキルとして削除済み(`c66bdee`)で、代わりは無い。
