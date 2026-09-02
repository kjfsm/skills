# このリポジトリにスキルを足す

配線 — マニフェストへの登録、README への掲載、`agents/openai.yaml` の有無、2つのハーネスの呼び出し方式の一致、frontmatter の上限、参照ファイルの実在と階層 — は `scripts/check-invariants.sh` が機械的に検査する。**走らせて落ちた項目が、まだ済んでいない配線である。** 覚えておく必要はない。

この文書が扱うのは、検査が見られない2つ: 走らせる前に下す **判断** と、検査に出ない **後始末** である。

## 1. バケットを選ぶ

`skills/<バケット>/<スキル名>/SKILL.md` に置く。バケットが決めるのは**配布されるかどうか**である。

| バケット                                                   | 配布                                        | ここに入れるもの                                                        |
| ---------------------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------- |
| `engineering/` `productivity/`                             | **される**(プラグイン + `npx skills`)       | 他人のリポジトリでも価値を持つもの                                      |
| `misc/` `personal/` `emdash/` `in-progress/` `deprecated/` | されない(`npx skills` の個別指定でのみ届く) | このリポジトリ・この端末・特定の CMS に紐づくもの、下書き、退役したもの |

判定は1問で済む: **これは他人のリポジトリで価値を持つか。** 持たないなら昇格しないバケットへ入れる — 昇格は後からできる。

迷ったら `in-progress/` に置く。出荷準備が整っていない下書きの正規の置き場であり、そこに居るあいだは誰にも届かない。

## 2. 呼び出し方式を決める

判定基準は [`.agents/invocation.md`](./invocation.md) にある: **モデルがこれを自律的に使いこなせるか。** 再利用性は切り出す理由ではあっても、この判定基準ではない。

決めたら2つのファイルを揃える。片方だけ書くのが最も多い取りこぼしだが、検査が捕まえる。

|                    | `SKILL.md` frontmatter           | `agents/openai.yaml`                      |
| ------------------ | -------------------------------- | ----------------------------------------- |
| ユーザー呼び出し型 | `disable-model-invocation: true` | `policy.allow_implicit_invocation: false` |
| モデル呼び出し型   | (書かない)                       | (`policy` ブロックを書かない)             |

`agents/openai.yaml` は**どちらの方式でも必要**で、Codex のスキルピッカー用に `interface.display_name` と `interface.short_description` を持つ:

```yaml
interface:
  display_name: "良いスキルを書く"
  short_description: "スキルを予測可能にする原則"
policy:
  allow_implicit_invocation: false # ユーザー呼び出し型のときだけ
```

`description` の宛先も方式で変わる。モデル呼び出し型は**モデル向け**でトリガー表現を厚く持ち、ユーザー呼び出し型は**人間向け**の1行に刈り込む — 後者の description はモデルのコンテキストに載らないので、トリガーを書いても誰も読まない。

## 3. スキルを書く

判断基準は [`/writing-great-skills`](../skills/productivity/writing-great-skills/SKILL.md)、公式の仕様は同じフォルダの [`OFFICIAL.md`](../skills/productivity/writing-great-skills/OFFICIAL.md)。

数値上限(`name` の形式、`description` の長さ、本文の行数、参照ファイルの階層)は**暗記しなくてよい** — 検査が落とす。`OFFICIAL.md` を引くのは、上限を確かめるためではなく、何をどう書くかを決めるためである。

**`name` に `claude` と `anthropic` を入れない。** 仕様上の禁止ではないので検査は落とさないが、Anthropic 側の検証(claude.ai へのアップロード、Skills API、`package_skill.py`)はこれを弾く。Claude Code プラグインと `npx skills` で配るぶんには当たらない一方、**個人スキルを Cowork やクラウドセッションで有効にする経路は claude.ai へのアップロードを通る** ので、そこでは弾かれる。トリガー語としての "CLAUDE.md" が要るなら `description` に書く — 予約語の制約がかかるのは `name` だけである。

残っている例外は `claude-handoff` と `git-guardrails-claude-code` の2つで、どちらも未昇格なので配布経路に乗らない。昇格させるなら、そのときに改名する。(`tend-claude-md` は昇格済みだったので `tend-memory-files` に改名した。)

## 4. 検査を走らせる

```
scripts/check-invariants.sh
```

落ちた項目を潰す。README への追加も `plugin.json` への登録も、ここに出てくる。**クリーンになるまで、配線は済んでいない。**

