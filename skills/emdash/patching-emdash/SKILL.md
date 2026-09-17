---
name: patching-emdash
description: EmDash 本体(`emdash`・`@emdash-cms/*`)の不具合を、サイト側の pnpm パッチ(`patchedDependencies`)で直す。原因が node_modules の EmDash のコードにあると分かったとき、パッチを当てるか上げるか回避するか決めるとき、EmDash を上げて `ERR_PNPM_PATCH_FAILED` や版付きキーの不一致で install が落ちたとき、既存のパッチがまだ要るか確かめるときに使う。
---

# EmDash にパッチを当てる

> pnpm のパッチ機能そのものは公式にある: [`pnpm patch`](https://pnpm.io/cli/patch) /
> [`patchedDependencies`](https://pnpm.io/settings#patcheddependencies)。

パッチは **最後の手段** である。当てた瞬間から、EmDash を上げるたびに作り直す維持費が発生し、しかも当たらなくなったことに気づけるのは install が落ちたときだけになる。だから手順の大半は「当てずに済むか」の判定に使う。

## 手順

### 1. 原因がどのファイルの何行目かを特定する

「EmDash のバグっぽい」では足りない。実行時に読まれているファイルと行まで絞る。

- **実行時に読まれるのは `dist/` である。** パッケージには `src/` も同梱されているが、`package.json` の `exports` が `dist/*.mjs` を指している。どちらが読まれるかは `exports` で確かめる(`./auth/providers/*-admin` のように `src/*.tsx` を直接指すエントリもある)。
- 上流のリポジトリでのパスは `packages/core/src/...`(`emdash`)、`packages/admin/...` のように読み替える。
- 本番でしか通らない経路かを確かめる。Cloudflare Access 認証は dev では passkey へ切り替わるので、`handleExternalAuth` などは **ローカルで再現できない**。

**完了基準:** 直したい挙動を生んでいる `dist/` のファイルと行を1つ以上名指しできる。

### 2. 当てずに済むかを、この順で確かめる

上から順に当たり、どれかで解決するならパッチを書かない。

1. **上流で直っているか。** `gh release list -R emdash-cms/emdash` と、該当ファイルの `main` を読む(`gh api repos/emdash-cms/emdash/contents/<path> -H "Accept: application/vnd.github.raw"`)。直っているなら **上げる**。
2. **上流に issue / PR があるか。** `gh search issues <語> -R emdash-cms/emdash` を、語を変えて数回。複数語の検索は全語一致なので、1〜2語で引く。検索 API は1分30回で止まる — 止まったら `gh api rate_limit` で解除時刻を見る。進行中の PR があるなら、その差分をパッチの下敷きにする。
3. **サイトの設定か自前のコードで避けられるか。** `astro.config.mjs` の EmDash / Astro の設定、`src/middleware.ts`、自前のプラグイン。避けられるなら、そちらの方が上げたときに壊れない。

**完了基準:** 3つそれぞれについて「だめだった理由」を1行ずつ言える。1つでも「避けられる」なら、パッチを作らずに終える。

### 3. 差分を最小にして書く

- 直すのは原因の行だけ。周辺の整理や上流への提案を混ぜない — 上げるたびに作り直すのは、この差分の全行である。
- 直した行の直前に、`/** [patched: <リポジトリ名>] <なぜ> */` の1行コメントを置く(既存パッチの慣習)。`dist/` は英語のビルド成果物なので英語で書く。
- 同じファイルがすでに import している関数を使う。`dist/` のチャンク名(`session-user-CbnMMwk6.mjs` など)は版ごとに変わるので、新しい import を足すと上げたときに壊れる。

### 4. パッチファイルを作る

`pnpm patch <pkg>@<版>` は、同じ版が peer の組み合わせ違いで複数入っていると **どれを直すかを対話で選ばせ、TTY の無いところでは `ERR_PNPM_PATCH_CANCELED` で止まる**(`ls node_modules/.pnpm | grep '^emdash@<版>'` が2行以上なら当たる)。エージェントからは手で作る:

```bash
P=$(readlink -f node_modules/<pkg>)           # 例: node_modules/emdash
W=<スクラッチの作業ディレクトリ>
mkdir -p "$W/a/dist/<dir>" "$W/b/dist/<dir>"
cp "$P/dist/<file>" "$W/a/dist/<dir>/"
cp "$P/dist/<file>" "$W/b/dist/<dir>/"
# $W/b/dist/<file> を編集する
(cd "$W" && git diff --no-index a/dist/<file> b/dist/<file>) \
  | sed -e 's#a/a/dist#a/dist#; s#b/b/dist#b/dist#' > patches/<name>@<版>.patch
```

`<name>` は pnpm の命名に合わせる(`emdash@0.38.0.patch`、スコープ付きは `@emdash-cms__admin@0.38.0.patch`)。パスはパッケージのルートからの相対(`a/dist/...`)にする。

`pnpm-workspace.yaml` の `patchedDependencies` に **版付きのキー** で足す(`emdash@0.38.0: patches/emdash@0.38.0.patch`)。版なしのキーは、上げたときに黙って別の版へ当たろうとする。

**完了基準:** `pnpm install` が通り、`grep -n "patched: <リポジトリ名>" node_modules/<pkg>/dist/<file>` が当たる。`pnpm-lock.yaml` の `patchedDependencies` にハッシュが増えている。

### 5. 検証する

1. リポジトリの検証ゲート(型チェック・lint・テスト)。
2. **`pnpm build` の成果物に入っているかを grep する。** サーバー側のコードは `dist/server/` の1ファイルへまとめ直されるので、元のファイル名では探せない。直した行の文字列で `grep -rl` する。
3. **挙動を観測する。** dev で通る経路なら dev で。本番でしか通らない経路なら、デプロイ後に本番で **前後を比べる**。Cloudflare の集計(GraphQL の `kvOperationsAdaptiveGroups` など)やログは、反映まで数分遅れる — 0 件でもすぐに「効いた」と判断しない。決め手が要るなら、ダッシュボードでパッチ前の版へ一時的にロールバックして同じ操作をし、差を見る(終わったら必ず戻す)。

**完了基準:** 3 で、パッチありとなしの違いを数字か観測で示せる。示せないなら、PR 本文に「未観測」と書き、デプロイ後に何を見るかを残す。

### 6. 記録して、上流へ返す

- **`patches/README.md` の台帳に1行足す。** 列は「パッチ・当て始めた日・対象の版・直していること・上流の状況・外せる条件」。無ければ作る。上げるときに1本ずつ判定する材料はここに集める — コミットログに散らばると、パッチが2本を超えたあたりで見直しが漏れる。症状の数字や前後比較のように表に収まらないものは、同じファイルの節に書く。
- コミットメッセージには **なぜ当てたか** を書く(台帳は今の状態、コミットは経緯)。
- 上流への issue / PR は外部への投稿なので、出す前にユーザーに確かめる。既存の近い issue(同じ症状の読み取り版など)があれば番号を添える。出したら台帳の「上流の状況」を更新する。

**完了基準:** 台帳にそのパッチの行があり、「外せる条件」が上流のコードで判定できる形で書けている。

## EmDash を上げるとき

版付きキーは新しい版に当たらないので、install の前に `patches/README.md` の台帳を上から1本ずつ判定する。

1. **上流で直ったか。** 台帳の「外せる条件」を、新しい版の該当ファイルで確かめる。直っていれば、パッチファイル・`patchedDependencies` のキー・台帳の行を消す。
2. **直っていなければ作り直す。** 手順 4 を新しい版の `dist/` に対して行い、ファイル名とキーの版を上げ、台帳の「対象の版」と「上流の状況」を更新する。**中身が同じでも行番号とチャンク名が動くので、古いパッチの版だけ書き換えても当たらない**(`ERR_PNPM_PATCH_FAILED`)。
3. コミットメッセージに、パッチごとに「直っていなかったので作り直した / 直ったので外した」を1行ずつ書く。

**完了基準:** 台帳のすべての行の「対象の版」が新しい版になっているか、行ごと消えている。

## 同じパッチを別の EmDash サイトへ持っていくとき

**そのサイトが同じ経路を通るかを先に確かめる。** 認証方式・ストレージ・キャッシュの設定が違えば、同じ行があっても実行されない(例: Access 認証の毎リクエスト書き込みは、passkey や OAuth のサイトでは起きない)。通らない経路へのパッチは効果が無いまま、上げるたびの維持費だけが残る。
