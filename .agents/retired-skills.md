# 退役したスキル

退役したスキルは削除する(本家と同じ方針)。本文は git 履歴にある。ここに残すのは **なぜ退役したかと、代わりに使うもの** だけである — 書かないと、同じものをもう一度作る。

## 自作・本家から離れていたもの

- **batch-grill-me** — ラウンド単位で設計ツリーを進めるインタビュー。中身は本家の `grilling` に取り込まれた。
- **design-an-interface** — 並列サブエージェントで根本的に異なるインターフェース案を出す。本家 `codebase-design` の DESIGN-IT-TWICE が同じことをする。
- **new-session** — worktree と tmux で独立したセッションを立てる。Claude Code の `claude -w <名前> --tmux` が同じことをする。
- **qa** — 会話で報告されたバグを GitHub イシューにする対話セッション。本家の `triage` を使う。
- **request-refactor-plan** — インタビューから小さなコミット単位のリファクタ計画を作る。本家の `to-spec` → `to-tickets` を使う。
- **setup-pre-commit** — husky + lint-staged の pre-commit を敷く。git hook の層は `/kjfsm-skills:setup-hooks` が持ち、lefthook を既定に pre-commit を1秒未満に保つ — このスキルはどちらの判断とも逆を敷いていた。
- **ubiquitous-language** — 会話から DDD のユビキタス言語の用語集を抽出する。本家の `domain-modeling` が `CONTEXT.md` を保守する。
- **help-skills** — README の一覧の URL を1行返すだけで、interface と中身が同じ大きさだった。`/kjfsm-skills:ask-kjfsm` の冒頭が URL を持つ。

## 本家の写しだったもの(2026-09-23)

訳の配布をやめた(→ [ADR 0006](./adr/0006-depend-on-upstream-ship-translation-separately.md))あとに `misc/` と `in-progress/` に残っていた、本家に同名で存在するスキル。どのプラグインも配らず、検査と `.claude/skills/` の二重表示のコストだけを払っていた。使うなら本家から入れる — `wizard`・`to-questionnaire` は `mattpocock-skills` プラグインが配り、残りは `npx skills add mattpocock/skills --skill <名前>` で届く。

`claude-handoff`、`loop-me`、`setup-ts-deep-modules`、`to-questionnaire`、`wizard`、`writing-beats`、`writing-fragments`、`writing-shape`、`git-guardrails-claude-code`、`migrate-to-shoehorn`、`scaffold-exercises`
