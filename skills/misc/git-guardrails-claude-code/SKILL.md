---
name: git-guardrails-claude-code
description: 危険な git コマンド(push, reset --hard, clean, branch -D など)を実行前にブロックする Claude Code フックをセットアップする。破壊的な git 操作の防止、git 安全フックの追加、Claude Code での git push/reset のブロックをユーザーが望む場合に使う。
---

# Git ガードレールのセットアップ

Claude が危険な git コマンドを実行する前に、それを検知してブロックする PreToolUse フックをセットアップする。

## ブロック対象

- `git push` (`--force` を含むすべてのバリエーション)
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

ブロックされると、Claude には拒否理由がそのまま渡り、そのコマンドは実行されない。

拒否は **終了コード 0 と `hookSpecificOutput.permissionDecision: "deny"`** で返す。終了コード 2 でも今のところ拒否になるが、そちらは非推奨の経路である。`jq` が無いなどでコマンドを取り出せなかったときは `"defer"` を返して通常の権限フローへ戻す — ガードレールが壊れたときに、全部拒否も全部許可もしないためである。

## 手順

### 1. スコープを確認する

ユーザーに確認する: **このプロジェクトのみ**(`.claude/settings.json`)か **全プロジェクト**(`~/.claude/settings.json`)のどちらにインストールするか?

### 2. フックスクリプトをコピーする

同梱されているスクリプトは [scripts/block-dangerous-git.sh](scripts/block-dangerous-git.sh) にある。

スコープに応じて、以下の配置先にコピーする。

- **プロジェクト**: `.claude/hooks/block-dangerous-git.sh`
- **グローバル**: `~/.claude/hooks/block-dangerous-git.sh`

`chmod +x` で実行可能にする。

### 3. フックを settings に追加する

該当する settings ファイルに以下を追加する。

**プロジェクト**(`.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

**グローバル**(`~/.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

settings ファイルが既に存在する場合は、既存の `hooks.PreToolUse` 配列にフックをマージすること — 他の設定を上書きしないように。

### 4. カスタマイズについて確認する

ブロックリストにパターンを追加・削除したいかユーザーに確認する。必要に応じてコピーしたスクリプトを編集する。

### 5. 検証する

簡単なテストを実行する。

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | <path-to-script>
```

終了コード 0 で終わり、標準出力に `"permissionDecision":"deny"` を含む JSON が出るはず。素通しの側も確かめる:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | <path-to-script>
```

こちらは何も出力せず、終了コード 0 で終わる。
