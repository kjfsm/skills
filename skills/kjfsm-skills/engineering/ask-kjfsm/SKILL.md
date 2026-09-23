---
name: ask-kjfsm
description: どのスキルやフローが自分の状況に合うかを尋ねる。このリポジトリのスキルを案内するルーター。
disable-model-invocation: true
---

# Ask kjfsm

スキルを全部覚えていなくていい。だから尋ねる。名前を思い出すだけなら `/kjfsm-skills:help-skills`。

**フロー** はスキルを通り抜ける一本の道筋である。ほとんどは1つの **メインフロー** に沿い、そこへ3つの **オンランプ** が合流する。残りはスタンドアロンである。

ここにあるのは **起点** — どのフローへ入るか。フローを走っている最中に、状況が満たされたときだけ入るものは [`SITUATIONS.md`](SITUATIONS.md) にある。開くのは次のとき: テストの土台が無い・信用できない、テストが多すぎる・振る舞いを変えないのに大量に落ちる、スタック固有の規律(React Router / Drizzle / D1)が要る、サインインの要る画面を人間なしで駆動したい、E2E のブラウザが用意できない、ロジックを変えない機械的な変更を大量にかける、Worker の経路が素通りで守られていない、マージがコンフリクトで止まった、スレッドが埋まった、プロセスではなく言葉が問題になった。

## メインフロー: アイデア → 出荷

1. **`/mattpocock-skills:grill-with-docs`** — インタビューでアイデアを研ぐ。**コードベースがある** ならここから始め、学んだことを `CONTEXT.md` と ADR に残す。コードベースがない → **`/mattpocock-skills:grill-me`**(同じ `/mattpocock-skills:grilling` プリミティブを走らせるが、記録は残さない)。
2. **会話だけでは決着しない問い**(状態、ビジネスロジック、実際に見ないと決まらない UI)がある → プロトタイプへ寄り道する。**`/mattpocock-skills:handoff`** で外へ出し、新しいセッションの **`/mattpocock-skills:prototype`** が使い捨てのコードで答え、`/mattpocock-skills:handoff` で持ち帰る。
3. 複数セッションにまたがるビルド → **`/mattpocock-skills:to-spec`**(スレッドをスペックに変換)、続けて **`/mattpocock-skills:to-tickets`** でトレーサーバレット方式のチケットに分割し、それぞれに **ブロッキングエッジ** を宣言させる。ローカルは `.scratch/<feature>/issues/` に1チケット1ファイル、実トラッカーではそのエッジがネイティブなブロッキングリンクになる。チケットごとに **`/kjfsm-skills:implement-and-review`** を起動し、**チケットごとにコンテキストをクリアする**。1セッションで収まる → その場で **`/kjfsm-skills:implement-and-review`**。

   **`/kjfsm-skills:implement-and-review`** は本家の **`/mattpocock-skills:implement`** を打つ行を示して止まり(ビルドはそこで **`/mattpocock-skills:tdd`** を駆動する)、ビルドが済んだら**`/kjfsm-skills:verification-loop`** で **クリーンラン**(記録されたゲートを中断なく1回で通し、変更した経路を実際に駆動して観測)を取り、コミット前に **`/kjfsm-skills:prune-comments`**(書いたコメントを削る)→ **`/kjfsm-skills:two-axis-review`**(Standards + Spec)を通し、PR を出して締める。単体でも使う: テストファーストで作る → `/mattpocock-skills:tdd`、動くか確かめるだけ → `/kjfsm-skills:verification-loop`、コメントを削るだけ → `/kjfsm-skills:prune-comments`、固定した基点でブランチや PR をレビュー → `/kjfsm-skills:two-axis-review`。

### コンテキストの衛生管理

手順1〜3は **1つの途切れないコンテキストウィンドウ** で進める — `/mattpocock-skills:to-tickets` の後まで compact もクリアもしない。こうしてグリリング・スペック・チケットが同じ思考の上に積み上がる。各 `/kjfsm-skills:implement-and-review` はその後、チケットをもとに新しいコンテキストから始める。

ここでの限界が **スマートゾーン** である — モデルが依然として鋭く推論できる範囲(最先端でおよそ12万トークン)。超えると、コンテキストが技術的に収まっていても推論の質は落ちる。`/mattpocock-skills:to-tickets` の前にこれへ近づいた → 押し進めず、`/mattpocock-skills:handoff` して新しいスレッドで続ける。

## オンランプ

- **バグや要望が積み上がった** → **`/mattpocock-skills:triage`**。イシューをトリアージロールに沿って進め、エージェントが着手できる状態にする。後で `/kjfsm-skills:implement-and-review` が拾う。**自分が作成していない** イシュー専用である — `/mattpocock-skills:to-tickets` が生成したチケットはすでに着手できるので、**トリアージしない**。

- **何かが壊れている** → **`/mattpocock-skills:diagnosing-bugs`**。一目では太刀打ちできないバグ、断続的なフレーク、2つの正常な状態の間のリグレッション向け。**タイトなフィードバックループ**(_この_ バグですでにレッドになる1つのコマンド)を手にするまで理論化しない。本当の発見が「このバグを封じ込めるシームがない」ことだった → **`/mattpocock-skills:improve-codebase-architecture`** に引き継ぐ。

