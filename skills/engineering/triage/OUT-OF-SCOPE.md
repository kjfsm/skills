# スコープ外ナレッジベース

リポジトリ内の `.out-of-scope/` ディレクトリは、却下された機能要望の永続的な記録を保存する。これは2つの目的を果たす:

1. **組織的な記憶** — なぜある機能が却下されたのか。イシューがクローズされたときにその理由が失われないようにする
2. **重複排除** — 過去の却下と一致する新しいイシューが来たとき、このスキルは蒸し返す代わりに過去の決定を表面化させられる

## ディレクトリ構造

```
.out-of-scope/
├── dark-mode.md
├── plugin-system.md
└── graphql-api.md
```

イシューごとではなく **概念** ごとに1ファイル。同じことを要望する複数のイシューは、1つのファイルにまとめられる。

## ファイル形式

このファイルは、データベースのエントリというより短い設計ドキュメントのような、肩の力を抜いた読みやすいスタイルで書くべきである。段落、コードサンプル、例を使い、初めてそれに出会う人にとって理由が明快で役立つようにする。

````markdown
# Dark Mode

This project does not support dark mode or user-facing theming.

## Why this is out of scope

The rendering pipeline assumes a single color palette defined in
`ThemeConfig`. Supporting multiple themes would require:

- A theme context provider wrapping the entire component tree
- Per-component theme-aware style resolution
- A persistence layer for user theme preferences

This is a significant architectural change that doesn't align with the
project's focus on content authoring. Theming is a concern for downstream
consumers who embed or redistribute the output.

```ts
// The current ThemeConfig interface is not designed for runtime switching:
interface ThemeConfig {
  colors: ColorPalette; // single palette, resolved at build time
  fonts: FontStack;
}
```
````

## Prior requests

- #42 — "Add dark mode support"
- #87 — "Night theme for accessibility"
- #134 — "Dark theme option"

```

### ファイルの名付け方

概念に対して短く説明的な kebab-case の名前を使う: `dark-mode.md`、`plugin-system.md`、`graphql-api.md`。ディレクトリを眺める人が、ファイルを開かなくても何が却下されたのか分かる程度には見分けがつく名前にする。

### 理由の書き方

理由は実質的なものであるべきである — 「これはやりたくない」ではなく、なぜかを書く。良い理由は次を参照する:

- プロジェクトのスコープや哲学(「このプロジェクトは X に焦点を当てている。テーマ機能は下流の関心事である」)
- 技術的な制約(「これをサポートするには Y が必要になり、それは我々の Z アーキテクチャと衝突する」)
- 戦略上の決定(「... という理由で B ではなく A を使うことにした」)

理由は長持ちするものであるべきである。一時的な事情(「今は忙しすぎる」)を理由にするのは避ける — それらは本当の却下ではなく、先送りにすぎない。

## いつ `.out-of-scope/` を確認するか

トリアージ中(手順1: コンテキストを集める)に、`.out-of-scope/` の全ファイルを読む。新しいイシューを評価するとき:

- その要求が既存のスコープ外の概念と一致するか確認する
- 一致はキーワードではなく概念の類似性で判断する — 「night theme」は `dark-mode.md` と一致する
- 一致するものがあれば、メンテナーに表面化させる: 「これは `.out-of-scope/dark-mode.md` に似ています — 以前 [理由] のためこれを却下しました。今も同じ考えですか?」

メンテナーは次のいずれかを選べる:

- **確認する** — 新しいイシューは既存ファイルの「Prior requests」リストに追加され、クローズされる
- **再検討する** — スコープ外ファイルが削除または更新され、イシューは通常のトリアージを進む
- **異議を唱える** — それらのイシューは関連しているが別物であり、通常のトリアージを進める

## いつ `.out-of-scope/` に書くか

**拡張**(バグではなく)が `wontfix` として *却下* されたときだけ。これは拡張系の PR にも、イシューとまったく同じように当てはまる — 却下された PR はここに記録され、同じ要求が新しいコードとして戻ってこないようにする。

**すでに実装済み** という理由で `wontfix` としてクローズされる場合は、ここに書か **ない**。それは構築済みの機能であって却下されたものではない。それを記録すると、誤った却下によって重複チェックが汚染されてしまう。代わりに、クローズ時のコメントで、その機能がすでにどこにあるかを示す。

流れ:

1. メンテナーが機能要望をスコープ外だと決める
2. 一致する `.out-of-scope/` ファイルがすでに存在するか確認する
3. あれば: 新しいイシューを「Prior requests」リストに追加する
4. なければ: 概念名、決定、理由、最初の Prior request を持つ新しいファイルを作成する
5. その決定を説明し `.out-of-scope/` ファイルに言及するコメントをイシューに投稿する
6. `wontfix` ラベルを付けてイシューをクローズする

## スコープ外ファイルの更新・削除

メンテナーが以前却下した概念について考えを変えた場合:

- `.out-of-scope/` ファイルを削除する
- このスキルは古いイシューを再オープンする必要はない — それらは過去の記録である
- 再検討のきっかけとなった新しいイシューは、通常のトリアージを進む
```
