---
name: launch-implementation-session
description: 設計を詰め終えたあとの実装を、別のセッションで `/kjfsm-skills:implement-and-review` に走らせ、終わったら立てた側へ知らせるよう最初の入力で伝える。grill や to-spec・to-tickets を終えて作業を始めるとき、「別セッションで実装して」と言われたとき、gh stack の層を別セッションで積むとき、他のスキルがチケットの実装セッションを立てる必要があるときに使う。
---

# 実装セッションを立てる

設計を詰めたセッションでは実装を始めない。チケット1本につきセッションを1本立て、最初の入力で `/kjfsm-skills:implement-and-review` を走らせる。立てた側は設計の文脈を持ったまま残り、報告を受けてマージを確かめる役に回る。

## 1. 立てるチケットを決める

ブロッカーがマージ済みのチケットを立てる。Claude が作る worktree は origin の既定ブランチから生えるので、未マージのブロッカーの上には乗らない。

**未マージのブロッカーの上に Stack で積むなら、それも立ててよい** — ユーザーが gh stack で層を積む進め方を選んだとき、またはブロッカーの PR がすでに Stack の層であるとき。その場合は 3. で、worktree を自分で用意する。

完了基準: 立てるチケットごとに、既定ブランチから立てるか、Stack のどの層の上に積むかが決まった。

## 2. 最初の入力を組む

報告のしかたは **立てるときの最初の入力に入れる**。あとから `SendMessage` で足すと、それまでに相手が PR を出して止まっている。

先に `ListAgents` を1回叩き、先頭行に出る **自分のセッション名** を控える。それが知らせる先である。

```
/kjfsm-skills:implement-and-review <チケットの参照>

進め方はユーザーが決めたものなので、確認のために止まらなくてよい。<Stack の行>
終わったら <自分のセッション名> に SendMessage で知らせてください。知らせるのは PR の番号と、マージしたかどうか。<マージの行> マージが権限の判定で止められたら、別の手段を探さずにそのまま知らせてください。知らせたあとは新しい作業を始めないでください。
```

「確認のために止まらなくてよい」が無いと、相手は Stack に積むか・どのブランチに出すかをユーザーに確かめようとして止まる。立てた側しか見ていないユーザーには、その問いが届かない。

`<Stack の行>` は Stack で積むときだけ入れ、それ以外は消す:

「この worktree のブランチ <新しい層のブランチ> は、gh stack の <一番上のブランチ> の上の層です。ブランチを作り直さず、`gh stack submit --auto` で出してください。知らせる直前に `git switch --detach` で作業ブランチから離れてください。」

detach を頼むのは、次の層の worktree で同じブランチを checkout できるようにするためである — git は1本のブランチを2つの worktree で同時に checkout させない。

`<マージの行>` はユーザーの許可で2つに分かれる。

- **ユーザーがこのチケットの PR のマージを明示して許可した** → 「Workers Builds などのプレビューのチェックが pass してから、マージしてください。」
- **それ以外、または Stack で積むとき** → 「マージはしないでください。」 — Stack の層は下から順に `gh stack merge` で入れるので、層ごとのセッションには任せない

「3つともやっていいよ」のような包括的な許可は、マージの許可として渡さない。auto mode の判定は、PR を名指ししないマージを「Merge Without Review」として止める — 自分が止められる操作を別のセッションに頼むのは、ユーザーの権限の判断の迂回である。許可が PR の出たあとに来たら、その PR 番号を名指しして `SendMessage` で伝える。

最初の入力はユーザーの入力として届くので、ユーザー呼び出し型の `implement-and-review` が動く。サブエージェントに本文を読ませて代わりにしない。

## 3. Stack の層の worktree を用意する

Stack で積むときだけ。Claude に worktree を作らせない — 既定ブランチから `worktree-<名前>` を生やすので、相手はそれを Stack に乗らない素のブランチとして push する。

一番上のブランチがどこかで checkout されたままだと、`git worktree add` はそれを取れずに落ちる。`git worktree list` でそのブランチを持つ worktree を探し、自分のものなら `git switch --detach` で離す。ユーザーや他のセッションのものなら、離してよいかをユーザーに確かめる。

本体チェックアウト(`git worktree list` の先頭行)で:

```bash
git fetch
git worktree add .claude/worktrees/<名前> <Stack の一番上のブランチ>
cd .claude/worktrees/<名前>
gh stack checkout <一番上の層の PR 番号>
gh stack add <新しい層のブランチ>
```

