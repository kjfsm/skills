#!/usr/bin/env bash
# 判定までフックに寄せると、通ってよい編集を止めた瞬間にモデルが Bash の sed へ
# 逃げて、規約は守られたように見えて実際は緩む。
# 4本の柱をここに書かないのも同じ理由ではなく、常駐3か所(検査 16.)の同期先を
# 増やさないためである。柱は呼び出し側のコンテキストに既にある。

# `-e` を付けない: grep -c は不一致で 1 を返すので、コメント0行の編集のたびに
# ここで異常終了し、フックが黙って壊れる。
set -uo pipefail

# jq が無い環境で拒否側に倒れないよう、判定できなければ黙って通す。
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
path=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null) || exit 0
[ -n "$path" ] || exit 0

# `#` は Markdown の見出しでも YAML のキーでもあるので、コメント記法が一意に
# 決まる拡張子だけを見る。
case "${path##*.}" in
  ts | tsx | js | jsx | mjs | cjs | go | rs | java | c | h | cc | cpp | hpp | cs | swift | kt | kts | scala | php | dart | vue | svelte | css | scss | less)
    # `*/` を除外する: 数えると JSDoc 1ブロックが常に +1 に嵩上げされ、閉じ括弧
    # だけの行が点検対象に混ざる。
    pattern='^[[:space:]]*(//|/\*|\*[^/])' ;;
  py | rb | sh | bash | zsh | pl | rake)
    # `#!` を除外する: 素直な `#` だと shebang が数えられ、新規シェルスクリプトを
    # 書くたびに必ず発火する。
    pattern='^[[:space:]]*#($|[^!])' ;;
  sql)
    pattern='^[[:space:]]*--' ;;
  *)
    exit 0 ;;
esac

count() {
  grep -cE "$pattern" <<<"$1" || true
}

added=$(count "$(jq -r '.tool_input.new_string // .tool_input.content // empty' <<<"$input")")
removed=$(count "$(jq -r '.tool_input.old_string // empty' <<<"$input")")

# Write は old_string を持たないので、差し引かないと既存ファイルの全コメントが
# 「増えた」に化ける。PostToolUse の時点で前版はディスクに無く、git の版で代用する
# — 未コミットのコメントがあると多めに数えるが、鳴りすぎる側へ倒してある。
if jq -e '.tool_input | has("content")' >/dev/null 2>&1 <<<"$input"; then
  dir=$(dirname "$path")
  if rel=$(git -C "$dir" ls-files --full-name --error-unmatch -- "$path" 2>/dev/null); then
    removed=$(count "$(git -C "$dir" show "HEAD:$rel" 2>/dev/null || true)")
  fi
fi

# added だけを見ない: コメントを含むブロックの再インデントや移動が毎回発火する。
net=$((added - removed))
[ "$net" -gt 0 ] || exit 0

jq -n --arg path "$path" --arg n "$net" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ($path + " でコメント行が " + $n + " 行増えた。増えた行それぞれについて、その行を消してコードだけを読んだとき失われる情報があるか答えよ。無い行は今すぐ消す。残す行は、何を運んでいるのかを一語で言えること。")
  }
}'
