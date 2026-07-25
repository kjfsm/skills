#!/usr/bin/env bash
# 1つのゲートを「基点」と「現在」の両方で走らせ、その差だけを出す。
#
# 「このゲートの赤は自分が壊したのか、元からなのか」に答えるためのもの。
# エージェントはこれを実行する — 中身を読む必要はない。
#
# Usage:
#   bash baseline-diff.sh [--base <ref>] [--extract <regex>] -- <gate-command...>
#
# Examples:
#   bash baseline-diff.sh -- npm run lint
#   bash baseline-diff.sh --base main -- npm test
#   bash baseline-diff.sh --extract '^[^ ]+\.(ts|tsx)' -- npm run format:check
#
#   --base    比較する基点。既定は HEAD(= コミットしていない変更の影響を見る)。
#             ref を渡すと、その ref をデタッチで一時チェックアウトして走らせる。
#   --extract 出力から比較したい部分だけを取り出す正規表現(grep -oE に渡る)。
#             省略すると行全体を比較する。ファイル名だけを比べたいときに使う。
#
# 出力:
#   NEW   現在だけで出ている  = この変更が壊したもの。直す対象はこれだけである。
#   PRE   両方で出ている      = 元から赤。そう述べて先へ進む。
#   FIXED 基点だけで出ていた  = この変更が直したもの。
#
# 終了コード: NEW が1件でもあれば 1、なければ 0。
#
# 作業ツリーは stash / detach で一時的に動かし、EXIT trap で必ず元へ戻す。

set -uo pipefail

BASE="HEAD"
EXTRACT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --extract) EXTRACT="$2"; shift 2 ;;
    --) shift; break ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ $# -gt 0 ] || { printf 'usage: baseline-diff.sh [--base <ref>] [--extract <regex>] -- <gate-command...>\n' >&2; exit 2; }

git rev-parse --git-dir >/dev/null 2>&1 || { printf 'not a git repository\n' >&2; exit 2; }
git rev-parse --verify --quiet "$BASE" >/dev/null || { printf 'cannot resolve base: %s\n' "$BASE" >&2; exit 2; }

WORK="$(mktemp -d)"
STASHED=0
RETURN_REF="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"

# 元の位置と作業ツリーへ戻す。git は --quiet でも内部マージの一言を出すので
# 出力は握り、失敗したときだけ見せる — 失敗は黙って通してよいものではない。
restore() {
  local out
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "$RETURN_REF")" ]; then
    if ! out="$(git checkout --quiet "$RETURN_REF" 2>&1)"; then
      printf '%s\n元の位置 %s へ戻れなかった。手で戻すこと。\n' "$out" "$RETURN_REF" >&2
      return 1
    fi
  fi
  if [ "$STASHED" -eq 1 ]; then
    if ! out="$(git stash pop --quiet 2>&1)"; then
      printf '%s\n作業ツリーは stash に残っている。`git stash list` で確認し、手で pop すること。\n' "$out" >&2
      return 1
    fi
    STASHED=0
  fi
}
cleanup() { restore; rm -rf "$WORK"; }
trap cleanup EXIT

# ゲートの出力を、比較できる行の集合へ落とす。
collect() {
  if [ -n "$EXTRACT" ]; then
    grep -oE "$EXTRACT" | sort -u
  else
    sed 's/[0-9]\+\(\.[0-9]\+\)\?\(ms\|s\)\b/<t>/g' | sort -u
  fi
}

"$@" 2>&1 | collect > "$WORK/now"

if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  git stash push --quiet --include-untracked --message "baseline-diff.sh" || {
    printf 'could not stash the working tree; aborting without running the base\n' >&2
    exit 2
  }
  STASHED=1
fi

[ "$(git rev-parse "$BASE")" = "$(git rev-parse HEAD)" ] || git checkout --quiet --detach "$BASE" || {
  printf 'could not check out base: %s\n' "$BASE" >&2
  exit 2
}

"$@" 2>&1 | collect > "$WORK/base"

restore || exit 2

printf '=== NEW   (この変更が壊したもの) ===\n'; comm -13 "$WORK/base" "$WORK/now"
printf '=== PRE   (元から赤) ===\n';             comm -12 "$WORK/base" "$WORK/now"
printf '=== FIXED (この変更が直したもの) ===\n';  comm -23 "$WORK/base" "$WORK/now"

NEW_COUNT="$(comm -13 "$WORK/base" "$WORK/now" | grep -c . || true)"
printf '\nNEW=%s  基点=%s\n' "$NEW_COUNT" "$BASE"
[ "$NEW_COUNT" -eq 0 ]
