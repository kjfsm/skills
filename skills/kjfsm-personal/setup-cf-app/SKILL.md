---
name: setup-cf-app
description: 新規の Cloudflare Workers フルスタックアプリを、GitHub のテンプレート `kjfsm/cf-workers-free-template`(Free プランに収まる Vite の React SPA + Hono の API Worker)を写して立ち上げる。テンプレートが見えなければ公式テンプレートから組む。「環境構築」「新規プロジェクト」「新しいアプリを作る」「セットアップ」「スキャフォールド」などで参照する。
---

# テンプレートを写してアプリを立ち上げる

テンプレート `kjfsm/cf-workers-free-template` は標準構成を組み終え、`/kjfsm-skills:setup-repo` も済ませた状態で保ってある。**ここでは構成を組み直さない** — 構成を変えたいときはテンプレートを直し、次に写すアプリから効かせる。

## 1. 決める

写す前に2つだけ聞く。推測で埋めない。

- **認証先** — kjfsm の共通 IdP(kjfsm-auth。テンプレートの既定)、Google などの social、email/password
- **DB** — 共有 D1(`kjfsm-shared-db`。テンプレートの既定)に相乗りするか、このアプリだけの D1 を作るか

## 2. テンプレートを探す

`gh repo view kjfsm/cf-workers-free-template` で見えるかを確かめる(非公開なので、見えるのは権限のあるアカウントだけ)。**見えなければ写さず、`scaffold-cf-app` スキルを呼び、手順1の2つの答えを渡す。**

手元にテンプレートのチェックアウトがあっても、そこからは写さない。手元が `origin` より遅れていると、テンプレートで直した不具合が戻る。

## 3. 写す

```bash
gh repo clone kjfsm/cf-workers-free-template <名前>
git -C <名前> remote rename origin template
git -C <名前> remote set-url --push template no-push
```

GitHub の「Use this template」やファイルのコピーではなく clone にする。履歴を持ち込むので、起点(C3 の生成物そのまま)からの差分を `git diff <起点>` で読める。remote は消さずに `template` として残し、`git fetch template` でテンプレートの更新を追えるようにする。push 先だけは潰す — 残すと、このアプリの最初の push がテンプレートへ飛ぶ。

## 4. 依存を上げる

`pnpm up --latest` のあと、テンプレートの `docs/agents/verification.md` のゲートを上から通し、名前の付け替えとは別のコミットにする — 混ぜると、赤くなったときに上げた依存と替えたものの切り分けがつかない。範囲内で上げる `pnpm up` にしないのは、テンプレートの範囲指定そのものが、写した時点の最新から遅れていくからである。

**`pnpm up --latest` は peer の範囲を見ない。** プラグインが peer で上限を持つと(`@cloudflare/vitest-plugin` と `vitest` など)、最新が範囲外になる。落ちたら peer を読み、範囲に揃える。

ゲートが通ったら、**テンプレートも同じく上げるセッションを立てるかをユーザーに訊く。** 上げたのがこのアプリだけだと、次に写すアプリがまた古い版から始まる。立てるなら、テンプレートのリポジトリに「依存を `pnpm up --latest` で上げる」イシューを作り(peer を揃えた依存があれば、その版を書く)、`launch-implementation-session` スキルを呼んで、そのイシューと、セッションを立てる場所としてテンプレートのチェックアウト(手元に無ければ clone したもの)を渡す。

## 5. 名前・DB・認証先を替える

テンプレートの README に沿う。README の手順をここへ写さない — テンプレートと一緒に直るのは README だけである。

- 名前 → 「フォークしたら」。slug の空きは `kjfsm-shared-db` スキルが持つ
- このアプリだけの D1 → 続けて「新規 D1 に切り替える」
- kjfsm-auth 以外 → 続けて「認証先を替える」。kjfsm-auth のままなら、IdP のクライアントは `connect-kjfsm-auth` スキルで作る

## 6. 確かめる

- 検証ゲートを上から通す
- `pnpm dev` でログインから1つの機能までを画面で通す。叩く前にポートの空きを確かめる — 別のプロジェクトの dev サーバーが同じポートに居ると、自分は `Port already in use` で落ちたまま、**応答は他人のアプリから返り、書き込みも他人の DB に入る**

## 7. 完了

- [ ] テンプレートの履歴の上に、依存を上げたコミットと、名前・DB・認証先を替えたコミットが積まれている。`template` の remote は push できない
- [ ] テンプレートの依存を上げるセッションを立てるか訊き、答えに従った
- [ ] 検証ゲートが green で、`pnpm dev` でログインから1つの機能までを通した
- [ ] このアプリの remote を作ったら、ユーザーに `/kjfsm-skills:setup-repo` を実行してもらった。テンプレートで済んでいるので、拾うのは名前を替えたことで生じたずれだけである
