---
name: new-session
description: 【退役】worktree と tmux でセッションを立てる。Claude Code の `--worktree` と `--tmux` に置き換わった。
disable-model-invocation: true
argument-hint: "立ち上げたいリポジトリ(曖昧な呼び名でよい)"
allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/new-session.sh *), Bash(bash ${CLAUDE_SKILL_DIR}/scripts/resumable.sh *)
---

# 新しいセッションを立てる

> **退役。使わないこと。** 下の手順は Claude Code v2.1.263 の組み込みに置き換わった。
>
> ```bash
> cd <リポジトリ>
> claude -w <名前> --tmux=classic
> ```
>
> これが worktree を `.claude/worktrees/<名前>/` に作り、origin の既定ブランチから
> 生やし、`.worktreeinclude` にある gitignore されたファイルを持ち込み、tmux
> セッションを立て、終了時に残すか消すかを訊く。リポジトリ直下に置かれるので
> フォルダの信頼プロンプトも踏まない — 下の §4 が対処していた症状は起きない。
>
> 下に残っている `-wt` サイブリングと手製の tmux 起動は、そのどれとも噛み合わない。

機械的な列は同梱の [scripts/new-session.sh](scripts/new-session.sh) が持つ。ここに残るのは判断だけである。

## 1. どのリポジトリか

呼び名は曖昧なまま来る。`ls ~/github/*/` で解決し、**綴りは当てにしない** — 「akaszmplay」は `akszmplay`、「circle scheduler」は `circle-scheduler` だった。候補が複数に割れたら訊く。

`allowed-tools` の免除は呼び出したターンだけ効く。ここで訊き返すと、ユーザーが答えた次のターンでは切れているので、スクリプトは権限プロンプトを通る。

## 2. 立てるのか、戻すのか

**Windows や WSL の再起動は tmux セッションを丸ごと消すが、worktree と未コミットの編集はディスクに残る。** そこへこのスキルを素直に適用すると、作業の続きがある worktree の隣に空の worktree をもう1つ生やす。

だから作る前に、そのリポジトリに戻り先が無いかを見る。

```
bash ${CLAUDE_SKILL_DIR}/scripts/resumable.sh <リポジトリのパス>
```

上から順に読む。

- **`TMUX` に名前がある** — セッションはまだ生きている。何も作らず `tmux attach -t <名前>` を渡して終わり。
- **`KIND` が `wt` の行で `DIRTY` か `AHEAD` が 0 でない、または `LAST TALK` が新しい** — 続きのある作業である。ユーザーが再開のつもりなら、新しく作らずそこへ戻す。
- **`KIND` が `main` の行**は本体のチェックアウトで、大抵 dirty か ahead である。ここでは判定材料にしない — 本体は §3 でも触らない。

`AHEAD` は上流(無ければ既定ブランチ)より先にあるコミット数で、`?` は「先行している」ではなく **比較する基準が無い**(origin/HEAD 未設定)である。これも判定材料にしない。

```
tmux new-session -d -s <セッション名> -c <worktree のパス> 'claude --continue'
```

`--continue` はそのディレクトリの直近の会話を開く。履歴を選ばせるなら `--resume`。**どちらもディレクトリ基準**なので、`-c` を間違えると別の履歴が開く。

新しい作業を始めるのだと分かっているとき、そして戻り先が1つも無いときだけ、下へ進む。

戻せるのは worktree が残っている場合に限る。撤去済みの worktree の会話ログはファイルとしては残っているが、作業ツリーが無いので読み物にしかならない。

## 3. 走らせる

```
bash ${CLAUDE_SKILL_DIR}/scripts/new-session.sh <リポジトリのパス> [セッション名]
```

origin の既定ブランチを fetch し、`-wt` を付けた worktree を detached で作り、gitignore された `.env*` と `.dev.vars*` を(下層のものも含めて)持ち込み、lockfile を見て依存を入れ、tmux で claude を起動する。セッション名も worktree のパスも、埋まっていれば連番でずらす。

**常に worktree を作る。** 本体のチェックアウトは触らない — 未コミットの変更を抱えていることがあり、1つの作業ツリーを2つのセッションが踏むと壊れる。「今はクリーンだから直接でよい」は成り立たない: 立てたセッションはこの先ずっと生き、本体はその間に汚れる。

秘匿ファイルの持ち込みが要るのは、それが gitignore されていて worktree に付いてこないからである。無いまま渡すと、最初に dev サーバーを起動した時点で落ちる。`.example` で終わるものは雛形なので持ち込まない。

## 4. 最初の画面まで見て報告する

**立ち上げた claude が何を映しているかを必ず伝える。** スクリプトは tmux セッションを作ったあと最初の画面を読み、`state:` に判定を、その下に画面の末尾を出す。プロセスが起きたことと、働き始めたことは別である。

- `READY` — 入力欄が出ている。attach のコマンドを渡して終わり。
- `BLOCKED` — **人間が 1 キー押すまで、そのセッションは何もしない。** 何を訊かれているかと、attach のコマンドを伝える。ラベルが付いていない BLOCKED は、下に出ている画面をそのまま読んで伝える。
- `UNKNOWN` — 画面を読めなかった。READY と言い換えない。

worktree は毎回新しいパスなので、**初回起動はほぼ必ず何かのプロンプトで止まる** — フォルダの信頼、そのリポジトリで初めて見る MCP サーバーの有効化。どれも人間に向けた安全ゲートなので、`tmux send-keys` で代わりに答えない — 立てた本人ではない誰かが、見ていないものを許可したことになる。

複数立てたなら、どれが `BLOCKED` でどれが `READY` かを並べて渡す。ユーザーが次に attach するのは止まっている方である。

そのうえで、持ち込んだファイルと撤去のコマンドを添える。

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
