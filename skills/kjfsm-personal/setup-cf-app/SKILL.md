---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、手元のテンプレート `kjfsm/cf-workers-free-template`(Free プランに収まる Vite の React SPA + Hono の API Worker)を写して立ち上げる。依存を上げ、認証先と DB を替え、名前を付け替える。テンプレートが無ければ公式テンプレートから組む。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# テンプレートを写してアプリを立ち上げる

テンプレート `kjfsm/cf-workers-free-template` は標準構成を組み終え、`/kjfsm-skills:setup-repo` も済ませた状態で保ってある。**ここでは構成を組み直さない** — 構成を変えたいときはテンプレートを直し、次に写すアプリから効かせる。

## 1. 決める

写す前に2つだけ聞く。推測で埋めない — あとから替えると、スキーマとマイグレーションを作り直す。

- **認証先** — kjfsm の共通 IdP(kjfsm-auth。テンプレートの既定)、Google などの social、email/password
- **DB** — 共有 D1(`kjfsm-shared-db`。テンプレートの既定)に相乗りするか、このアプリだけの D1 を作るか

## 2. テンプレートを探す

`gh repo view kjfsm/cf-workers-free-template` で見えるかを確かめる(非公開なので、見えるのは権限のあるアカウントだけ)。**見えなければ写さず、`/kjfsm-skills:scaffold-cf-app` を呼び、手順1の2つの答えを渡す。**

手元にテンプレートのチェックアウトがあっても、そこからは写さない。手元が `origin` より遅れていると、テンプレートで直した不具合が戻る。

## 3. 写す

```bash
gh repo clone kjfsm/cf-workers-free-template <名前>
git -C <名前> remote remove origin
```

GitHub の「Use this template」やファイルのコピーではなく clone にする。履歴を持ち込むので、起点(C3 の生成物そのまま)からの差分を `git diff <起点>` で読め、公式の更新を取り込むときの比較元が残る。

## 4. 依存を上げる

`pnpm up --latest` のあと、テンプレートの `docs/agents/verification.md` のゲートを上から通し、名前の付け替えとは別のコミットにする — 混ぜると、赤くなったときに上げた依存と替えたものの切り分けがつかない。

**`pnpm up --latest` は peer の範囲を見ない。** プラグインが peer で上限を持つと(`@cloudflare/vitest-plugin` と `vitest` など)、最新が範囲外になる。落ちたら peer を読み、範囲に揃える。

ゲートが通ったら、**テンプレートも同じく上げるセッションを立てるかをユーザーに訊く。** 上げたのがこのアプリだけだと、次に写すアプリがまた古い版から始まる。立てるなら `/kjfsm-skills:launch-implementation-session` の手順4の形で、テンプレートのチェックアウトから立てる(手元に無ければ clone してから)。最初の入力は次のとおり:

```
依存を `pnpm up --latest` で上げ、docs/agents/verification.md のゲートを通して PR を出してください。<peer を揃えた依存があれば、その版>。終わったら <自分のセッション名> に SendMessage で PR の番号を知らせてください。マージはしないでください。
```

## 5. 名前と DB を替える

テンプレートの README の「フォークしたら」に沿う。手順1で「このアプリだけの D1」を選んだなら、続けて「新規 D1 に切り替える」に沿う。README の手順をここへ写さない — テンプレートと一緒に直るのは README だけである。slug の空きは `/kjfsm-personal:kjfsm-shared-db` が持つ。

## 6. 認証先を替える

kjfsm-auth のままなら飛ばし、IdP のクライアントは `/kjfsm-personal:connect-kjfsm-auth` で作る。

替えるなら、**差し替えは `src/worker/auth.ts` の中で完結させる**。このファイルは `/api/auth/*` からしか動的 import されず、ほかの API の軽い検証(`session.ts`)は session 表と Cookie の署名しか見ないので、認証先に依らない。

- `genericOAuth` を外し、`socialProviders`(Google など)か `emailAndPassword: { enabled: true }` にする。import は `better-auth/minimal` のまま保つ — 素の `better-auth` は kysely(約 430KB)を取り込む
- `IDP_URL`(`wrangler.json` の `vars`)と `IDP_CLIENT_ID`・`IDP_CLIENT_SECRET`(`secrets.required` と `.dev.vars.example`)を、選んだ認証先のものに替える。`secrets.required` に並べたキーしか `.dev.vars` から読まれない
- `src/react-app/routes/login.tsx` のボタンと文言を、選んだ認証先のサインインに替える
- `pnpm auth:generate` でスキーマを作り直し、差分が出たら `pnpm db:generate`
- **email/password は CPU を食う。** パスワードのハッシュ化(scrypt)が予算ぎりぎりで動く(better-auth#8860)ので、本番で登録とログインの経路を別に測る

## 7. 確かめる

- 検証ゲートを上から通す
- `pnpm dev` でログインから1つの機能までを画面で通す。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**

## 8. 完了

- [ ] テンプレートの履歴の上に、依存を上げたコミットと、名前・DB・認証先を替えたコミットが積まれている。origin は外れている
- [ ] テンプレートの依存を上げるセッションを立てるか訊き、答えに従った
- [ ] 検証ゲートが green で、`pnpm dev` でログインから1つの機能までを通した
- [ ] remote を作り直したら `/kjfsm-skills:setup-repo` を再実行した。テンプレートで済んでいるので、拾うのは名前を替えたことで生じたずれだけである
