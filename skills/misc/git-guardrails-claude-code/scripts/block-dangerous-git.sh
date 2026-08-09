#!/bin/bash
# PreToolUse フック — 破壊的な git コマンドを実行前に拒否する。
#
# 拒否は「終了コード 0 + hookSpecificOutput.permissionDecision」で返す。
# 終了コード 2 でも今のところ拒否になるが、そちらは非推奨の経路であり、
# 拒否理由をモデルへ渡す粒度もこちらの方が細かい。
set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# jq が無い、あるいは Bash 以外のツールで呼ばれてコマンドが取れない場合は、
# 何も主張せず通常の権限フローへ戻す。ガードレールが壊れたときに
# 「全部拒否」も「全部許可」もしないための逃げ道である。
if [ -z "$COMMAND" ]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"defer"}}'
  exit 0
fi

DANGEROUS_PATTERNS=(
  "git push"
  "git reset --hard"
  "git clean -fd"
  "git clean -f"
  "git branch -D"
  "git checkout \."
  "git restore \."
  "push --force"
  "reset --hard"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -qE "$pattern"; then
    jq -n --arg cmd "$COMMAND" --arg pat "$pattern" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: (
          "BLOCKED: \($cmd) matches the dangerous pattern \($pat). " +
          "The user has set up a guardrail against this. " +
          "Do not work around it with another command — tell the user what you wanted to run and why."
        )
      }
    }'
    exit 0
  fi
done

exit 0
