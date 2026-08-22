# GitHub Actions のテンプレート

`SKILL.md` の手順4が使う雛形と、**各行がそこにある理由**。理由が読めない行は消してよい — 意味を持たない設定はいずれ「そういうものだから」で増殖する。

## 目次

1. [骨格](#1-骨格) — トリガー・並行制御・権限
2. [Node + pnpm](#2-node--pnpm)
3. [検証ゲートのステップ](#3-検証ゲートのステップ)
4. [E2E を足す](#4-e2e-を足す)
5. [他のスタック](#5-他のスタック)
6. [必須チェックにする](#6-必須チェックにする)
7. [よくある落ち方](#7-よくある落ち方)

## 1. 骨格

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

- **`push: branches: [main]` と `pull_request` の両方** — PR で緑だったものが、マージ後の main で赤くなることがある(別の PR と組み合わさって初めて壊れる)。main 側を見ていないと、次に PR を出した人が他人の赤を踏む
- **`concurrency` + `cancel-in-progress`** — 同じブランチへ push を重ねたとき、古い実行を打ち切る。付けないとキューが詰まり、最新の結果が最後に届く。`github.ref` を含めるので、ブランチをまたいでは打ち切らない
- **`permissions: contents: read`** — 既定のトークンは書き込み権限を持つ。CI から push しない以上、渡す理由が無い。事故ったワークフローやサードパーティ Action が押せる範囲を、読み取りに落としておく

## 2. Node + pnpm

```yaml
- uses: pnpm/action-setup@v4

- uses: actions/setup-node@v4
  with:
    node-version-file: .node-version
    cache: pnpm

- run: pnpm install --frozen-lockfile
```

- **順序が効く。** `setup-node` の `cache: pnpm` は pnpm が既に居ることを前提にするので、`pnpm/action-setup` が先に来る。逆にすると「pnpm が見つからない」で落ちる
- **`node-version-file`** — バージョンを YAML に直接書かない。書くと手元(`.node-version` / `.nvmrc`)とずれ、ずれた事実が誰にも見えない。ファイルが無いならこの機会に作る
- **`--frozen-lockfile`** — ロックファイルと `package.json` が食い違っていたら落とす。付けないと CI が黙って解決し直し、手元と別のバージョンで緑になる。npm なら `npm ci`、yarn なら `--immutable`
- **`postinstall` で生成物を作るリポジトリでは、これだけで型チェックが通る。** 無いなら生成コマンドを明示的に足す。どちらなのかは手順1で確かめる

## 3. 検証ゲートのステップ

`docs/agents/verification.md` の行と 1:1 に、同じ順で並べる。

```yaml
- run: pnpm typecheck
- run: pnpm lint
- run: pnpm format:check
- run: pnpm test
- run: pnpm build
```

- **`format:check` であって `format` ではない。** 書き換える側を CI で走らせると、差分が出たまま緑になる。CI は落とすだけにする
- **`name:` は省いてよい。** `run` がそのままログの見出しになるので、コマンドと違う名前を付けると、赤を読むときに一段翻訳が要る
- ステップを分けておくと、どの行で落ちたかが一覧で分かる。`&&` で1行に畳まない

## 4. E2E を足す

```yaml
- name: Install Playwright browsers
  run: pnpm exec playwright install --with-deps chromium

- run: pnpm test:e2e

- uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 7
```

- **`--with-deps`** — ubuntu ランナーにはブラウザの共有ライブラリが揃っていない。付け忘れると、ブラウザは入るのに起動で落ちる
- **インストールするブラウザは明示する。** 引数なしだと3種類入り、CI 時間が数分増える
- **`if: failure()` のレポート回収** — E2E の赤はログだけでは読めない。トレースとスクリーンショットが無いと、CI 専用の失敗を手元で追えない。これが CI で唯一「手元に無いものを足す」正当な理由である
- Playwright の `webServer` 設定があるなら、CI 側でサーバーを起動しない。二重起動でポートが埋まる

## 5. 他のスタック

| スタック | 置き換わるところ                                                                |
| -------- | ------------------------------------------------------------------------------- |
| npm      | `pnpm/action-setup` を落とし、`cache: npm`、`npm ci`                            |
| yarn     | `cache: yarn`、`yarn install --immutable`                                       |
| Bun      | `oven-sh/setup-bun@v2`、`bun install --frozen-lockfile`                         |
| Python   | `actions/setup-python@v5` + `cache: pip`、あるいは `astral-sh/setup-uv@v5`      |
| Go       | `actions/setup-go@v5`(`cache` は既定で有効)、`go build ./...` → `go test ./...` |
| Rust     | `dtolnay/rust-toolchain@stable` + `Swatinem/rust-cache@v2`                      |

GitLab CI なら `.gitlab-ci.yml` の `stages` に同じ順で並べ、`interruptible: true` が `concurrency` に当たる。

## 6. 必須チェックにする

ワークフローを置いただけでは、赤いままマージできる。**リポジトリ設定を変えるまで CI は助言である。**

1. 追加後、PR を1本通してジョブを1回実行する(実行していないジョブ名は選択肢に出ない)
2. Settings → Branches → `main` のルール → **Require status checks to pass before merging** → ジョブ名(上の例なら `verify`)を選ぶ
3. **Require branches to be up to date before merging** は、main の動きが速いリポジトリでは付けない — マージのたびに全 PR の再実行が要る
4. `main` への直 push を禁じる絶対ルールがあるなら **Require a pull request before merging** も入れる

これはファイルではないので、**エージェントは代わりに設定できない。** ユーザーに手順として渡す。

## 7. よくある落ち方

- **手元では通るのに CI だけ赤い** → たいてい生成物かコミット漏れ。`git status --porcelain` が空か、`.gitignore` が生成物を無視していて CI 側で作られているかを確かめる
- **CI だけ通って手元が赤い** → CI が verification.md より少ない行しか走らせていない。手順2に戻る
- **fork からの PR で必ず落ちる** → シークレットは fork の PR に渡らない。その経路のゲートは `pull_request` から外す
- **キャッシュが効いていない** → `cache:` はロックファイルをキーにする。ロックファイルがリポジトリに無ければ何もキャッシュされない
