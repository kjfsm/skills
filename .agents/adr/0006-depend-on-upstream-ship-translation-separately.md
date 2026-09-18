# `kjfsm-skills` は本家 `mattpocock-skills` に依存し、本家の訳は別プラグイン `matt-skills-jp` で配る

このリポジトリは本家 [mattpocock/skills](https://github.com/mattpocock/skills) の日本語訳から出発したので、`kjfsm-skills` には本家由来の訳と自作のスキルが同じバケットに混ざっていた。どれが自作かはマニフェストからは読めない。本家の更新も、訳を手で直してからでないと届かなかった(→ [upstream-sync.md](../upstream-sync.md))。

本家はそれ自体が Claude Code プラグイン `mattpocock-skills@mattpocock` として配られている。そしてプラグインは、別のマーケットプレイスのプラグインへの依存を宣言できる([Constrain plugin dependency versions](https://code.claude.com/docs/en/plugin-dependencies))。

## 決定

- `kjfsm-skills` の `plugin.json` に `{ "name": "mattpocock-skills", "marketplace": "mattpocock" }` を依存として書く。`marketplace.json` の `allowCrossMarketplaceDependenciesOn` に `mattpocock` を入れる。これが無いと、インストール時に `cross-marketplace` エラーで止まる。
- 本家を**ほぼ訳のまま**写した 17 本は `skills/matt-skills-jp/` へ移し、ADR 0005 と同じ形の別プラグイン `matt-skills-jp` で配る。これは日本語で読みたい人が、本家の**代わりに**入れるものである。
- 本家から離れて自作の流れの中心になった `implement-and-review`(本家の `implement` から改名)・`ask-kjfsm`・`setup-skills`・`writing-great-skills` は `kjfsm-skills` に残す。
- 依存の向きは `kjfsm-skills → 本家` の一方向に揃える。`matt-skills-jp` は自作スキルを名指ししない。

## 却下した手

- **`kjfsm-skills` を `matt-skills-jp` に依存させる。** 訳は本家の更新を手で取り込むまで古いままで、依存先として本家より劣る。
- **訳を消して、本家だけに寄せる。** 日本語で読みたいという、フォークを始めた理由が消える。

## この決定が生む不変条件

- `matt-skills-jp` のスキルは、`kjfsm-skills` のスキルを本文で呼ばない。呼ぶと、訳だけを入れた環境では呼び先が無く、何も起きない。**これは検査が見ていない** — 訳を直すときに `grep` で確かめる。
- 本家と同じ名前のスキルは、`kjfsm-skills` には置かない。同じ名前だと本家版と kjfsm 版の2つが並び、本家の流れ(`ask-matt` や `to-tickets`)から呼ばれたときにどちらが選ばれるかはモデル次第になる。kjfsm の `implement` はそのせいで検証 → コメント削り → 二軸レビューの流れが黙って飛ばされうるので、`implement-and-review` に改名した。
- 依存にはバージョンの制約を付けない。本家の `version` が上がるたびに、kjfsm-skills を入れた環境へそのまま届く。

## 覆る条件

- 本家が、`kjfsm-skills` から呼んでいるスキル(`tdd`・`research`・`codebase-design`・`diagnosing-bugs`・`grilling`)を改名したり退役させたりしたら、呼び先を直す。本家の変更を1回で丸ごと受け取りたくなくなったら、`version` の範囲で固定する。ただし範囲の解決はタグ `mattpocock-skills--v<版>` を探すのに対し、本家のタグは `v1.2.3` の形である(2026-09-18 時点)。このままでは範囲に合う版を取りに行けず、読み込むときに範囲を外れていればプラグインが無効になるだけである。
