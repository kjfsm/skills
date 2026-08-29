#!/usr/bin/env bash
# 増えたコメント行の本数だけを数え、そのコメントが適切かはモデルへ返す。
# 判定までフックに寄せると、通ってよい編集を止めた瞬間にモデルが Bash の sed へ
# 逃げて、規約は守られたように見えて実際は緩む(skills/engineering/setup-hooks)。
# 4本の柱をここに書かないのも同じ理由ではなく、常駐3か所(検査 16.)の同期先を
# 増やさないためである。柱は呼び出し側のコンテキストに既にある。
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
    pattern='^[[:space:]]*(//|/\*|\*[^/])' ;;
  py | rb | sh | bash | zsh | pl | rake)
    pattern='^[[:space:]]*#($|[^!])' ;;
  sql)
    pattern='^[[:space:]]*--' ;;
  *)
    exit 0 ;;
esac

count() {
  [ -n "$1" ] || { echo 0; return; }
  grep -cE "$pattern" <<<"$1" || true
}

added=$(count "$(jq -r '.tool_input.new_string // .tool_input.content // empty' <<<"$input")")
removed=$(count "$(jq -r '.tool_input.old_string // empty' <<<"$input")")
net=$((added - removed))
[ "$net" -gt 0 ] || exit 0

jq -n --arg path "$path" --arg n "$net" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ($path + " でコメント行が " + $n + " 行増えた。増えた行それぞれについて、その行を消してコードだけを読んだとき失われる情報があるか答えよ。無い行は今すぐ消す。残す行は、何を運んでいるのかを一語で言えること。")
  }
}'
