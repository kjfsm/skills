# EmDash

[EmDash](https://docs.emdashcms.com) で作った Astro + Cloudflare のサイト専用のスキル群。EmDash を使わないプロジェクトでは何の役にも立たないので、plugin では promote していない。EmDash サイトのリポジトリ側で `npx skills` を使って個別に取り込む。

- **[building-emdash-site](./building-emdash-site/SKILL.md)** — コンテンツ取得、Portable Text のレンダリング、スキーマ設計、seed ファイル、サイト機能(menu・widget・検索・SEO・コメント・byline)。EmDash の作業はまずここから。
- **[creating-plugins](./creating-plugins/SKILL.md)** — hooks・storage・管理UI・API ルート・Portable Text ブロックタイプを使った EmDash プラグイン開発。
- **[emdash-cli](./emdash-cli/SKILL.md)** — コンテンツ管理・シード・型生成・ビジュアル編集フロー用の CLI コマンド。
- **[local-mcp-access](./local-mcp-access/SKILL.md)** — ローカル dev サーバーの MCP エンドポイント(`/_emdash/api/mcp`)をブラウザなしで叩く。`dev-bypass` + トークン API 経由での PAT 発行(MCP は bearer 専用でセッション Cookie が効かない)、コア MCP ツールが公開していないプラグイン管理設定の読み書き、`wrangler d1 execute` による D1 テーブルの直接参照。

EmDash 自体の最新ドキュメントは MCP サーバー(`https://docs.emdashcms.com/mcp`)の `search_docs` で引く。これらのスキルは EmDash 固有のパターンを扱うもので、API の一次情報源ではない。
