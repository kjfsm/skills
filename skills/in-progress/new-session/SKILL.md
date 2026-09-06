---
name: new-session
description: 別のリポジトリや別の作業のために、worktree と tmux で独立した新しいセッションを立ち上げる。
disable-model-invocation: true
argument-hint: "立ち上げたいリポジトリ(曖昧な呼び名でよい)"
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/new-session.sh *)
---

# 新しいセッションを立てる

機械的な列は同梱の [scripts/new-session.sh](scripts/new-session.sh) が持つ。ここに残るのは判断だけである。

## 1. どのリポジトリか

呼び名は曖昧なまま来る。`ls ~/github/*/` で解決し、**綴りは当てにしない** — 「akaszmplay」は `akszmplay`、「circle scheduler」は `circle-scheduler` だった。候補が複数に割れたら訊く。

## 2. 走らせる

```
bash ${CLAUDE_SKILL_DIR}/scripts/new-session.sh <リポジトリのパス> [セッション名]
```

origin の既定ブランチを fetch し、`-wt` を付けた worktree を detached で作り、gitignore された `.env*` と `.dev.vars*` を持ち込み、lockfile を見て依存を入れ、tmux で claude を起動する。セッション名も worktree のパスも、埋まっていれば連番でずらす。

**常に worktree を作る。** 本体のチェックアウトは触らない — 未コミットの変更を抱えていることがあり、1つの作業ツリーを2つのセッションが踏むと壊れる。「今はクリーンだから直接でよい」は成り立たない: 立てたセッションはこの先ずっと生き、本体はその間に汚れる。

秘匿ファイルの持ち込みが要るのは、それが gitignore されていて worktree に付いてこないからである。無いまま渡すと、最初に dev サーバーを起動した時点で落ちる。`.example` で終わるものは雛形なので持ち込まない。

## 3. 出力をそのまま渡す

attach のコマンド、持ち込んだファイル、撤去のコマンドが出る。ユーザーが次に打つのはこれである。

## ブランチは切らない

detached のまま置く。作業内容が決まってから、立てたセッション自身が `git switch -c` する。ここで切ると、**まだ知らない作業にブランチ名を付ける**ことになる。

## 片付け

```
tmux kill-session -t <セッション名>
git -C <リポジトリ> worktree remove <worktree のパス>
```

gitignore 済みのファイル(`.dev.vars`、`node_modules`)は dirty 扱いされないので、`worktree remove` は素通りする。止まるのは追跡ファイルに未コミットの変更が残っているときだけで、それは消してはいけない変更なので、止まるのが正しい。

## 組み込みの `EnterWorktree` ではない

あれは **いま走っているセッション自身** を worktree へ移すものである。こちらは今のセッションをその場に残したまま **もう一枚立てる**。並行して動かしたいならこちらで、秘匿ファイルのコピーと依存のインストールも向こうは行わない。
