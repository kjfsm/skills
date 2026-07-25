---
name: scaffold-exercises
description: リンティングを通過するセクション・問題・解答・解説を備えたエクササイズのディレクトリ構造を作成する。ユーザーがエクササイズのスキャフォールド、エクササイズのスタブ作成、新しいコースセクションのセットアップを望む場合に使う。
---

# エクササイズのスキャフォールド

`pnpm ai-hero-cli internal lint` を通過するエクササイズのディレクトリ構造を作成し、`git commit` でコミットする。

## ディレクトリ命名規則

- **セクション**: `exercises/` 内の `XX-section-name/`(例: `01-retrieval-skill-building`)
- **エクササイズ**: セクション内の `XX.YY-exercise-name/`(例: `01.03-retrieval-with-bm25`)
- セクション番号 = `XX`、エクササイズ番号 = `XX.YY`
- 名前はダッシュケース(小文字・ハイフン区切り)

## エクササイズのバリアント

各エクササイズには以下のサブフォルダのうち最低1つが必要:

- `problem/` - TODO 付きの学習者用ワークスペース
- `solution/` - リファレンス実装
- `explainer/` - 概念的な資料、TODO なし

スタブ作成時は、計画で特に指定がない限り `explainer/` をデフォルトとする。

## 必須ファイル

各サブフォルダ(`problem/`、`solution/`、`explainer/`)には以下を満たす `readme.md` が必要:

- **空でない**(実際の内容が必要、タイトル1行だけでも可)
- リンク切れがない

スタブ作成時は、タイトルと説明を含む最小限の readme を作成する:

```md
# Exercise Title

Description here
```

サブフォルダにコードがある場合は `main.ts`(2行以上)も必要。ただしスタブの場合は readme のみのエクササイズで問題ない。

## ワークフロー

1. **計画をパースする** - セクション名、エクササイズ名、バリアントの種類を抽出する
2. **ディレクトリを作成する** - 各パスに対して `mkdir -p`
3. **スタブ readme を作成する** - バリアントフォルダごとにタイトル付きの `readme.md` を1つ
4. **lint を実行する** - `pnpm ai-hero-cli internal lint` で検証
5. **エラーを修正する** - lint が通るまで繰り返す

## Lint ルールの要約

リンター(`pnpm ai-hero-cli internal lint`)は以下をチェックする:

- 各エクササイズにサブフォルダ(`problem/`、`solution/`、`explainer/`)があること
- `problem/`、`explainer/`、`explainer.1/` のうち最低1つが存在すること
- 主要サブフォルダに `readme.md` が存在し、空でないこと
- `.gitkeep` ファイルがないこと
- `speaker-notes.md` ファイルがないこと
- readme 内にリンク切れがないこと
- readme 内に `pnpm run exercise` コマンドがないこと
- readme のみの場合を除き、サブフォルダごとに `main.ts` が必要なこと

## エクササイズの移動・リネーム

エクササイズの番号変更や移動を行う場合:

1. ディレクトリのリネームには `mv` ではなく `git mv` を使う - git の履歴が保持される
2. 順序を保つために数値プレフィックスを更新する
3. 移動後に lint を再実行する

例:

```bash
git mv exercises/01-retrieval/01.03-embeddings exercises/01-retrieval/01.04-embeddings
```

## 例: 計画からスタブを作成する

以下のような計画があるとする:

```
Section 05: Memory Skill Building
- 05.01 Introduction to Memory
- 05.02 Short-term Memory (explainer + problem + solution)
- 05.03 Long-term Memory
```

作成する:

```bash
mkdir -p exercises/05-memory-skill-building/05.01-introduction-to-memory/explainer
mkdir -p exercises/05-memory-skill-building/05.02-short-term-memory/{explainer,problem,solution}
mkdir -p exercises/05-memory-skill-building/05.03-long-term-memory/explainer
```

次に readme スタブを作成する:

```
exercises/05-memory-skill-building/05.01-introduction-to-memory/explainer/readme.md -> "# Introduction to Memory"
exercises/05-memory-skill-building/05.02-short-term-memory/explainer/readme.md -> "# Short-term Memory"
exercises/05-memory-skill-building/05.02-short-term-memory/problem/readme.md -> "# Short-term Memory"
exercises/05-memory-skill-building/05.02-short-term-memory/solution/readme.md -> "# Short-term Memory"
exercises/05-memory-skill-building/05.03-long-term-memory/explainer/readme.md -> "# Long-term Memory"
```
