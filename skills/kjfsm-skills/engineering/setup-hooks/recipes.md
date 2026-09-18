# フックの雛形

`SKILL.md` の手順4が使う。どれも **終了コード 0 + `permissionDecision`** で返し、判定できなければ**黙って通す**。

## 目次

1. [共通の骨格](#1-共通の骨格)
2. [生成物の手編集を止める](#2-生成物の手編集を止める)
3. [保護ブランチへの push を止める](#3-保護ブランチへの-push-を止める)
4. [セッション開始時に環境を用意する](#4-セッション開始時に環境を用意する)
5. [応答を終える前に型チェックを通す](#5-応答を終える前に型チェックを通す)
6. [settings.json への配線](#6-settingsjson-への配線)
7. [検査のしかた](#7-検査のしかた)

## 1. 共通の骨格

```bash
#!/usr/bin/env bash
set -uo pipefail
# set -e は付けない — grep の不一致(終了コード 1)で抜けると、
# 「通してよい」場合に無出力・非ゼロで終わり、フックの失敗として扱われる。

input="$(cat)"

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

command -v jq >/dev/null || exit 0   # 判定できないなら通す
```

⚠️ **最後の行が要る。** `jq` が無い環境で拒否側に倒すと、フックが壊れた瞬間に何も実行できなくなる。無出力の `exit 0` は通常の権限フローへ戻る。

## 2. 生成物の手編集を止める

`Edit` / `Write` と、`Bash` 経由の書き込みの**両方**を見る。片方だけだと `sed -i` で素通しになる。

```bash
# .claude/hooks/block-generated-edits.sh
GENERATED='app/db/auth-schema\.ts|worker-configuration\.d\.ts|drizzle/migrations/|app/shadcn/'
REGEN='それぞれの再生成コマンドは .claude/rules/generated-files.md にある'

tool="$(jq -r '.tool_name // empty' <<<"$input")"

case "$tool" in
  Edit | Write | NotebookEdit)
    path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
    [[ "$path" =~ $GENERATED ]] &&
      deny "$path は生成物なので手で編集しない。$REGEN。生成元(スキーマ定義・wrangler.jsonc・ルートファイル)を直して作り直す。"
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
    # 書き込む形のコマンドだけを見る。grep や cat は素通しする
    [[ "$cmd" =~ (sed[[:space:]]+-i|tee|[[:space:]]*\>|dd[[:space:]]) ]] &&
      [[ "$cmd" =~ $GENERATED ]] &&
      deny "そのコマンドは生成物に書き込む。$REGEN。"
    ;;
esac

exit 0
```

- **`GENERATED` は実パスを書く。** ディレクトリ名だけの広いパターンにすると、通ってよい編集を巻き込む
- **理由に再生成の手段を書く。** 「禁止」だけだと、モデルは別の書き込み経路を探し始める
- `Bash` 側は**書き込む形**に限定する。読み取りまで弾くと、生成物を確認することすらできなくなる

## 3. 保護ブランチへの push を止める

```bash
# .claude/hooks/block-protected-push.sh
PROTECTED='main|master|release'

[[ "$(jq -r '.tool_name // empty' <<<"$input")" == "Bash" ]] || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
[[ "$cmd" =~ git[[:space:]]+push ]] || exit 0

# 明示的な push 先
if [[ "$cmd" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+(HEAD:)?($PROTECTED)([[:space:]]|$) ]]; then
  deny "保護ブランチへの直 push は禁止。ブランチを切って PR を出す。"
fi

# 引数なしの push — 現在のブランチが保護対象なら止まる
if [[ "$cmd" =~ git[[:space:]]+push[[:space:]]*$ || "$cmd" =~ git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]*$ ]]; then
  branch="$(git -C "$(jq -r '.cwd // "."' <<<"$input")" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  [[ "$branch" =~ ^($PROTECTED)$ ]] &&
    deny "現在のブランチ $branch は保護対象。ブランチを切って PR を出す。"
fi

exit 0
```

⚠️ **引数なしの `git push` を忘れない。** 明示的な `git push origin main` だけを見るフックは、`main` を checkout したままの `git push` を素通しする — 一番起きる形がこれである。

## 4. セッション開始時に環境を用意する

```bash
# .claude/hooks/session-start.sh
cd "$CLAUDE_PROJECT_DIR" || exit 0
[ -d node_modules ] || pnpm install --frozen-lockfile >&2
```

- `SessionStart` の**標準出力はそのままコンテキストに入る**。インストールのログを流し込まないよう `>&2` へ送る
- **すでに用意できていれば何もしない。** 毎回インストールすると、セッション開始が数十秒重くなる
- クラウドセッション(`CLAUDE_CODE_REMOTE=true`)でだけ走らせたいなら、その環境変数で分岐する
- 重い準備は `"async": true` を付けて背後で走らせられる。ただし最初のツール呼び出しが準備完了を待たない点に注意する

## 5. 応答を終える前に型チェックを通す

```bash
# .claude/hooks/stop-typecheck.sh — Stop イベント
cd "$CLAUDE_PROJECT_DIR" || exit 0
out="$(pnpm typecheck 2>&1)" || {
  jq -n --arg o "$out" '{
    hookSpecificOutput: { hookEventName: "Stop", decision: "block" },
    systemMessage: ("型チェックが通っていない:\n" + $o)
  }'
  exit 0
}
```

⚠️ **数秒で終わるものだけ置く。** 応答のたびに走る。テストや E2E は CI が持つ(`/setup-ci`)。ここを重くすると、体感の遅さの原因が見えないまま蓄積する。

## 6. settings.json への配線

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-generated-edits.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-protected-push.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh" }
        ]
      }
    ]
  }
}
```

- **`matcher` はツール名に対する**(`SessionStart` だけは開始モード)。`|` 区切りか正規表現
- すでに `hooks` があるなら**配列へマージする**。上書きしない
- スクリプトは `chmod +x` を忘れない
- `$CLAUDE_PROJECT_DIR` を引用符で囲む — パスに空白があると引用なしでは壊れる

## 7. 検査のしかた

**両方向を試す。** 通す側が壊れたフックは、動いて見えて作業を止める。

```bash
h=.claude/hooks/block-generated-edits.sh

echo '{"tool_name":"Edit","tool_input":{"file_path":"app/db/auth-schema.ts"}}' | "$h"; echo "exit=$?"
echo '{"tool_name":"Edit","tool_input":{"file_path":"app/db/index.ts"}}'       | "$h"; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ drizzle/migrations/0001.sql"}}' | "$h"; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"grep -n foo drizzle/migrations/0001.sql"}}'  | "$h"; echo "exit=$?"
```

1番目と3番目は `"permissionDecision":"deny"` を含む JSON、2番目と4番目は**無出力**。**4つとも `exit=0`** になる。

配線したあとは、実際に Claude Code から1度踏んで確かめる — settings の書き方を間違えたフックは、**呼ばれないだけで何のエラーも出ない**。
