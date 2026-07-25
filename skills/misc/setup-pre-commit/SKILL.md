---
name: setup-pre-commit
description: 現在のリポジトリに、lint-staged(Prettier)、型チェック、テストを備えた Husky の pre-commit フックをセットアップする。ユーザーが pre-commit フックの追加、Husky のセットアップ、lint-staged の設定、コミット時のフォーマット/型チェック/テストの追加を望む場合に使う。
---

# Pre-Commit フックのセットアップ

## セットアップされるもの

- **Husky** の pre-commit フック
- ステージされた全ファイルに Prettier を実行する **lint-staged**
- **Prettier** の設定(未設定の場合)
- pre-commit フック内の **typecheck** と **test** スクリプト

## 手順

### 1. パッケージマネージャーを検出する

`package-lock.json`(npm)、`pnpm-lock.yaml`(pnpm)、`yarn.lock`(yarn)、`bun.lockb`(bun)の存在を確認する。存在するものを使う。不明な場合は npm をデフォルトとする。

### 2. 依存パッケージをインストールする

devDependencies としてインストールする:

```
husky lint-staged prettier
```

### 3. Husky を初期化する

```bash
npx husky init
```

これにより `.husky/` ディレクトリが作成され、package.json に `prepare: "husky"` が追加される。

### 4. `.husky/pre-commit` を作成する

以下の内容でファイルを作成する(Husky v9+ では shebang は不要):

```
npx lint-staged
npm run typecheck
npm run test
```

**適応させる**: `npm` を検出したパッケージマネージャーに置き換える。リポジトリの package.json に `typecheck` や `test` スクリプトがない場合は、それらの行を省略しユーザーに伝える。

### 5. `.lintstagedrc` を作成する

```json
{
  "*": "prettier --ignore-unknown --write"
}
```

### 6. `.prettierrc` を作成する(未設定の場合)

Prettier の設定が存在しない場合のみ作成する。以下のデフォルト値を使う:

```json
{
  "useTabs": false,
  "tabWidth": 2,
  "printWidth": 80,
  "singleQuote": false,
  "trailingComma": "es5",
  "semi": true,
  "arrowParens": "always"
}
```

### 7. 検証する

- [ ] `.husky/pre-commit` が存在し実行可能であること
- [ ] `.lintstagedrc` が存在すること
- [ ] package.json の `prepare` スクリプトが `"husky"` であること
- [ ] `prettier` の設定が存在すること
- [ ] `npx lint-staged` を実行して動作を確認すること

### 8. コミットする

変更・作成したファイルをすべてステージし、`Add pre-commit hooks (husky + lint-staged + prettier)` というメッセージでコミットする。

これにより新しい pre-commit フックが実際に実行される — すべてが動作することを確認する良いスモークテストになる。

## 補足

- Husky v9+ ではフックファイルに shebang は不要
- `prettier --ignore-unknown` は Prettier がパースできないファイル(画像など)をスキップする
- pre-commit はまず lint-staged(高速、ステージされたファイルのみ)を実行し、その後に完全な typecheck と test を実行する
