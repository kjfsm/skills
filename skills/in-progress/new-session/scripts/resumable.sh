#!/usr/bin/env bash
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: resumable.sh <repo-path>" >&2; exit 64; }
repo=$(cd "$1" 2>/dev/null && pwd) || { echo "no such directory: $1" >&2; exit 66; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 66; }

# origin/HEAD は fetch されていない clone では未設定なので、無ければ実在する候補から選ぶ。
# ここは判定の前段なので、ネットワークには出ない
base_ref=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
if [ -z "$base_ref" ]; then
  for c in origin/main origin/master; do
    if git -C "$repo" rev-parse --verify --quiet "$c" >/dev/null; then base_ref=$c; break; fi
  done
fi

# 生きているセッションが戻り先の第一候補である。会話ログの新しさはこれの代理にならない
declare -A live=()
while IFS=$'\t' read -r path name; do
  [ -n "$path" ] && live["$path"]=$name
done < <(tmux list-sessions -F '#{session_path}'$'\t''#{session_name}' 2>/dev/null || true)

# 一覧を先に読み切る — ループ内の git がパイプの残りを食い、2件目以降が消える
mapfile -t worktrees < <(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')

fmt='%-4s %-56s %-30s %6s %6s %-12s %s\n'
# shellcheck disable=SC2059
printf "$fmt" KIND PATH BRANCH DIRTY AHEAD "LAST TALK" TMUX
kind=main
for wt in "${worktrees[@]}"; do
  branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
  dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)

  ref=$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "$base_ref")
  ahead="?"
  [ -n "$ref" ] && ahead=$(git -C "$wt" rev-list --count "${ref}..HEAD" 2>/dev/null || echo "?")

  # 会話ログの置き場はパスの / を - に潰した名前で決まる
  log_dir="$HOME/.claude/projects/$(printf '%s' "$wt" | tr '/.' '--')"
  # 会話ログが無い worktree では ls が失敗する。pipefail に殺されないよう握る
  last=$(ls -t "$log_dir"/*.jsonl 2>/dev/null | head -1 || true)
  when="-"
  [ -n "$last" ] && when=$(date -r "$last" '+%m/%d %H:%M')

  # shellcheck disable=SC2059
  printf "$fmt" "$kind" "$wt" "$branch" "$dirty" "$ahead" "$when" "${live[$wt]:--}"
  kind=wt
done
