#!/usr/bin/env bash
# 「コメント行か」の判定を1か所に持つ。hooks/nudge-comment-check.sh と prune-comments の
# 入口(増えたコメント行の数え上げ)が両方これを呼ぶ — 別々に書くと拡張子の一覧がずれる。
#
#   comment-lines.sh pattern <ファイルパス>   その拡張子のコメント行の ERE を出す。
#                                            コメント記法が一意に決まらなければ終了コード 1
#   comment-lines.sh count <基点>            マージベースから作業ツリー(未追跡を含む)までで
#                                            増えたコメント行の数を出す

set -uo pipefail

pattern() {
  # `#` は Markdown の見出しでも YAML のキーでもあるので、コメント記法が一意に
  # 決まる拡張子だけを見る。
  case "${1##*.}" in
    ts | tsx | js | jsx | mjs | cjs | mts | cts | go | rs | java | c | h | cc | cpp | hpp | cs | swift | kt | kts | scala | php | dart | vue | svelte | css | scss | less)
      # `*/` を除外する: 数えると JSDoc 1ブロックが常に +1 に嵩上げされ、閉じ括弧
      # だけの行が点検対象に混ざる。
      echo '^[[:space:]]*(//|/\*|\*[^/])' ;;
    py | rb | sh | bash | zsh | pl | rake)
      # `#!` を除外する: 素直な `#` だと shebang が数えられ、新規シェルスクリプトを
      # 書くたびに必ず発火する。
      echo '^[[:space:]]*#($|[^!])' ;;
    sql)
      echo '^[[:space:]]*--' ;;
    *)
      return 1 ;;
  esac
}

# 差分の本文だけを数える。ファイル見出しの `--- a/x.sql` は1文字落とすと SQL の
# コメントに見える。
net_in_diff() {
  # `-v` はバックスラッシュを解釈して `\*` を `*` に変えるので、環境変数で渡す。
  RE="$1" awk '
    BEGIN { re = ENVIRON["RE"] }
    /^diff / { body = 0; next }
    /^@@/ { body = 1; next }
    !body { next }
    /^\+/ { if (substr($0, 2) ~ re) n++; next }
    /^-/ { if (substr($0, 2) ~ re) n--; next }
    END { print n + 0 }
  '
}

# ファイルごとの正味の増分のうち、正のものだけを足す。全体で差し引くと、別のファイルを
# 消した分が新しく書いたコメントを打ち消す。
count() {
  local base total=0 f re n
  base=$(git merge-base "$1" HEAD) || exit 2
  while IFS= read -r f; do
    re=$(pattern "$f") || continue
    n=$(git diff "$base" -- "$f" | net_in_diff "$re")
    [ "$n" -gt 0 ] && total=$((total + n))
  done < <(git diff --name-only "$base")
  while IFS= read -r f; do
    re=$(pattern "$f") || continue
    total=$((total + $(git diff --no-index /dev/null "$f" | net_in_diff "$re")))
  done < <(git ls-files --others --exclude-standard)
  echo "$total"
}

case "${1:-}" in
  pattern) pattern "${2:?usage: comment-lines.sh pattern <path>}" ;;
  count) count "${2:?usage: comment-lines.sh count <base>}" ;;
  *) echo "usage: comment-lines.sh pattern <path> | count <base>" >&2; exit 2 ;;
esac
