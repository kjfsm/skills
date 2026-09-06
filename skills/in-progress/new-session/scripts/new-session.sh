#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: new-session.sh <repo-path> [session-name]" >&2
  exit 64
}

[ $# -ge 1 ] || usage
repo=$(cd "$1" 2>/dev/null && pwd) || { echo "no such directory: $1" >&2; exit 66; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 66; }
command -v tmux >/dev/null || { echo "tmux not found" >&2; exit 69; }

base=${2:-$(basename "$repo")}
session=$base
n=2
while tmux has-session -t "=$session" 2>/dev/null; do
  session="${base}-${n}"
  n=$((n + 1))
done

# origin/HEAD は fetch されていない clone では未設定なので、既定ブランチは remote に訊く
default_branch=$(git -C "$repo" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -1)
default_branch=${default_branch:-main}
git -C "$repo" fetch origin "$default_branch"

worktree="${repo}-wt"
n=2
while [ -e "$worktree" ]; do
  worktree="${repo}-wt${n}"
  n=$((n + 1))
done
git -C "$repo" worktree add --detach "$worktree" "origin/${default_branch}"

# gitignore された秘匿ファイルは worktree に付いてこないが、無いと dev サーバーが起動しない
copied=()
while IFS= read -r f; do
  case "$f" in
    *.example | *.sample | *.template) continue ;;
  esac
  [ -f "${repo}/${f}" ] || continue
  cp "${repo}/${f}" "${worktree}/${f}"
  copied+=("$f")
done < <(git -C "$repo" ls-files --others --ignored --exclude-standard --directory | grep -E '^(\.env|\.dev\.vars)' || true)

installed=""
if [ -f "${worktree}/package.json" ]; then
  if [ -f "${worktree}/pnpm-lock.yaml" ]; then installed="pnpm install"
  elif [ -f "${worktree}/bun.lockb" ] || [ -f "${worktree}/bun.lock" ]; then installed="bun install"
  elif [ -f "${worktree}/yarn.lock" ]; then installed="yarn install"
  else installed="npm install"
  fi
  ( cd "$worktree" && $installed >/dev/null 2>&1 ) || { echo "$installed failed in $worktree" >&2; exit 70; }
fi

tmux new-session -d -s "$session" -c "$worktree" 'claude'

# worktree は毎回新しいパスなので、初回起動は必ず信頼プロンプトで止まる。
# 「起動した」と「働き始めた」は別なので、最初の画面まで見て報告する
sleep "${NEW_SESSION_SETTLE:-5}"
# 読めなかったときに READY と言わない — 黙って通す false READY が最悪の壊れ方である
if pane=$(tmux capture-pane -p -t "$session" -S -40 2>/dev/null); then
  pane=$(printf '%s' "$pane" | grep -v '^[[:space:]]*$' || true)
  case $pane in
    *"trust this folder"*) state="BLOCKED  フォルダの信頼を尋ねている — 人間が答えるまで働き始めない" ;;
    *"sign in"* | *"Sign in"* | *"Login"* | *"log in"*) state="BLOCKED  サインインを求めている" ;;
    "") state="UNKNOWN  画面が空。attach して目で確かめる" ;;
    *) state="READY" ;;
  esac
else
  pane=""
  state="UNKNOWN  画面を読めなかった。attach して目で確かめる"
fi

echo "session:  $session   (tmux attach -t $session)"
echo "worktree: $worktree  (detached at origin/${default_branch})"
echo "copied:   ${copied[*]:-(none)}"
echo "deps:     ${installed:-(no package.json)}"
echo "state:    $state"
echo "cleanup:  git -C $repo worktree remove $worktree"
echo "--- 最初の画面 ---"
echo "$pane" | tail -6