`claude plugin validate .` も走らせてよいが、2点で当てにならない。リポジトリルートを渡すと `marketplace.json` しか検証せず、`plugin.json` の壊れたパスを見逃す。そして `--strict` は `version` 不在を error に格上げする — このリポジトリではそれが意図した状態である(→ `CLAUDE.md`)。

## 5. 検査に出ない後始末

ここだけは自分で確認する。

- **`ask-kjfsm` を更新する** — ユーザーが到達できるスキルを追加・改名・削除したとき、あるいはフローへの組み込み方を変えたとき。[`SKILL.md`](../skills/engineering/ask-kjfsm/SKILL.md)(起点)と [`SITUATIONS.md`](../skills/engineering/ask-kjfsm/SITUATIONS.md)(状況で入るもの)の両方を読み直し、新しいスキルが一度も言及されない・古いスキルがまだルーティングされる状態を残さない。**嘘をつくルーターは、無いルーターより悪い。** `SITUATIONS.md` 側に足したら、`SKILL.md` 冒頭のポインタが並べるトリガーにも足す — その文言が到達を決めている。

  どちらに置くかは **作業の起点になるか** だけで決める。ルーターは呼ばれた瞬間に全文がコンテキストに乗るので、起点にならないものを `SKILL.md` に置くと呼び出しのたびに重くなる。

- **`scripts/link-skills.sh` を走らせる** — ローカルのハーネススキルディレクトリへのシンボリックリンクを張り直す。追加・削除・改名のあと。
- **`pnpm format`** — CI が `format:check` で落とす。

## マニフェストの決まり

`plugin.json` の `skills` 配列は、既定の `skills/` スキャンに **追加** されるのが原則で、`marketplace.json` の `source` がマーケットプレイスのルート(`"./"`)に解決される場合に限り **置き換え** になる。昇格していないバケットがプラグインに載らないのはこの例外に乗っているからなので、`source` を変えるときは `deprecated/` や `in-progress/` が出荷対象に混ざらないか確認する。

`version` を両方のマニフェストから省く理由は `CLAUDE.md` が持つ。片方にでも書くと、その文字列が固定のキャッシュキーになって更新が止まる。

昇格していないバケットのスキルは、プラグインではなく利用側リポジトリでの `npx skills` による実体配置で配る(`skills-lock.json` に載り、`npx skills update` で追随できる)。`emdash/` がこの経路の主な利用者である。

## 改名するとき

ディレクトリ名と frontmatter の `name` は一致していなければならない(仕様の要求であり、検査もする)。両方を同時に変える。

そのうえで、名前を書いている場所すべてを追う: バケットの `README.md`、トップレベルの `README.md`、`plugin.json`、`ask-kjfsm`、そして**他のスキルの本文にある `/旧名` の文中呼び出し**。最後の1つは検査に出ない — `grep -rn '/旧名' skills/` で拾う。

改名後は `link-skills.sh` を走らせ、古い名前のシンボリックリンクを手で消す(スクリプトは張り直すだけで、消えた名前の後始末はしない)。リポジトリ側の `.claude/skills/` は `scripts/sync-project-skills.sh` が古い名前ごと張り直すので手当ては要らず、忘れれば検査 14. が落ちる。

## 昇格するとき

`in-progress/` や `misc/` から `engineering/` か `productivity/` へ移す。

ディレクトリを移動したら、あとは検査が要求してくる — トップレベル `README.md` への追加と `plugin.json` の `skills` 配列への登録。バケットの `README.md` は移動元から消し、移動先へ足す。昇格済みバケットとトップレベルの README は **ユーザー呼び出し型 / モデル呼び出し型** でグループ分けするので、正しい側へ入れる(昇格していないバケットの README はフラットなリストを使う)。掲載されているかは検査 4./5. が弾くが、**どちらのグループに入っているかは弾かない。**

そのスキルにユーザーが到達できるなら `ask-kjfsm` にも足す。作業の起点になるなら `SKILL.md`、フローの途中で状況が満たされたときだけ入るなら `SITUATIONS.md`。

## 退役させるとき

`deprecated/` へ移す。`scripts/link-skills.sh` と `scripts/sync-project-skills.sh` はどちらもこのバケットを除外するので、走らせ直せばローカルのハーネスからも `.claude/skills/` からも消える。

`plugin.json` とトップレベル `README.md` からは消える必要がある(検査が要求する)。`ask-kjfsm` からも消す。他のスキルがその名前を文中呼び出ししていないか `grep` で確かめる — 呼ばれたまま退役したスキルは、実行時に静かに何も起きない。
