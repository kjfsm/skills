# クラウドのサンドボックスで用意する

Claude Code on the web のように、**毎回まっさらなコンテナで始まり、セットアップスクリプトの結果だけがスナップショットに残る**環境で、[SKILL.md](./SKILL.md) の3つの層をどう割り当てるか。同じ形は Codespaces や devcontainer にも移せる。

## 前提を3つ確かめる

1. **同梱物は公表されていない。** [Installed tools](https://code.claude.com/docs/en/cloud-environments#installed-tools) の表にブラウザの行は無い。それでも `PLAYWRIGHT_BROWSERS_PATH` が設定され、その先にブラウザが置いてあることがある — **ドキュメントに無いものは、告知なく動く**。だから「置いてある実体」に合わせて `@playwright/test` を下げる案は取らない
2. **イメージは差し替えられない。** 公式は "To customize the base image, use a setup script to install what you need on top of the provided image (…) **Replacing the base image entirely isn't supported yet.**" と書いている。イメージに入る Playwright の版を選ぶ口は無い
3. **セットアップスクリプトだけがキャッシュされる。** スクリプトの完了後にファイルシステムがスナップショットされ、以降のセッションはそこから始まる(スクリプト自体は飛ばされる。作り直しはスクリプトを変えたときと約7日で)。スナップショットが撮られるのは Claude Code の起動前なので、**SessionStart フックが取ってきたものは残らない**

## 割り当て

| 層                    | 置き場所                         | キャッシュ |
| --------------------- | -------------------------------- | ---------- |
| VM のプロビジョニング | 環境のセットアップスクリプト     | 残る       |
| プロジェクトの用意    | `.claude/hooks/session-start.sh` | 残らない   |
| CI                    | `.github/workflows/ci.yml`       | —          |

### セットアップスクリプト(環境の設定画面。リポジトリの外)

```bash
#!/usr/bin/env bash

# @playwright/test を上げたらここも上げる。ずれても壊れず、フック側が落として遅くなるだけ。
npx --yes playwright@1.62.1 install --with-deps chromium || true
```

- **版を直に書くことになる。** スクリプトが走る時点でリポジトリの `node_modules` を当てにできないため。正はあくまでフック側で、ここはキャッシュにすぎない
- **`|| true` を付ける。** 公式の制約が "if the script exits non-zero, **the session fails to start**"。ブラウザの取得に失敗しても、セッションごと立ち上がらなくなるほうが困る
- **5分の制限に収める。** chromium の取得は実測20秒前後、`--with-deps` の `apt-get` が20秒前後
- `PLAYWRIGHT_BROWSERS_PATH` が設定済みの環境なら、置き場所は勝手に揃う

### SessionStart フック(リポジトリ側。ここが正)

依存を用意した直後に、無条件で置く。

```bash
pnpm exec playwright install chromium >&2 2>&1
```

- **版は lockfile から決まる。** セットアップスクリプト側とずれても、ここが取り直すので壊れない
- **`--with-deps` を付けない。** このフックは手元の macOS でも非 root の Linux でも走る(→ [SKILL.md](./SKILL.md) の手順3)
- **早抜けの分岐を書かない。** 揃っていれば数秒で戻る
- **標準出力を stderr へ逃がす。** SessionStart の標準出力はそのままコンテキストに入るので、インストールのログを流し込まない

## 症状から引く

| 症状                                            | 見るところ                                                           |
| ----------------------------------------------- | -------------------------------------------------------------------- |
| `Executable doesn't exist at .../chromium-NNNN` | 要求 revision と置いてある revision のずれ。`--dry-run` で両方を出す |
| `Missing system dependencies`                   | `--with-deps` を付ける層(CI / プロビジョニング)を飛ばしている        |
| 新しいセッションのたびに取得が走る              | フックにしか置いていない。セットアップスクリプトへ前倒しする         |
| セッションが立ち上がらなくなった                | セットアップスクリプトが非ゼロで終わっている。`\|\| true` が無い     |
| 手元は緑で CI だけ落ちる                        | `executablePath` の逃げ道が残っている。消してピン通りに取り直す      |
