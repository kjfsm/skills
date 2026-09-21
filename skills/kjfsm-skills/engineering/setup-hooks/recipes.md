# 弾く層の雛形

`SKILL.md` の手順3〜5が使う。**上から順に、置ける一番上の層で済ませる** — 1 と 2 で足りるものを 3 以降へ降ろさない。

## 目次

1. [`permissions.deny`](#1-permissionsdeny)
2. [検査スクリプトを git hook と CI から呼ぶ](#2-検査スクリプトを-git-hook-と-ci-から呼ぶ)
3. [Claude フックの共通の骨格](#3-claude-フックの共通の骨格)
4. [Bash 経由の書き込みまで止める](#4-bash-経由の書き込みまで止める)
5. [`--no-verify` を止める（自己スコープ版）](#5---no-verify-を止める自己スコープ版)
6. [セッション開始時に環境を用意する](#6-セッション開始時に環境を用意する)
7. [応答を終える前に型チェックを通す](#7-応答を終える前に型チェックを通す)
8. [settings.json への配線](#8-settingsjson-への配線)
9. [検査のしかた](#9-検査のしかた)

## 1. `permissions.deny`

gitignore 済みのファイルの保護は、ここで終わる。スクリプトは0本でよい。

```json
{
  "permissions": {
    "deny": [
      "Read(.dev.vars)",
      "Edit(.dev.vars)",
      "Write(.dev.vars)",
      "Read(.env)",
      "Edit(.env)",
      "Write(.env)",
      "Read(.env.local)",
      "Edit(.env.local)",
      "Write(.env.local)"
    ]
  }
}
```

- ⚠️ **ツール呼び出しにしか掛からない。** `Bash` 経由の書き込み(`sed -i`、`pnpm install` による lock の書き換え)は通る。散文側で「これも守られる」と書かない
- ⚠️ **glob が巻き込む先を実物で確かめる。** `.dev.vars.*` と書くと `.dev.vars.example` まで塞ぐ — 追跡されていて、他のスキルが編集し、検査スクリプトが読むファイルである。**1つずつ列挙するほうが安い**
- ⚠️ **素の名前(`"NotebookEdit"`)を書くと、そのツール定義がペイロードから消える。** 引数付き(`"Edit(...)"`)はそうならない。詳細は `/kjfsm-skills:tend-memory-files`
- 追跡されている生成物(`pnpm-lock.yaml`、`worker-configuration.d.ts`)はここではなく 2 — commit に届くので、「再生成して diff が出たら落とす」が本来の検査である

## 2. 検査スクリプトを git hook と CI から呼ぶ

述語は1本のスクリプトに置く。`lefthook.yml` は薄い呼び出し役にする。

```ts
// scripts/check-migrations.ts
// 適用済み（origin/main にある）マイグレーションの改変・削除を弾く。
// 存在の有無ではなく merge-base との差分で見るのは、生成直後の手直しを通すため。
import { execFileSync } from "node:child_process";

const base = execFileSync("git", ["merge-base", "origin/main", "HEAD"], {
  encoding: "utf8",
}).trim();
const changed = execFileSync(
  "git",
  ["diff", "--name-status", "--diff-filter=MDR", base, "--", "drizzle/"],
  {
    encoding: "utf8",
  },
);

export function main(): number {
  const offenders = changed.split("\n").filter(Boolean);
  if (offenders.length === 0) return 0;
  for (const line of offenders) console.error(`適用済みのマイグレーションを変更している: ${line}`);
  return 1;
}

// import 時に走らせない — ユニットテストから述語だけを呼べるようにする
if (process.argv[1]?.endsWith("check-migrations.ts")) process.exit(main());
```

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  jobs:
    - name: format
      glob: "*.{ts,tsx,json,md}"
      run: pnpm oxfmt {staged_files}
      stage_fixed: true

pre-push:
  jobs:
    - name: verify
      run: pnpm check && pnpm test
```

- **pre-commit は1秒未満に保つ。** 越えたものは pre-push へ。毎コミット待たされると `--no-verify` が現実的な選択肢に見え始める
- **CI も同じコマンドを呼ぶ**(`/kjfsm-skills:setup-ci`)。⚠️ merge-base を使う検査は checkout に `fetch-depth: 0` が要る — 既定の 1 では解決できず、検査が**黙って飛ぶ**
- **誤爆を潰す。** 禁止パターンを素の grep で探すと、その禁止を説明しているコメント本文に当たる。コメントとクォート内を落としてから判定する
- **例外は理由付きの定数に登録する** — `KNOWN_*` のような配列に「なぜ安全か」を添える。許可そのものが確認の記録になる
- `prepare: "lefthook install"` を `package.json` に入れる。入れないと clone した人のところで1本も走らない

## 3. Claude フックの共通の骨格

ここから下は、1 と 2 から**構造的に見えないもの**だけである。

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

## 4. Bash 経由の書き込みまで止める

`permissions.deny` は `Edit` / `Write` しか見ない。**`sed -i` まで止めたいと決めたとき**だけ、この形を足す。

```bash
# .claude/hooks/block-generated-edits.sh
GENERATED='app/db/auth-schema\.ts|worker-configuration\.d\.ts|app/shadcn/'
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

## 5. `--no-verify` を止める（自己スコープ版）

git hook 自身を飛ばすフラグなので、git hook には原理的に置けない。**`~/.claude/settings.json` に1本**置き、スコープは実行時に決める。

```bash
# ~/.claude/hooks/block-no-verify.sh
[[ "$(jq -r '.tool_name // empty' <<<"$input")" == "Bash" ]] || exit 0

root="$(git -C "$(jq -r '.cwd // "."' <<<"$input")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
# git hook が無いリポジトリでは --no-verify は no-op。止めるのは雑音でしかない
[[ -f "$root/lefthook.yml" || -f "$root/lefthook.yaml" || -d "$root/.husky" ]] || exit 0

cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
# クォート内を落としてから判定する — 「--no-verify は使わない」と書いた
# コミットメッセージ自体が弾かれるのが、この検査の典型的な誤爆である
bare="$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd")"

[[ "$bare" =~ (--no-verify|--no-gpg-sign|commit\.gpgsign=false) ]] &&
  deny "ゲートを飛ばさない。落ちた根本原因(型・lint・テスト)を直してから通す。"

exit 0
```

⚠️ **リポジトリ非依存だから user-level、ではない。** user-level に置けるのは、**該当しないリポジトリで黙って何もしない**と書けるものだけである。実態を見ずに全プロジェクトへ配ると、設計どおりの作業を毎日止める。

## 6. セッション開始時に環境を用意する

```bash
# .claude/hooks/session-start.sh
cd "$CLAUDE_PROJECT_DIR" || exit 0
[ -d node_modules ] || pnpm install --frozen-lockfile >&2
```

- `SessionStart` の**標準出力はそのままコンテキストに入る**。インストールのログを流し込まないよう `>&2` へ送る
- **すでに用意できていれば何もしない。** 毎回インストールすると、セッション開始が数十秒重くなる
- クラウドセッション(`CLAUDE_CODE_REMOTE=true`)でだけ走らせたいなら、その環境変数で分岐する
- 重い準備は `"async": true` を付けて背後で走らせられる。ただし最初のツール呼び出しが準備完了を待たない点に注意する

## 7. 応答を終える前に型チェックを通す

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

⚠️ **数秒で終わるものだけ置く。** 応答のたびに走る。テストや E2E は CI が持つ(`/kjfsm-skills:setup-ci`)。ここを重くすると、体感の遅さの原因が見えないまま蓄積する。

## 8. settings.json への配線

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
- ⚠️ **プラグイン由来のフックを `.claude/settings.json` へ重ねて登録しない。** プラグインの `hooks/hooks.json` は自動で拾われるので、二重発火になる。`/hooks` で登録数を見れば1行で分かる

## 9. 検査のしかた

**両方向を試す。** 通す側が壊れたフックは、動いて見えて作業を止める。

```bash
h=.claude/hooks/block-generated-edits.sh

echo '{"tool_name":"Edit","tool_input":{"file_path":"app/db/auth-schema.ts"}}' | "$h"; echo "exit=$?"
echo '{"tool_name":"Edit","tool_input":{"file_path":"app/db/index.ts"}}'       | "$h"; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"sed -i s/a/b/ app/db/auth-schema.ts"}}' | "$h"; echo "exit=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"grep -n foo app/db/auth-schema.ts"}}'  | "$h"; echo "exit=$?"
```

1番目と3番目は `"permissionDecision":"deny"` を含む JSON、2番目と4番目は**無出力**。**4つとも `exit=0`** になる。

検査スクリプト(2)は、**弾く入力・通す入力・誤爆しそうな入力**を実際にワーキングツリーへ作って走らせる。ユニットテストはそのうえで書く — テストだけでは「実際に `pnpm check` から呼ばれているか」が確かめられない。

配線したあとは、実際に Claude Code から1度踏んで確かめる — settings の書き方を間違えたフックは、**呼ばれないだけで何のエラーも出ない**。
