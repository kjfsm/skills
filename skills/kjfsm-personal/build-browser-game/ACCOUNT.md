# ログインとランキング

SKILL.md の手順 1 で入れると決めたときだけ読み、各手順にここの分を足す。入れないと決めたとき・あとで外すときは「外す」だけを読む。ログインそのもの(RP の組み方・ボタンの文言)は `/kjfsm-personal:connect-kjfsm-auth`、開発用の入口は `/kjfsm-skills:dev-bypass-sign-in`、共有 D1 は `/kjfsm-personal:kjfsm-shared-db` が持つ。

## 仕様(手順 3 に足す)

- プレイヤー名はアカウントに持つ。IdP の名前は Google のアカウント名で本名のことが多いので使わず、初回のログインで聞き、設定で変えられる
- 同じアカウントが入り直したら、古い接続を閉じる。閉じないと、自分のキャラを2つ並べて自分で自分を倒し、点を積める
- ランキングは通算の成績で並べ、同点は同じ順位にする

テストのシームに、名前を聞く関所(http 層)が加わる。

## 作る(SLICES.md のチケット 5)

### 名前を聞く関所

ログインした人の名前は、アプリ側のテーブル(`<slug>_profile`)にアカウントごと1つ持つ。ゲストの名前は、ログインを入れない場合と同じく端末に持つ。設定画面(`/settings`)では、ログインした人はアカウントの名前を、ゲストは端末の名前を変える。

関所は root の middleware の1か所に置く。middleware はアカウントを要求ごとに1回だけ引いて context に置き、名前の無いアカウントを、どのページからでも `/welcome?redirectTo=<元のパス>` へ送る。

- **`/welcome`・`/login`・`/api/*` は通す。** `/api/` まで止めると、ログアウトもできなくなる
- **パスは `.data` を落としてから見る**(→ `/kjfsm-skills:react-router-route-module`)。落とさないと、名前を決める送信そのものを関所が `/welcome` へ送り返す
- **loader ごとに判定を書かない。** 写し忘れたページが、ビルドもテストも通ったまま素通りになる。`/login` も含め、どのページもセッションを引き直さず context から読む
- **アカウントを引けなかったら、ゲストとして通す。** middleware が投げると全ページが 500 になる。テーブルより先にコードが出たときに、ログインした人の全ページが落ちる
- **ログインの戻り先(`callbackURL`)は元のページのままでよい。** 戻った直後の要求を middleware が捕まえる
- **`/welcome` は、ページ自身の middleware でログインを要求する。** loader と action に同じ判定を2回書かない

### 部屋へ誰かを渡す

対戦の WebSocket は React Router の外にあり、関所を通らない。

- **Worker がセッションを確かめ、userId と名前をヘッダで DO へ渡す。** ブラウザから届いた同名のヘッダは消す。日本語はヘッダにそのまま載らないので `encodeURIComponent` する。手元から送られた名前は、ゲストのときだけ使う
- **名前の無いアカウントはゲストとして扱い、userId を渡さない。** 渡すと、端末の名前のままランキングに積まれる
- **Origin を見て、他のサイトから張られた upgrade を断る。** upgrade には Cookie が付くので、断らないと本人の成績に勝負が載る
- **同じ userId の古い接続は、部屋の状態を手に取る前に閉じる。** 古い接続が最後の1人だと、抜けた時点で状態を捨てる処理が走り、手に取った状態が宙に浮く

### ランキング

- **名前は `coalesce(profile.name, stats.name)` で読む。** 勝負の結果は、部屋が入室時に持った名前で書かれる。stats の名前だけを見ると、名前を変える前から開いていたタブの勝負が終わった時点で、ランキングが古い名前に戻る。stats の名前に落とすのは、profile を持たない行(profile のテーブルより前の成績)のためである
- **同点は同じ順位にする。** 一覧を並び順の通し番号にして、自分の欄を「自分より点の高い人の数 + 1」にすると、同点の人の順位が食い違う。どちらも後者に揃える

### テスト

- **名前の無いアカウントで、全ページぶん「送られる」を撃つ。** `/api/auth` と `/login` が通ることも撃つ
- **開発用の入口の種の人を、名前を決めないまま使う人と、決める人に分ける。** http 層は D1 をファイルの中で共有するので、分けないとテストの順序に乗る
- **E2E は、種の人の名前を毎回まっさらに戻してから始める。** 開発用の入口で戻せるようにする。戻さないと1回目しか通らず、手元の2回目も CI のリトライも落ちる