- **巨大で霧に包まれた取り組み**(グリーンフィールド、1セッションに大きすぎる機能)→ **`/mattpocock-skills:wayfinder`**、最も認知負荷が高い。イシュートラッカー上に **意思決定チケット** の **共有マップ** を描き、**成果物ではなく意思決定** を生みながら1つずつ解決していく — 霧が晴れて道が見えるまで。1セッションで抱えられるアイデアなら `/mattpocock-skills:grill-with-docs`、抱えきれないならこちらで、より遅く濃密である。よく絞り込まれた機能には決して使わない。

  晴れたマップは **ビルドせず、引き継ぐ**: **`/mattpocock-skills:to-spec`** がリンクされた意思決定をビルド可能な計画へ畳み込み、メインフローに合流する。マップをそのまま `/kjfsm-skills:implement-and-review` へループさせると、この畳み込みを飛ばしてリンクされた詳細を捨てる。取り組みが実際には小さかったときに限り、直接 `/kjfsm-skills:implement-and-review` へ進む。

## コードベースの健全性

- **`/mattpocock-skills:improve-codebase-architecture`** — 手が空いたらいつでも実行し、エージェントが操作しやすいコードベースを保つ。**深化の機会** を洗い出し、1つ選ぶと _アイデアが生まれる_ ので、`/mattpocock-skills:grill-with-docs` でメインフローに持ち込む。これは候補を見つける調査であり、選んだものを設計する作業台が **`/mattpocock-skills:codebase-design`** である。
- **`/kjfsm-skills:tend-memory-files`** — セッション開始時にロードされる指示ファイル(`AGENTS.md`、`CLAUDE.md`、`CLAUDE.local.md`、`.claude/rules/`)を新規に書く、あるいは肥大化・陳腐化・矛盾を疑うたびに監査してトリムする。

## スタンドアロン

- **`/mattpocock-skills:grill-me`** — `/mattpocock-skills:grill-with-docs` と同じ容赦ないインタビューを、**コードベースがない** ときに。ステートレスで、ローカルには何も保存せず `CONTEXT.md` も作らない。
- **`/mattpocock-skills:prototype`** — デザイン上の問い1つに答える、小さく使い捨てのプログラム。答えだけ残してコードは消す。メインフロー手順2の寄り道だが、そこに限らない。
- **`/mattpocock-skills:research`** — 調べ物の力仕事を **バックグラウンドエージェント** に委ね、**一次情報源** に当たった引用付きのマークダウンを残す。読んでいる間も作業を続けられる。成果は `/mattpocock-skills:grill-with-docs` でメインフローに **持ち込む** — リサーチは思考の材料であって、代わりにはならない。
- **`/mattpocock-skills:teach`** — 現在のディレクトリをステートフルな作業スペースとして、複数セッションにわたり概念を学ぶ。
- **`/kjfsm-skills:sharpen-request`** — 「〜を整理したい」「〜を改善したい」のように、既にあるものを良くしたいのに何をもって良いかが言葉になっていないときに。作業に入る前に、1項目ずつ判定できる問いと止まる地点を持った指示へ研ぐ。何を作るか自体が決まっていないなら `/mattpocock-skills:grill-me` か `/mattpocock-skills:grill-with-docs`。
- **`/kjfsm-skills:writing-great-skills`** — スキルを書き、編集するための語彙と判断基準。公式が定める数値上限・frontmatter の仕様・名指しのアンチパターンは、同梱の `OFFICIAL.md` にある。

## 前提条件

**`/kjfsm-skills:setup-cf-app`** — リポジトリがまだ無いときの出発点。Cloudflare Workers のフルスタックアプリを標準ライブラリ構成で立ち上げ、`/kjfsm-skills:setup-repo` へ続く。

**`/kjfsm-skills:setup-repo`** — 最初のエンジニアリングフローの前に実行する、setup 系の **唯一の入口**。順序と依存はこれが持つ。**再実行してよい** — 済んだ工程は飛ばし、ずれだけを直す。

敷くのは **届き方の違う4つの層**。下ほど確実に効き、上ほど広く効く。

- **`/kjfsm-skills:setup-skills`**(毎セッション)— 他のスキルが前提とする設定一式。**検証ゲートの定義** もここ
- **`/kjfsm-skills:setup-rules`**(その glob を編集するとき)— `paths:` を持つ rule と絶対ルール。**敷く側** で、監査とトリムは `/kjfsm-skills:tend-memory-files`
- **`/kjfsm-skills:setup-ci`**(push / PR)— そのゲートを CI で回す。手元で通しても記録は残らない
- **`/kjfsm-skills:setup-hooks`**(該当する操作のたび)— 散文では守られないものを、効く範囲の広い層から順に決定的に弾く。**先回りしない**

この4層が敷く規約は本体の `AGENTS.md` にも載るが、重複ではない。**出力スタイルは(fork を除く)サブエージェントに届かない** — `/kjfsm-skills:two-axis-review` や `/mattpocock-skills:improve-codebase-architecture` が投げる子コンテキストに規約を効かせるのは、こちら側だからである。
