---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、Free プランに収まる標準構成(Vite の React SPA + Hono の API Worker)で立ち上げる。手元のテンプレートを写して名前を替え、無ければ公式テンプレートから組む。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# 標準構成のアプリを立ち上げる

手元のテンプレート `kjfsm/cf-workers-free-template` を写して名前を替える。テンプレートは標準構成を組み終え、`/kjfsm-skills:setup-repo` も済ませた状態で保ってある。**ここでは組み直さない** — 構成を変えたいときはテンプレートを直し、次に写すアプリから効かせる。

## 1. 決める

写す前に2つだけ聞く。推測で埋めない — あとから替えると、スキーマとマイグレーションを作り直す。

- **認証先** — kjfsm の共通 IdP(kjfsm-auth)か、それ以外(Google などの social、email/password)か
- **DB** — 共有 D1(`kjfsm-shared-db`)に相乗りするか、このアプリだけの D1 を作るか

## 2. テンプレートを探す

`~/github/kjfsm/cf-workers-free-template` を見る。次のどれかに当たったら写さず、**`/kjfsm-skills:scaffold-cf-app` を呼び、手順1の2つの答えを渡す**:

- そのディレクトリが無い
- 認証先が kjfsm-auth 以外 — テンプレートは kjfsm-auth に固定されていて、差し替える手順を持たない

あれば `git -C <テンプレート> fetch` し、`main` が `origin/main` より遅れていたら pull してから写す。手元の古い版を写すと、テンプレートで直した不具合が戻る。

## 3. 写す

```bash
git clone ~/github/kjfsm/cf-workers-free-template <名前>
git -C <名前> remote remove origin
```

`cp -r` ではなく clone にする。履歴を持ち込むので、起点(C3 の生成物そのまま)からの差分を `git diff <起点>` で読め、公式の更新を取り込むときの比較元が残る。gitignore 済みの `node_modules`・`dist`・`.dev.vars` も持ち込まない。

**依存はここで上げない。** 上げるならテンプレート側で上げ、検証を通してから写す — このアプリだけで上げると、次に写すアプリとの差が理由無く開く。

## 4. 名前を替える

テンプレートの README の「フォークしたら」に沿う。手順1で「このアプリだけの D1」を選んだなら、続けて「新規 D1 に切り替える」に沿う。README の手順をここへ写さない — テンプレートと一緒に直るのは README だけである。

slug の空きは `/kjfsm-personal:kjfsm-shared-db`、IdP のクライアントは `/kjfsm-personal:connect-kjfsm-auth` が持つ。

## 5. 確かめる

- `pnpm install` のあと、テンプレートの `docs/agents/verification.md` のゲートを上から通す
- `pnpm dev` でログインから1つの機能までを画面で通す。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**

## 6. 完了

- [ ] 手順1の2つの答えに沿って、認証先と DB が組まれている
- [ ] テンプレートの履歴の上に、名前を替えたコミットが積まれている。origin は外れている
- [ ] 検証ゲートが green で、`pnpm dev` でログインから1つの機能までを通した
- [ ] remote を作り直したら `/kjfsm-skills:setup-repo` を再実行した。テンプレートで済んでいるので、拾うのは名前を替えたことで生じたずれだけである
