---
name: setup-playwright
description: Playwright の E2E を入れ、ブラウザをどの層で用意するか決める。E2E をこれから入れるとき、`Executable doesn't exist` や `Missing system dependencies` が出たとき、コンテナやクラウドのサンドボックスに置いてあるブラウザと Playwright が要求するビルド番号がずれたとき、CI でだけブラウザの取得に失敗するとき、`playwright install` をセットアップスクリプト・SessionStart フック・CI のどこに置くか決めるときに使う。
---

# Playwright を入れる

**ブラウザは環境の備品ではなく、lockfile が版を決める依存である。** Playwright は `playwright-core/browsers.json` に焼き込まれた revision を読み、`<ブラウザ>-<revision>` という名前のディレクトリだけを探す。**revision を上書きする環境変数は無い。** 置いてあるブラウザと要求するブラウザがずれたとき、取れる手は「ピン通りに取ってくる」「実体を名指しする」「版を下げて合わせる」の3つしかなく、**正しいのは1つ目だけ**である。

残り2つが危ういのは、E2E が落ちるからではない。**通ってしまう**からである。手元と CI が別のブラウザを見ている状態は、緑が何も保証しない状態と同じで、しかも症状が出ない。

## 手順

### 1. ずれているかを数字で確かめる

推測しない。1つのコマンドが、要求している版と探しに行く場所の両方を出す。

```
pnpm exec playwright install --dry-run chromium
```

```
Chrome for Testing 151.0.7922.34 (playwright chromium v1234)
  Install location:    /opt/pw-browsers/chromium-1234
```

その `Install location` を `ls` して、**実際に何が置いてあるか**を見る。`chromium-1194` しか無ければ、それがずれである。

あわせて、すでに逃げ道が作られていないかを読む — `playwright.config.ts` の `executablePath` と `channel`、`PLAYWRIGHT_BROWSERS_PATH`、`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD`、CI に `playwright install` の行があるか。

**完了基準: 「要求している revision」「置いてある revision」「一致しているか」を数字で言えること。**

### 2. 3つの層のどこで用意するか決める

同じ `playwright install` でも、置く層によって走る条件が違う。

| 層                                                                                                   | いつ走るか                                                  | 置くもの                                 |
| ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------- |
| **VM のプロビジョニング** — クラウドのセットアップスクリプト、Dockerfile、devcontainer の postCreate | 環境を作るときに1度。結果はイメージやスナップショットに残る | `install --with-deps <ブラウザ>`         |
| **プロジェクトの用意** — SessionStart フック、`postinstall`                                          | どこでも、毎回                                              | `install <ブラウザ>`(`--with-deps` 無し) |
| **CI**                                                                                               | ジョブごとに、まっさらな状態から                            | `install --with-deps <ブラウザ>`         |

**正は真ん中の層に置く。** 版を知っているのは lockfile なので、そこから引く `pnpm exec playwright install` が唯一の権威になる。上下の層は前倒しのキャッシュであり、版がずれても遅くなるだけで、間違ったブラウザで緑にはならない。逆向き(プロビジョニング側だけが用意する)にすると、ずれた日に静かに壊れる。

**「入っているか」を調べる分岐を自分で書かない。** `playwright install` はすでに冪等で、揃っていれば数秒で戻る。

クラウドのサンドボックス(Claude Code on the web など)で組むときの具体は [cloud-sandbox.md](./cloud-sandbox.md)。

### 3. `--with-deps` を付ける層を分ける

付けるのは **root で回る Linux** だけ — CI と VM のプロビジョニング。中身は共有ライブラリの `apt-get` なので、それ以外の層では害になる。

- **非 root では `sudo` に化ける。** playwright は uid≠0 のとき `sudo -- sh -c ...`(sudo が無ければ `su root -c`)を組み立てる。tty の無いフックがこれを踏むと、パスワード待ちのままタイムアウトまで固まる
- **macOS では何もしない。** `installDeps` は win32 と linux 以外を素通りする

`Missing system dependencies required to run browser` は、この層を飛ばした症状である。ブラウザの実体があるのに起動できないときは、まずここを疑う。

### 4. 逃げ道を作らない

**やらないこと3つ。** どれも E2E を緑にするが、緑の意味を壊す。

- **`executablePath` で置いてあるブラウザを名指しする。** その環境だけが CI と別のビルドで通る。ずれに気づく機会も同時に潰れる
- **置いてあるブラウザに合わせて `@playwright/test` を下げる。** テスト依存の版を環境が決める向きになる。イメージが上がるたびに追随して下げ直すことになり、しかもサンドボックスの同梱物は公表されていないことが多い(→ [cloud-sandbox.md](./cloud-sandbox.md))
- **起動できないブラウザのプロジェクトを skip する。** 落ちる経路ではなく、見ない経路が増える

**例外はネットワークが閉じている環境だけ。** そのときも名指しではなく、**要求されている revision と同じものを置く**(社内ミラー、イメージへの事前焼き込み)。`executablePath` は最後に残る手であって、最初に取る手ではない。

### 5. 検証ゲートと CI に載せる

E2E は `docs/agents/verification.md` の1行になり、そこから CI に写る(→ `/setup-ci`)。**向きは常に verification.md → CI。**

`webServer` にビルドとマイグレーションまで持たせると、手元と CI で E2E の入口が1つになる。CI では `reuseExistingServer: false` にして、前のジョブの残骸を掴ませない。E2E が内部でビルドするなら、CI にビルドの行を重ねて置かない。

### 6. 完了

**3つの層に何を置いたか、版の正がどこにあるか**をユーザーに伝える。プロビジョニング側はリポジトリの外(環境の設定画面)にあることが多いので、そのときは**貼る文字列をそのまま渡す** — こちらからは書き込めない。
