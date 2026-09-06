#!/usr/bin/env bash
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: resumable.sh <repo-path>" >&2; exit 64; }
repo=$(cd "$1" 2>/dev/null && pwd) || { echo "no such directory: $1" >&2; exit 66; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 66; }

# 一覧を先に読み切る — ループ内の git がパイプの残りを食い、2件目以降が消える
mapfile -t worktrees < <(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')

printf '%-46s %-34s %6s %6s %s\n' PATH BRANCH DIRTY AHEAD "LAST TALK"
for wt in "${worktrees[@]}"; do
  branch=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
  dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)
  ahead=$(git -C "$wt" rev-list --count origin/HEAD..HEAD 2>/dev/null || echo "?")

  # 会話ログの置き場はパスの / を - に潰した名前で決まる
  log_dir="$HOME/.claude/projects/$(printf '%s' "$wt" | tr '/.' '--')"
  # 会話ログが無い worktree では ls が失敗する。pipefail に殺されないよう握る
  last=$(ls -t "$log_dir"/*.jsonl 2>/dev/null | head -1 || true)
  when="-"
  [ -n "$last" ] && when=$(date -r "$last" '+%m/%d %H:%M')

  printf '%-46s %-34s %6s %6s %s\n' "$wt" "$branch" "$dirty" "$ahead" "$when"
done
