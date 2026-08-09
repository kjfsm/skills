# kjfsm's Skills

Claude Code、Codex、その他 Agent-Skills 標準に準拠したハーネス向けのエージェントスキル(スラッシュコマンドと振る舞い) — 雰囲気で書くコーディングではなく、実務のエンジニアリングのために使う。

[mattpocock/skills](https://github.com/mattpocock/skills) を日本語訳し、kjfsm 向けに調整した独立フォーク。

これらのスキルは小さく、手を加えやすく、組み合わせやすいように設計されている。どのモデルでも動作する。

## インストール

### いちばん手っ取り早い方法: Claude に貼る

Claude Code に次の1行を貼れば、あとはエージェントが[セットアップ手順](./setup.md)を読んでインストールまで済ませる:

```
Fetch https://raw.githubusercontent.com/kjfsm/skills/main/setup.md
```

自分の手で入れたい場合は、以下から選ぶ。

### 選択肢 A: ローカルのハーネススキルディレクトリへシンボリックリンクする

リポジトリのルートから:

```bash
scripts/link-skills.sh
```

これは(`deprecated/` を除く)すべてのスキルを `~/.claude/skills` と `~/.agents/skills` にシンボリックリンクする。各エントリはこのリポジトリへのシンボリックリンクなので、`git pull` すればインストール済みのスキルは常に最新の状態を保つ。スキルを追加・削除・改名したあとは、このスクリプトを再実行すること。

### 選択肢 B: Claude Code プラグインとしてインストールする

昇格済みのスキル集合(`engineering/` + `productivity/`)は、ネイティブな [Claude Code プラグイン](https://code.claude.com/docs/en/plugins)としても出荷されている:

```
/plugin marketplace add kjfsm/skills
/plugin install kjfsm-skills@kjfsm
```

またはシェルから:

```bash
claude plugin marketplace add kjfsm/skills
claude plugin install kjfsm-skills@kjfsm
```

### 選択肢 C: `npx skills` でコピーとして入れる

スキルの **実体** を手元に置きたい場合(このリポジトリを clone せずに使いたい、プロジェクトに同梱したい、など):

```bash
npx -y skills add kjfsm/skills
```

- 何が入るかを先に見るには `--list`、個別に選ぶには `--skill tdd,two-axis-review`、対象ハーネスを決め打ちするには `--agent claude-code` を付ける。
- プロジェクト内で実行するとそのプロジェクトのスキルディレクトリ(`.claude/skills/` など)へ**実ファイルとしてコピー**され、`skills-lock.json` が作られる。`--global` を付けるとユーザーレベル(`~/.claude/skills`)に入る。
- コピーなので `git pull` では追随しない。更新は `npx skills update`、`skills-lock.json` からの復元は `npx skills experimental_install`。
- この CLI はリポジトリ全体を走査するため、`--skill '*'` は `deprecated/` や `in-progress/` まで含めて全スキルを入れてしまう。昇格済みの集合だけが欲しいなら選択肢 B を使うか、`--skill` で名前を挙げること。

**3つの方法は併用しない。** 同じスキルが2系統で入ると、スラッシュコマンドが重複し、常時読み込まれる description も二重に数えられる。このリポジトリを開発するなら選択肢 A、使うだけなら選択肢 B を選ぶ。

どの方法でも、他のエンジニアリング系スキルを使う前にリポジトリごとに一度 **`/setup-skills`** を実行すること。これは次のことを行う:

- どのイシュートラッカーを使うか尋ねる(GitHub、Linear、ローカルファイル)
- チケットをトリアージするときに適用するラベルを尋ねる(`/triage` がラベルを使う)
- 作成するドキュメントの保存先を尋ねる

## これらのスキルが存在する理由

コーディングエージェントで繰り返し起きる4つの失敗モードと、各スキルが当てる対処法:

**エージェントが望んだ通りに動かなかった。** ミスアライメントはソフトウェア開発で最もよくある失敗モードである — エージェントが理解してくれたと思っていたのに、できあがったものを見て実はそうでなかったと気づく。対処法は **グリリングセッション**: 作り始める前に、作ろうとしているものについて詳細な質問をエージェントにさせることである。[`/grill-me`](./skills/productivity/grill-me/SKILL.md)(コードベースなし)と [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md)(コードベースあり)を参照。

**エージェントが冗長すぎる。** 共有された語彙がなければ、エージェントは1語で済むところに20語を使い、物事の名付け方も一貫しなくなる。対処法は、プロジェクトの専門用語を解読するドキュメントである — [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md) に組み込まれており、グリリングをしながら `CONTEXT.md` と ADR を保守する。

**コードが動かない。** 何を作るか意識をそろえていても、フィードバックを受け取れずに手探りで進むエージェントは質の悪いコードを生む。対処法は、いつものひとそろいのフィードバックループ — 静的型付け、ブラウザへのアクセス、自動テスト — であり、レッド・グリーン・リファクタリングのループが仕事の大半を担う。[`/tdd`](./skills/engineering/tdd/SKILL.md) と [`/diagnosing-bugs`](./skills/engineering/diagnosing-bugs/SKILL.md) を参照。作り終えた変更が本当に動くかは [`/verification-loop`](./skills/engineering/verification-loop/SKILL.md) が締める — 記録されたゲートを中断なく1回で通し、変更した経路を実際に駆動して観測する。

**コードベースが泥団子になった。** エージェントはコーディングを劇的に加速させるが、それはソフトウェアのエントロピーも加速させる。対処法は、あらゆる層でコードの設計を気にかけることである — [`/to-spec`](./skills/engineering/to-spec/SKILL.md)(スペックを書く前にどのモジュールが影響を受けるか問いを立てる)と [`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md)(コードベースが泥団子へと漂流しつつあるのを定期的に捉える)を参照。

## リファレンス

これらは1つの軸で分かれる — 誰がそれを呼び出せるか。**ユーザー呼び出し型** のスキルは、あなたが入力したとき(例: `/grill-me`)だけ到達できる。その役目はオーケストレーションである。**モデル呼び出し型** のスキルは、あなたが呼び出すこともできるし、タスクに合致すればエージェントが自動的に手を伸ばすこともできる。それらは再利用可能な規律を保持する。ユーザー呼び出し型のスキルはモデル呼び出し型のスキルを呼び出せるが、別のユーザー呼び出し型のスキルは決して呼び出せない。

### Engineering

日々のコード作業のためのスキル。

**ユーザー呼び出し型**

- **[ask-kjfsm](./skills/engineering/ask-kjfsm/SKILL.md)** — どのスキルやフローが自分の状況に合うかを尋ねる。このリポジトリのスキルを案内するルーター。
- **[grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md)** — プロジェクトのドメインモデルも構築するグリリングセッション。用語を研ぎ澄まし、`CONTEXT.md` と ADR をその場で更新する。
- **[triage](./skills/engineering/triage/SKILL.md)** — トリアージロールのステートマシンに沿ってイシューを進める。
- **[improve-codebase-architecture](./skills/engineering/improve-codebase-architecture/SKILL.md)** — コードベースをスキャンして深化の機会を見つけ、視覚的な HTML レポートとして提示し、選んだものについてグリリングする。
- **[setup-skills](./skills/engineering/setup-skills/SKILL.md)** — このリポジトリをエンジニアリング系スキル向けに設定する(イシュートラッカー、トリアージラベル、ドメインドキュメントの配置)。他のエンジニアリング系スキルを使う前にリポジトリごとに一度実行する。
- **[tend-memory-files](./skills/engineering/tend-memory-files/SKILL.md)** — セッション開始時にロードされる指示ファイル(`CLAUDE.md`、`.claude/rules/`)を新規に書く、または監査してトリムする。行数の目安に収め、具体的で矛盾のない指示だけを残す。
- **[to-spec](./skills/engineering/to-spec/SKILL.md)** — 今の会話をスペックに変換し、イシュートラッカーへ公開する。インタビューはせず、すでに話し合った内容をまとめるだけ。
- **[to-tickets](./skills/engineering/to-tickets/SKILL.md)** — どんな計画・スペック・会話も、それぞれがブロッキングエッジを宣言するトレーサーバレット方式のチケットの集合へ分割する — ローカルファイルへのテキストとして、あるいは実際のトラッカー上のネイティブなブロッキングリンクとして書かれる。
- **[implement](./skills/engineering/implement/SKILL.md)** — スペックやチケットの集合が記述する作業をビルドする。事前に合意したシームで `/tdd` を駆動し、`/verification-loop` でクリーンランを取り、コミット前に `/two-axis-review` で締めくくる。
- **[wayfinder](./skills/engineering/wayfinder/SKILL.md)** — 1つのエージェントセッションには収まらない巨大な作業のかたまりを、イシュートラッカー上の調査チケットの共有マップとして計画する — 目的地までの道が明らかになるまで、1つずつ解決していく。

**モデル呼び出し型**

- **[prototype](./skills/engineering/prototype/SKILL.md)** — デザイン上の問いに答えるための使い捨てプロトタイプを作る — 状態やロジックの問いには実行可能なターミナルアプリ、または1つのルートから切り替えられる何通りかの根本的に異なる UI バリエーション。
- **[diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md)** — 手強いバグやパフォーマンスのリグレッションのための規律ある診断ループ: 再現 → 最小化 → 仮説立て → 計測 → 修正 → リグレッションテスト。
- **[research](./skills/engineering/research/SKILL.md)** — 信頼度の高い一次情報源に対してある問いを調査し、その発見を引用付きのマークダウンファイルとしてリポジトリに残す。バックグラウンドエージェントとして実行される。
- **[tdd](./skills/engineering/tdd/SKILL.md)** — レッド・グリーン・リファクタリングのループによるテスト駆動開発。機能を作るのもバグを直すのも、一度に1つの垂直スライスずつ進める。
- **[create-tests](./skills/engineering/create-tests/SKILL.md)** — Cloudflare Workers のプロジェクトで、テストが1本も無いところから作り始める。何が壊れると困るかから始め、node と workerd の2プロジェクトに分けて、依存の内側から積む。
- **[rebuild-tests](./skills/engineering/rebuild-tests/SKILL.md)** — Cloudflare Workers のテストスイートを立て直す。vitest.config の複雑さを `vi.mock` の本数の問題として読み替え、消す前に棚卸しし、履歴から復元し、書いたテストは壊して実効性を確かめる。
- **[domain-modeling](./skills/engineering/domain-modeling/SKILL.md)** — プロジェクトのドメインモデルを能動的に構築し研ぎ澄ます — 用語集に照らして用語に異議を唱え、エッジケースのシナリオでストレステストし、`CONTEXT.md` と ADR をその場で更新する。
- **[codebase-design](./skills/engineering/codebase-design/SKILL.md)** — 深いモジュールを設計するための共有された規律と語彙: 小さなインターフェースの裏に多くの振る舞いを隠し、きれいなシームに置き、そのインターフェースを通してテスト可能にする。
- **[delegation](./skills/engineering/delegation/SKILL.md)** — 作業をどこで走らせるかの共有された語彙: 出力が大量で後から読み返さない作業をサブエージェントの子コンテキストへ押し出し、探索や事実確認は下位モデルに、設計判断は上位モデルに回す。
- **[verification-loop](./skills/engineering/verification-loop/SKILL.md)** — 変更が本当に動くことを **クリーンラン** で確かめる: 記録された検証ゲートを中断なく1回で通し、そのうえで変更した経路を実際に駆動して観測の証拠を残す。
- **[two-axis-review](./skills/engineering/two-axis-review/SKILL.md)** — 固定した基点からの差分に対する二軸レビュー: **Standards**(リポジトリのコーディング標準に従っているか、加えて Fowler のコードスメルの基準を満たしているか)と **Spec**(元になったイシュー/PRD を忠実に実装しているか)。互いを汚染しないよう並列のサブエージェントとして実行する。
- **[resolving-merge-conflicts](./skills/engineering/resolving-merge-conflicts/SKILL.md)** — 進行中の git マージやリベースのコンフリクトを、ハンクごとに、双方の一次情報源にたどれる意図に基づいて解決し、そのうえで操作を完了させる — `--abort` は決して使わない。
- **[react-router-route-module](./skills/engineering/react-router-route-module/SKILL.md)** — React Router（framework mode）の route module に何をどの export へ置くかの規律: 認可の強制点は `middleware`（loader と action の両方の手前を通る）、レイアウトが持つ値は `<Outlet context>` で配る。
- **[where-to-write-what](./skills/engineering/where-to-write-what/SKILL.md)** — コメント・JSDoc・コミットメッセージ・PR 本文・ADR のどこに何を書くかのルーティング規律: コメント=コードから読めない制約と理由、JSDoc=型に出ない契約、コミット=何をなぜ変えたか、PR=レビューに要る文脈。

### Productivity

コードに限らない、一般的なワークフローツール。

**ユーザー呼び出し型**

- **[grill-me](./skills/productivity/grill-me/SKILL.md)** — 決定木のすべての枝が解決するまで、計画やデザインについて容赦なくインタビューされる。
- **[handoff](./skills/productivity/handoff/SKILL.md)** — 今の会話を引き継ぎ用のドキュメントへ圧縮し、別のエージェントが作業を継続できるようにする。
- **[teach](./skills/productivity/teach/SKILL.md)** — 現在のディレクトリをステートフルな教育用ワークスペースとして使い、複数セッションにわたってユーザーに新しいスキルや概念を教える。

**モデル呼び出し型**

- **[writing-great-skills](./skills/productivity/writing-great-skills/SKILL.md)** — スキルを書く・直すための判断基準と、公式が定める仕様: 予測可能性・情報階層・段階的開示・先導語・失敗モードの語彙に、公式の数値上限と frontmatter の規則をまとめた `OFFICIAL.md` が付く。
- **[grilling](./skills/productivity/grilling/SKILL.md)** — 決定木のすべての枝が解決するまで、計画・決定・アイデアについてユーザーに容赦なくインタビューする。`grill-me` と `grill-with-docs` の裏にある再利用可能なループ。

### その他のバケット

昇格していない(プラグインへのエントリなし、上記の README への掲載もなし) — 中身については各バケット自身の `README.md` を参照:

- [`skills/misc/`](./skills/misc/README.md) — 残してあるがほとんど使われない
- [`skills/emdash/`](./skills/emdash/README.md) — [EmDash](https://docs.emdashcms.com) CMS のサイト専用。EmDash を使わないプロジェクトでは無価値
- [`skills/personal/`](./skills/personal/README.md) — この端末固有のセットアップに紐づく
- [`skills/in-progress/`](./skills/in-progress/README.md) — まだ出荷準備が整っていない下書き
- [`skills/deprecated/`](./skills/deprecated/README.md) — もう使われていない
