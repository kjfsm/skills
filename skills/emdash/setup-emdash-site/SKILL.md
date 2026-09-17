---
name: setup-emdash-site
description: 新しい EmDash サイトを Cloudflare Workers 向けに `create emdash` で作り、手元で動かして本番へ出すところまで進める。「EmDash のサイトを作りたい」「EmDash をセットアップ」「create emdash」「EmDash で新しいブログ/ポートフォリオを始める」、EmDash を初めてデプロイするときに使う。作ったあとの版上げは `updating-emdash` へ引き継ぐ。
---

# EmDash サイトをセットアップする

手順の一次情報源は公式の [Getting Started](https://docs.emdashcms.com/getting-started/) と [Cloudflare へのデプロイ](https://docs.emdashcms.com/deployment/cloudflare/) である。公式は Node + npm + starter で説明しているので、ここでは **Cloudflare + pnpm** に読み替えた形と、公式に書かれていない落とし穴だけを持つ。

## 手順

**手順ごとにコミットを1つ作る。** 雛形・名前の置き換え・スキルの差し替え・版上げが1つに混ざると、壊れたときにどれが原因か切り分けられず、テンプレートから何を変えたかも読めなくなる。コミットメッセージはリポジトリの慣習に合わせる(雛形の直後で慣習が無ければ、日本語で「何をしたか」を1行)。

### 1. ユーザーに聞く

次の4つはユーザーの世界の事実なので、推測で埋めずに聞く。テンプレートは推奨を付けて選ばせる。

| 聞くこと                 | 選択肢                                                                                                                                                                                        |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| テンプレート             | **`blog`(推奨)** / `portfolio` / `marketing` / `starter`([中身](https://github.com/emdash-cms/templates))。`blog` を推すのは、やることリストの判定済みの表が `blog-cloudflare` にしか無いから |
| プロジェクト名と置き場所 | ディレクトリ名。Worker・D1・R2 の名前にも使う                                                                                                                                                 |
| Cloudflare のアカウント  | `pnpm wrangler whoami` に複数出るならどれか                                                                                                                                                   |
| サンドボックスプラグイン | Workers の有料プランなら有効にできる。無料プランなら無効                                                                                                                                      |

**完了基準:** 4つが決まり、`node --version` が 22.16 以上、`pnpm wrangler whoami` がログイン済みを返す。

### 2. 雛形を作り、そのままコミットする

```bash
pnpm create emdash@latest <名前> --template cloudflare:<テンプレート> --pm pnpm --no-install --no-sandboxed-plugins --yes
# 有料プランで有効にするなら --sandboxed-plugins
cd <名前> && git init && git add -A && git commit -m "create emdash の雛形"
```

- **`--yes` を外すと、フラグで渡していない項目を対話で聞き、TTY の無いところでは止まる。** 逆に `--yes` 付きでは、省いた項目が黙って既定値(`cloudflare`・`blog`)で埋まる — 手順 1 で決めた値は全部フラグで渡す。`--template` は `cloudflare:<テンプレート>` の形で、プラットフォームも一緒に決める。
- **git は初期化されない。** 手を入れる前の雛形だけのコミットを作っておくと、あとで `git diff <そのコミット>` がそのまま「テンプレートからどこを変えたか」になる — `updating-emdash` がテンプレート由来のコードを直すときの足場になる。
- `.env` に `EMDASH_ENCRYPTION_KEY` が書かれる(gitignore 済み)。**パスワードマネージャーへ控えるようユーザーに伝える。** 失うと、暗号化して保存された設定値が読めなくなる。

### 3. 固定値の名前を置き換える

`wrangler.jsonc` の名前は、プロジェクト名に関係なく **テンプレートの固定値** で入る(`"name": "my-emdash-site"`、`database_name`、`bucket_name`)。そのままデプロイすると、同じアカウントで2つ目のサイトを作ったときに Worker・D1・R2 がぶつかり、**既存サイトを上書きする**。

- 3つとも `<名前>` 系に書き換える(例: `<名前>`、`<名前>`、`<名前>-media`)。
- アカウントが複数あるなら `account_id` を `wrangler.jsonc` に書く。書かないと、どのアカウントへ出るかが実行する環境(ログイン状態や `CLOUDFLARE_ACCOUNT_ID`)で変わる。

**完了基準:** `grep -n "my-emdash" wrangler.jsonc` が何も出さない。ここでコミットする。

### 4. 同梱スキルを kjfsm 版へ差し替える

雛形の `.agents/skills/` には公式版の `building-emdash-site`・`creating-plugins`・`emdash-cli` が入っており、`.claude/skills` はそこへのシンボリックリンクである。kjfsm/skills の `emdash/` バケットに同名のスキルがあり、公式に無い落とし穴はそちらが持つ。同じディレクトリ名なので、公式版を消してから入れる:

```bash
rm -rf .agents/skills/{building-emdash-site,creating-plugins,emdash-cli}
npx -y skills add kjfsm/skills --agent claude-code --yes \
  --skill building-emdash-site --skill creating-plugins --skill emdash-cli \
  --skill local-mcp-access --skill caching-emdash-site \
  --skill patching-emdash --skill updating-emdash
```

- 入れる一覧は [kjfsm/skills の `skills/emdash/`](https://github.com/kjfsm/skills/tree/main/skills/emdash) に並ぶものすべて。増えていたら足す。
- `--skill` は **1つずつ繰り返す**。カンマ区切りで渡すと、選択に失敗して一覧を出したまま終わる。
- 入れたスキルはコピーなので、更新は `npx skills update` で行う。

**完了基準:** `ls .claude/skills/` に上の名前が並び、`head -3 .claude/skills/building-emdash-site/SKILL.md` の description が日本語である。ここでコミットする。

### 5. 依存を入れて、最新に追いつかせる

`pnpm install` のあと、**`updating-emdash` スキルを呼び、「セットアップ直後」として進める。** テンプレートは依存の版だけが最新で、コードは数版前の書き方のまま残っているので、雛形のままでは新しい版の機能が効かない箇所がある。

コミットの切り方は `updating-emdash` の手順に従う(`pnpm install` で生まれた `pnpm-lock.yaml` は、その最初のコミットに含める)。

### 6. 手元で動かす

```bash
pnpm dev   # http://localhost:4321/
```

- 管理画面(`/_emdash/admin/`)の初回セットアップは **パスキーの登録をブラウザで行うので、ユーザーにやってもらう。** 公式の手順どおり、サイト名 → メールと名前 → パスキー → ダッシュボード。
- エージェントから管理 API や MCP を叩く必要があれば、`local-mcp-access` スキルを呼ぶ(dev 限定の抜け道で PAT を作る)。

**完了基準:** トップページが表示され、ユーザーが管理画面に入れた。

### 7. 本番へ出す

公式の [Cloudflare へのデプロイ](https://docs.emdashcms.com/deployment/cloudflare/) に沿う(`pnpm build` → `pnpm wrangler deploy`。D1 と R2 は初回デプロイで作られ、マイグレーションは最初のリクエストで当たる)。公式に無い注意:

- **本番の管理画面は、ユーザーが1人もいないあいだ、URL に最初に来た人が管理者を作れる。** 管理者作成の API はユーザー数しか見ていない。デプロイしたら **すぐに** ユーザーに本番の `/_emdash/admin/` で初回セットアップを済ませてもらう。先に閉じたいなら、デプロイ前に `setup-cf-access` スキルで管理画面に Cloudflare Access を掛ける。
- `EMDASH_ENCRYPTION_KEY` は `pnpm wrangler secret put EMDASH_ENCRYPTION_KEY` で入れる。値は手順 2 と同じく控えてもらう。
- `wrangler.jsonc` の cron は毎分(`* * * * *`)で入っている。頻度は `updating-emdash` のやることリストの「cron の頻度を決める」で決める。
- エッジキャッシュを入れるなら `caching-emdash-site` スキルを呼ぶ。
- `account_id` やカスタムドメインなど、デプロイのために `wrangler.jsonc` を変えたらコミットする。`dev` で生成型 `emdash-env.d.ts` や `worker-configuration.d.ts` が変わっていれば、それも別のコミットにする。

**完了基準:** `workers.dev` の URL でトップページが出て、ユーザーが本番の管理画面に入れた。カスタムドメインは、ここまで確かめてから公式の手順で足す。