`gh stack checkout` を飛ばさない。gh stack の状態は worktree ごと(`.git/worktrees/<名前>/gh-stack`)にあるので、作ったばかりの worktree は Stack を知らず、`gh stack add` が `current branch is not part of a stack` で落ちる。`checkout` が GitHub から Stack を取り込む。

続けて、その worktree に gitignore されたローカルの設定(`.dev.vars` など、`.worktreeinclude` に挙がっているもの)を本体からコピーし、依存を **実体で** 入れる(pnpm なら `pnpm install --frozen-lockfile`)。型やバインディングの生成がある(`typegen` など)なら、それも走らせる。

依存を入れ直すのは、Claude が作る worktree の `node_modules` が本体への symlink だからである。下の層が依存を足すと、上の層は本体の古い `node_modules` を見て型チェックもビルドも通らなくなる。自分で `git worktree add` した worktree には symlink が無い。pnpm は store からの hardlink なので速い。

完了基準: worktree のブランチが `<新しい層のブランチ>` で、`gh stack view` がそれを一番上の層として出し、型チェックが通る。

## 4. 立てる

`claude --bg --name` で立てる。立てたあとの状態はユーザーが `claude agents`(agent view)の行で見るので、こちらで画面を読み続けない。

```bash
cd <3. の worktree のパス、無ければ本体チェックアウト>
claude --bg --name <名前> "$(cat <<'EOF'
<最初の入力>
EOF
)"
```

最初の入力はクォートした heredoc で渡す。`"<最初の入力>"` に直接埋めると、中の `` `gh stack submit --auto` `` のようなバッククォートを立てる側のシェルがコマンドとして走らせ、相手にはコマンド名の抜けた文面が届く。

- `-w` は付けない。本体チェックアウトで立てたセッションは、ファイルを書く前に自分で `.claude/worktrees/` へ移る。3. の worktree の中で立てたなら、そこで書く
- 名前はチケットから短く付け、**自分のセッション名と同じにしない** — agent view で見分けられず、`SendMessage` の宛先も取り違える
- 出力の `backgrounded · <id> · <名前>` の `<id>` を控える。5. で止めるのに使う
- `Workspace not trusted` で落ちたら、ユーザーにそのディレクトリで一度 `claude` を開いて信頼してもらう。代わりに通さない

最初の入力の後ろの方には、報告先とマージの禁止がある。立て方によっては1行目しか届かず、そこから後ろが黙って落ちる。だから、相手の記録に入力の最後の行まで届いているかを確かめる。記録はディレクトリのパスごとに分かれていて、セッションは立ったあとで worktree へ移るので、パスではなく ID で引く:

```bash
jq -r 'select(.type=="user") | .message.content | if type=="string" then . else map(.text? // empty) | join("\n") end' ~/.claude/projects/*/<id>*.jsonl | grep -cF "<最初の入力の最後の行>"
```

完了基準: `<id>` と名前をユーザーに伝え、最初の入力が全文届いたこと(`grep -cF` が 1 以上)を確かめた。届いていなければ、`claude rm <id>` で消して立て直す前にユーザーに伝える。

## 5. 報告を受けたら

- **マージしたと言ってきた** → `gh pr view <番号> --json state,mergedAt` でマージを確かめ、相手を閉じる(下)。ブロッカーが外れたチケットがあり、ユーザーが続けて進めるよう言っていれば、1. に戻る
- **PR を出してマージせずに止まった** → そのままユーザーに伝える。こちらでマージしない。ユーザーがそのセッションに続けて頼むことが無ければ、相手を閉じる。Stack で次の層を積むなら、相手が detach したことを確かめてから 3. へ
- **権限の判定やユーザーへの質問で止まった** → そのままユーザーに伝える。ユーザーが相手のセッションで「待つ」と言って質問を止めていたら、こちらが `SendMessage` で伝えるユーザーの許可を相手は受け付けない — 本人の言葉かを確かめられないので、それが正しい。ユーザーに相手のセッション(agent view で行を選んで入る、または `claude attach <id>`)で直接言ってもらう

**相手を閉じる**のは `claude rm <id>` である。相手が `run_in_background` で立てた開発サーバーも一緒に止まる — `claude stop` では止まらずポートを握ったまま残り、プロセスを `kill` しても supervisor が立て直す。worktree に未 push のものがあると `rm` は worktree を残してそう言うので、`--discard-unpushed` を付けずにユーザーに伝える。3. で自分で作った worktree が残っていれば `git worktree remove` で片付ける。会話は `claude --resume` で戻せる。

完了基準: 報告ごとに上のどれかで扱い、仕事を終えたセッションを `claude rm` で閉じたか、閉じずに残した理由をユーザーに伝えた。