完了: 初回のログインで名前を聞かれ、設定で変えるとトップにもランキングにも新しい名前が出る。上のテストが通り、同点の人が一覧でも自分の欄でも同じ順位になる。同じアカウントの入り直しで古い接続が閉じることを、bindings 層でテストした。

## 本番(DEPLOY.md に足す)

どれも本番(共有 D1・本番の IdP・Cloudflare)に触る。始める前に、この節の一覧をユーザーに見せ、まとめて確認を取る。

1. **PR を出す前に、secret を3本入れる。** 共有 D1 で slug が空いているかを読み(`kjfsm-shared-db` の手順 1)、`openssl rand -base64 32 | pnpm exec wrangler secret put BETTER_AUTH_SECRET --name <app>` を入れる。Worker がまだ無ければ、これが作る。残り2本は、本番の IdP にクライアントを作って入れる(`connect-kjfsm-auth` の手順 2。`redirect_uri` は `https://<app>.kjfsm.net/api/auth/callback/kjfsm`)
2. **PR の本文に、最初のビルドが共有 D1 へ流すマイグレーションの SQL を載せる。** マージのあとは、確認なしに流れる
3. **マイグレーションが流れる前に、戻り先と比較の基準を控える。** 共有 D1 の Time Travel の bookmark と、`<slug>_` の外のスキーマである(`kjfsm-shared-db` の「スキーマを変える」)。Workers Builds を繋いだあとなら、マージの前に控える。auto mode ではスキーマを読む `wrangler d1 execute --remote` が止められることがある。そのときは別の手で読みに行かず、コマンドを人間に渡す。人間が控えないなら、流れる SQL の全文を読み、触れる名前が全部 `<slug>_` で始まることを確かめてから進める
4. **Workers Builds のコマンドを、ログインの分だけ足す。** Build command は `pnpm run build && pnpm run check:door`(開発用の入口が本番の成果物に残っていないことの検査)、Deploy command は `pnpm db:migrate:remote && npx wrangler deploy` にする。マイグレーションは必ずデプロイより先に置く
5. **確かめる。** ビルドのログでマイグレーションが流れたこと、控えたスキーマと比べ直して `<slug>_` の外が変わっていないことを見る。本番で `/dev/bypass` が 404 を返すこと、`/login` への POST が `auth.kjfsm.net/api/auth/oauth2/authorize` へ正しい `client_id`・`redirect_uri`・`S256` で送ることも見る。その URL を叩くと、IdP のサインイン画面へ 302 で送られる(`invalid_client` にならない)
6. **人間に渡す。** IdP を通したログインの一巡は、Google と同意画面があるので人間にしか通れない。iOS のホーム画面(standalone)から開いたときのログインは、未確認であることを伝える

## 外す

遊んでみて要らないと分かったら、コードとドキュメントから外す PR と、本番に残ったものの片付けを分ける。手順 2 で最初から入れない場合も、1〜4 は同じである。

1. **`wrangler.jsonc` の `secrets.required` は、空の配列で残す。** 消すと `wrangler types` が手元の `.dev.vars` から古い secret を型に拾う。手元の型チェックは通り、`.dev.vars` の無い CI で `cf-typegen:check` が落ちる。`wrangler types --check --env-file /dev/null` で確かめる
2. **`.claude/rules/db.md` を消すなら、生成物の節を別の rule に移す。** `worker-configuration.d.ts` と `.react-router/` は D1 を外しても生成物のままなので、`paths:` を `wrangler.jsonc` と `worker-configuration.d.ts` に向けた rule に残す
3. **`.worktreeinclude` から `.dev.vars` を外す。** 読む側がいないのに、新しい worktree へ古い secret を写し続ける
4. **ログインのテストファイルを消す前に、ログインと無関係なテストを移す。** ゲストが設定で名前を変えるテストのように、残す画面を守るものが混ざっている
5. **マージの前に、人間が Workers Builds のコマンドを `pnpm run build` と `npx wrangler deploy` に戻す。** `check:door` と `db:migrate:remote` を消したまま古いコマンドで走ると、ビルドが落ちてデプロイされない
6. **マージのあと、本番に残ったものを片付ける。** 共有 D1 の `<slug>_` の表と `d1_migrations_<slug>`、IdP のクライアント、Worker の secret 3本である。一覧を見せて確認を取ってから消す(`kjfsm-shared-db` の「抜ける」)。PR 本文に一覧を書いておく。リポジトリからは消えるので、控えないと辿れなくなる
