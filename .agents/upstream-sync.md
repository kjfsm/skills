# 本家(mattpocock/skills)との同期

このリポジトリは [mattpocock/skills](https://github.com/mattpocock/skills) の日本語訳から出発した**独立フォーク**である。git 上の共通祖先は無いので、差分は**本家のコミット範囲**で管理する。

|                        | 本家のコミット | 日付       |
| ---------------------- | -------------- | ---------- |
| フォークの起点         | `ed37663`      | 2026-07-21 |
| 最後に突き合わせた地点 | `5b15a47`      | 2026-08-21 |

次に同期するときは `git clone https://github.com/mattpocock/skills` して `git diff 5b15a47..HEAD -- skills/` から始める。この表を更新するのは、実際に突き合わせて取捨を決めたときだけである。

## 起点の確認方法

`ed37663` は推定ではない。フォーク初版(`2747d44`, 2026-07-25)のスキル集合が、本家 `ed37663` の集合と次の差だけで一致した — `ask-matt`→`ask-kjfsm`、`setup-matt-pocock-skills`→`setup-skills`、`personal/obsidian-vault` を落とし、`ai-efficiency` と `setup-cf-app` を足した。次の本家コミット `17f22a3` は `writing-great-skills` を `writing-for-agents` に改名しており、フォークは旧名を持っているので、起点はその手前である。

## 差分の読み方 — 大半は文体である

`ed37663..5b15a47` は 137 コミット・2,333 変更行あるが、**その過半は em-dash(`—`)を `:` や `,` に置換する文体スイープ**である。日本語のこのフォークには当たらない。正規化して句読点だけの差を落とすと、実質は 39 ファイルまで縮む。

差分を測るときは行単位で数えない。両リビジョンの各ファイルを段落単位で正規化(`—:;,.()"'` を空白に潰す)してから比較すると、実質変更だけが残る。

## 取り込まないと決めているもの

- **em-dash スイープ** — このフォークは日本語で `—` を使う文体を採っている
- **`writing-great-skills` → `writing-for-agents` の改名と再構成** — こちらは `OFFICIAL.md`(公式仕様の突き合わせ)を足す方向へ独自に伸ばしてある
- **`ask-matt` / `setup-matt-pocock-skills` の変更** — `ask-kjfsm` / `setup-skills` は別物になった。後者は `setup-repo` を入口とする4工程に分解済み
- **`code-review`** — `two-axis-review` に置き換えてある
- **`deprecated/` バケットの廃止** — 本家は退役スキルを削除する方針に変えたが、こちらは残す
