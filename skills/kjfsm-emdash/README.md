# EmDash

[EmDash](https://docs.emdashcms.com) で作った Astro + Cloudflare のサイト専用のスキル群。EmDash を使わないプロジェクトでは何の役にも立たないので、`kjfsm-skills` には昇格させず、別プラグイン `kjfsm-emdash` で配る。EmDash サイトのリポジトリで、プロジェクトのスコープに入れる:

```bash
claude plugin marketplace add kjfsm/skills --scope project
claude plugin install kjfsm-emdash@kjfsm --scope project
```

`npx skills` で入れたコピーが残っていれば消す — 同じスキルが2度並ぶ。

**これらのスキルは EmDash API の一次情報源ではない。** 一次情報源は公式ドキュメント <https://docs.emdashcms.com/>(MCP サーバー `https://docs.emdashcms.com/mcp` の `search_docs` でも引ける)。各スキルには、**公式に書かれていないこと**と**公式が実装と食い違っていること**だけを書く。公式を読めば分かる内容をここに複製しない —— 複製は必ず古くなるため。

<!-- catalog:begin -->

- **[building-emdash-site](./building-emdash-site/SKILL.md)** — AstroでEmDash CMSサイトを構築・カスタマイズする。ページ作成、コレクション定義、シードファイル作成、コンテンツクエリ、Portable Textのレンダリング、メニュー/タクソノミー/ウィジェットのセットアップ、デプロイ設定など、EmDash搭載Astroサイトに関するあらゆるタスクで使用する。APIの一次情報源は公式ドキュメントで、このスキルは公式に載っていない落とし穴と公式と食い違う挙動を扱う。
- **[caching-emdash-site](./caching-emdash-site/SKILL.md)** — EmDash + Cloudflare のサイトに Workers Cache でエッジHTMLキャッシュを入れる。本番のTTFBが遅い・しばらく経ってからの初回表示が遅いとき、D1 のリードレプリカや Worker の Placement を決めるとき、`routeRules` や `cacheCloudflare()` を設定するとき、キャッシュから外したい経路(検索・404・管理画面)があるとき、MCPや管理画面で更新したのにサイトに出ないとき、`Server-Timing` の `cache.hit`/`cache.miss` を読むときに使う。公式に無い落とし穴と、公式の素直な読みが実装と食い違う箇所だけを扱う。
- **[creating-plugins](./creating-plugins/SKILL.md)** — フック、ストレージ、設定、管理UI、APIルート、Portable Textブロックタイプを備えたEmDash CMSプラグインを作成する。EmDashプラグインのビルド・スキャフォールド・実装を求められた場合や、カスタムブロックタイプ・管理ページ・コンテンツフックなどのプラグイン機能を作成する場合にこのスキルを使用する。APIの一次情報源は公式ドキュメントで、このスキルは公式が扱っていないnpm配布形式と実地の落とし穴を扱う。
- **[emdash-cli](./emdash-cli/SKILL.md)** — コンテンツ、スキーマ、メディアなどを管理するためにEmDash CLIを使用します。実行中のEmDashインスタンスとコマンドラインからやり取りする必要があるとき——コンテンツの作成、コレクションの管理、メディアのアップロード、型の生成、CMS操作のスクリプト化など——にこのスキルを使用してください。コマンドの一覧は公式ドキュメントにあり、このスキルはエージェントから使う際の挙動の差分を扱います。
- **[local-mcp-access](./local-mcp-access/SKILL.md)** — ローカルのEmDash devサーバーのMCPエンドポイント(/_emdash/api/mcp)をブラウザなしで叩く(dev-bypass経由でPATを発行、Bearer専用)。`emdash-site-local`コネクタが401/未認証のときの復旧もこれ。プラグイン自身の管理設定をBlock Kitの`form_submit`/`block_action`経由で読み書きする方法、および`wrangler d1 execute`(ローカル/`--remote`)でMCPが公開していない情報を直接SQLで読む方法もカバーする。
- **[patching-emdash](./patching-emdash/SKILL.md)** — EmDash 本体(`emdash`・`@emdash-cms/*`)の不具合を、サイト側の pnpm パッチ(`patchedDependencies`)で直す。原因が node_modules の EmDash のコードにあると分かったとき、パッチを当てるか上げるか回避するか決めるとき、EmDash を上げて `ERR_PNPM_PATCH_FAILED` や版付きキーの不一致で install が落ちたとき、既存のパッチがまだ要るか確かめるときに使う。
- **[setup-emdash-site](./setup-emdash-site/SKILL.md)** — 新しい EmDash サイトを Cloudflare Workers 向けに `create emdash` で作り、手元で動かして本番へ出すところまで進める。「EmDash のサイトを作りたい」「EmDash をセットアップ」「create emdash」「EmDash で新しいブログ/ポートフォリオを始める」、EmDash を初めてデプロイするときに使う。作ったあとの版上げは `updating-emdash` へ引き継ぐ。
- **[updating-emdash](./updating-emdash/SKILL.md)** — `create emdash` で作った直後の EmDash サイトを、初回だけ最新の EmDash に上げ、テンプレートから引き継いだ古い書き方のコードを追いつかせる。`setup-emdash-site` から引き継いだとき、雛形のまま手を入れていないサイトでテンプレートの遅れを取り戻したいときに使う。2度目以降の版上げは扱わない。

<!-- catalog:end -->
