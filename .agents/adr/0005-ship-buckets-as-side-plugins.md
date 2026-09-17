# `emdash/` と `personal/` を、バケットごとの別プラグインとして同じマーケットプレイスから配る

[ADR 0002](./0002-ship-as-a-claude-code-plugin.md) で、配布は「昇格済み(`engineering/` + `productivity/`)を `kjfsm-skills` で配る / それ以外は配らない」の二択になった。`emdash/` と `personal/` はこの二択に収まらない。**全員には入れたくないが、入れる場所ははっきりしている** — `emdash/` は EmDash のサイトのリポジトリ、`personal/` は自分の端末である。

二択のあいだ、この2つは `npx skills` のコピーで届けていた。コピーは `npx skills update` を叩くまで古いまま残り、上流で改名・退役したスキルもコピー先に居座る(kjfsm-site で実際に起きた)。

## 決定

- 同じマーケットプレイス(`.claude-plugin/marketplace.json`)に、`kjfsm-emdash`(`./plugins/emdash`)と `kjfsm-personal`(`./plugins/personal`)を足す。
- 各プラグインのディレクトリは `.claude-plugin/plugin.json` と `skills/` だけを持ち、`skills/<名前>` は `skills/<バケット>/<名前>` へのシンボリックリンクにする。実体は今の場所から動かさない。
- `kjfsm-emdash` はサイトのリポジトリに `--scope project` で、`kjfsm-personal` は端末に既定のユーザースコープで入れる。
- `version` は持たない(0002 と同じく、コミットごとに更新が届く)。

## 却下した手

- **リポジトリを分ける。** 公式のマーケットプレイスは、同じリポジトリの別ディレクトリを指すプラグインを並べられる([Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces))。分ける理由が無い。
- **`source: "./"` のまま `strict: false` でスキルを並べる。** `strict: false` のエントリは、プラグインの `plugin.json` がコンポーネントを宣言していると競合して読み込めない。ルートの `plugin.json` は `kjfsm-skills` のスキルを宣言している。
- **`plugin.json` の `skills` に `../../skills/emdash/...` を書く。** インストール時にコピーされるのはプラグインのディレクトリだけで、外を指す相対パスは届かない。
- **実体を `plugins/<バケット>/skills/` へ移す。** バケットの規則(`skills/<バケット>/<名前>/`)と、それに乗っている検査・スクリプト・`npx skills` の配布がすべて動く。シンボリックリンクなら、マーケットプレイスの中を指す限りインストール時に実体がコピーされる([Plugins reference の Plugin caching and file resolution](https://code.claude.com/docs/en/plugins-reference))。

## この決定が生む不変条件

- `plugins/<バケット>/skills/` は、そのバケットのスキルと1対1のシンボリックリンクだけを持つ(検査 4b. と、`version` を含めたマニフェストの検査)。
- このリポジトリの `.claude/skills/` には、`emdash/` と `personal/` も張らない — プラグインを入れた人のセッションで同じスキルが2度並ぶ。昇格済みと同じ扱いである(検査 14.)。
- プラグインで入れたサイトや端末に、同じスキルの `npx skills` のコピーを残さない。

## 覆る条件

- Claude Code が、マーケットプレイスの中を指すシンボリックリンクの実体をコピーしなくなったら、実体を `plugins/` 側へ移すか、生成したコピーをコミットするかを決め直す。
- `emdash/` をこのリポジトリで開発しながら呼びたくなったら、このリポジトリの `.claude/settings.json` で `kjfsm-emdash` を有効にする(ただし呼ばれるのは push 済みの版である)。
