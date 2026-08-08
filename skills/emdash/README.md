# EmDash

[EmDash](https://docs.emdashcms.com) で作った Astro + Cloudflare のサイト専用のスキル群。EmDash を使わないプロジェクトでは何の役にも立たないので、plugin では promote していない。EmDash サイトのリポジトリ側で `npx skills` を使って個別に取り込む。

**これらのスキルは EmDash API の一次情報源ではない。** 一次情報源は公式ドキュメント <https://docs.emdashcms.com/>(MCP サーバー `https://docs.emdashcms.com/mcp` の `search_docs` でも引ける)。各スキルには、**公式に書かれていないこと**と**公式が実装と食い違っていること**だけを書く。公式を読めば分かる内容をここに複製しない —— 複製は必ず古くなるため。

- **[building-emdash-site](./building-emdash-site/SKILL.md)** — サイト構築時の落とし穴、公式ドキュメントが実装とズレている箇所(画像フィールドの `src`、`orderBy`、`cacheHint`、`supports`)、公式に一覧のない `emdash/ui` コンポーネント。EmDash の作業はまずここから。
- **[creating-plugins](./creating-plugins/SKILL.md)** — 公式が扱っていない npm 配布の `format: "standard"` ディスクリプタ形式と、Block Kit の未文書化ブロック。
- **[emdash-cli](./emdash-cli/SKILL.md)** — エージェントから叩くときの自動公開の挙動、`--published`、Portable Text ⇄ markdown の変換仕様。
- **[local-mcp-access](./local-mcp-access/SKILL.md)** — ローカル dev サーバーの MCP エンドポイント(`/_emdash/api/mcp`)をブラウザなしで叩く。`dev-bypass` + トークン API 経由での PAT 発行(MCP は bearer 専用で、公式の「セッション Cookie も使える」は実装と食い違う)、コア MCP ツールが公開していないプラグイン管理設定の読み書き、`wrangler d1 execute` による D1 テーブルの直接参照。
