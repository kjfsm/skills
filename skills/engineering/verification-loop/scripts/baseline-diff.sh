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
# 終了コード:
#   0  NEW なし
#   1  NEW あり
#   2  比較できなかった(使い方の誤り、ゲートを実行できない、比較対象がない、
#      作業ツリーを戻せなかった)。1 と 2 は必ず区別すること。
#
# 注意: 作業ツリーは `git stash --include-untracked` と detach で一時的に動かし、
# EXIT trap で必ず元へ戻す。未追跡ファイルも退避するので、ゲートが未追跡の
# ファイル(.env、生成済みフィクスチャなど)に依存している場合、基点側の実行が
# その不在で落ちて偽の NEW になりうる。そういうゲートには使わない。

set -uo pipefail

usage() {
  printf 'usage: baseline-diff.sh [--base <ref>] [--extract <regex>] -- <gate-command...>\n' >&2
}

BASE="HEAD"
EXTRACT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || { printf -- '--base に ref がない\n' >&2; usage; exit 2; }; BASE="$2"; shift 2 ;;
    --extract) [ $# -ge 2 ] || { printf -- '--extract に regex がない\n' >&2; usage; exit 2; }; EXTRACT="$2"; shift 2 ;;
    --) shift; break ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[ $# -gt 0 ] || { printf 'ゲートのコマンドがない\n' >&2; usage; exit 2; }
GATE=("$@")

git rev-parse --git-dir >/dev/null 2>&1 || { printf 'not a git repository\n' >&2; exit 2; }
git rev-parse --verify --quiet "$BASE" >/dev/null || { printf 'cannot resolve base: %s\n' "$BASE" >&2; exit 2; }
command -v "${GATE[0]}" >/dev/null 2>&1 || { printf 'ゲートのコマンドが見つからない: %s\n' "${GATE[0]}" >&2; exit 2; }

# 何かを走らせる前に、そもそも比較になるかを確かめる。ここを通さないと、
# クリーンなツリーを自分自身と比べて「NEW なし」という無意味な緑が出る。
DIRTY=0
if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  DIRTY=1
fi
if [ "$(git rev-parse "$BASE")" = "$(git rev-parse HEAD)" ] && [ "$DIRTY" -eq 0 ]; then
  printf '比較対象がない: 作業ツリーはクリーンで、基点も HEAD である。\n' >&2
  printf 'コミット済みの基点と比べるなら --base <ref> を渡すこと。\n' >&2
  exit 2
fi

WORK="$(mktemp -d)"
STASHED=0
RETURN_REF="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"

# git は --quiet でも内部マージの一言を出すので出力は握り、失敗したときだけ
# 見せる — 失敗は黙って通してよいものではない。
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

collect() {
  if [ -n "$EXTRACT" ]; then
    grep -oE "$EXTRACT" | sort -u
  else
    sed 's/[0-9]\+\(\.[0-9]\+\)\?\(ms\|s\)\b/<t>/g' | sort -u
  fi
}

# ゲートが「問題を見つけた」のと「そもそも実行できなかった」のを混ぜない。
# 混ぜると、実行できなかったときのエラーメッセージが差分として現れ、偽の
# NEW になる。
run_gate() {
  local out="$1" rc
  "${GATE[@]}" 2>&1 | collect > "$out"
  rc="${PIPESTATUS[0]}"
  if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
    printf 'ゲートを実行できなかった(終了コード %s): %s\n' "$rc" "${GATE[*]}" >&2
    return 1
  fi
}

run_gate "$WORK/now" || exit 2

if [ "$DIRTY" -eq 1 ]; then
  git stash push --quiet --include-untracked --message "baseline-diff.sh" || {
    printf '作業ツリーを stash できなかった。基点を走らせずに中止する。\n' >&2
    exit 2
  }
  STASHED=1
fi

if [ "$(git rev-parse "$BASE")" != "$(git rev-parse HEAD)" ]; then
  git checkout --quiet --detach "$BASE" || { printf 'cannot check out base: %s\n' "$BASE" >&2; exit 2; }
fi

run_gate "$WORK/base" || exit 2

restore || exit 2

printf '=== NEW   (この変更が壊したもの) ===\n'; comm -13 "$WORK/base" "$WORK/now"
printf '=== PRE   (元から赤) ===\n';             comm -12 "$WORK/base" "$WORK/now"
printf '=== FIXED (この変更が直したもの) ===\n';  comm -23 "$WORK/base" "$WORK/now"

NEW_COUNT="$(comm -13 "$WORK/base" "$WORK/now" | grep -c . || true)"
printf '\nNEW=%s  基点=%s\n' "$NEW_COUNT" "$BASE"
[ "$NEW_COUNT" -eq 0 ]
