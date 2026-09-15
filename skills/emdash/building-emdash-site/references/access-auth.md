# Cloudflare Access を管理画面の認証にする

> `auth: access({...})` の書き方と各オプションの意味は公式を読むこと。
> [guides/authentication](https://docs.emdashcms.com/guides/authentication/)(Cloudflare Access の節)、
> [reference/configuration](https://docs.emdashcms.com/reference/configuration/)(`auth` の全オプション)。
> 公式は「Access が唯一の認証になる」とだけ書き、**Access をどのパスに掛けるか、既存のトークンがどうなるか、
> ロールがどこから来るか**に触れていない。ここに書くのはそこだけ。根拠は EmDash 0.37 の
> `emdash/src/astro/middleware/auth.ts` と `@emdash-cms/cloudflare/src/auth/cloudflare-access.ts`。

Access アプリ自体の作り方(3層ルール、リストとグループ)は `setup-cf-access` スキルが持つ。

## Access を `/_emdash` 全体に掛けない

公開サイトは、訪問者の認証なしで `/_emdash` 配下を叩いている。EmDash 自身もこれらを認証不要として扱う
(`auth.ts` の `PUBLIC_API_PREFIXES` / `PUBLIC_API_EXACT`)。`/_emdash` を丸ごと Access で塞ぐと、
訪問者に対して画像・検索・コメントが壊れる。次のパスは bypass 層に回す:

| パス                                                                                    | 叩くもの                                                         |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `/_emdash/api/media/file/`                                                              | Worker 経由のメディア配信(バイラインのアバターなど)              |
| `/_emdash/api/search`、`/_emdash/api/search/suggest`                                    | サイト内検索                                                     |
| `/_emdash/api/comments/`                                                                | コメント投稿                                                     |
| `/_emdash/api/mcp`                                                                      | MCP クライアント。bearer 専用で、Access のログイン画面を通れない |
| `/_emdash/api/oauth/token`、`/_emdash/api/oauth/register`、`/_emdash/api/oauth/device/` | MCP の OAuth のうち機械が叩く側                                  |
| `/_emdash/api/plugins/<id>/<route>`(`public: true` のもの)                              | プラグインの公開ルート                                           |

MCP の OAuth の同意画面(`/_emdash/oauth/authorize`)はブラウザで開くので、Access の内側に置いたままでよい。
EmDash を上げたら、上の2つの定数を読み直して表を合わせる。

**Access の範囲を狭く取りすぎても穴にはならない。** 非公開のルートは、リクエストのたびに Access の JWT
(`Cf-Access-Jwt-Assertion` ヘッダ、無ければ `CF_Authorization` クッキー)を検証し直す。セッションへは
フォールバックしない。Access の外に漏れた非公開パスは `401 Authentication failed` を返すだけで、素通りはしない。

## デプロイの順序を逆にすると締め出される

`auth: access()` を入れた Worker が Access の外で動くと、JWT が届かないので非公開の `/_emdash` はすべて
`401` になる。パスキーと OAuth ログインも同時に無効になるので、管理画面へ入る別の経路が無い。

1. Access アプリを先に作り、素の curl で `/_emdash/admin` が Access のログインへ `302` するのを確かめる
2. それから `auth: access()` をデプロイする

戻すときは設定を外して再デプロイすればよい。`users` テーブルはそのまま残る。

## 誰が入れるかは Access、ロールは EmDash が持つ

- **`autoProvision`(既定 `true`)のままにする。** Access を通った未知のメールアドレスは、初回アクセスで
  `defaultRole` のユーザーとして作られる。これで「Access のリストに載っている = 入れる」になる。
  `false` にすると `users` に無い人は `403 User not authorized` になり、Access と EmDash の2か所で名簿を持つことになる
- **既存のユーザーはメールアドレスで突き合わされる**(`getUserByEmail`)。パスキーや Google ログインで作った
  アカウントも、Access のアドレスと一致すればロールごと引き継がれる。「最初のユーザーは Admin」は `users` が空のときだけ効く
- **`roleMapping` に Access のグループやリストは届かない。** 突き合わせる `groups` は Access の `get-identity`
  が返す **IdP のグループ**(Google Workspace、Okta など)である。Access の rule group や Zero Trust の
  リストはここに現れない。個人の Google アカウントやワンタイム PIN でログインさせるなら、グループが空なので全員が
  `defaultRole` になる。ロールは管理画面で上げ下げし、`syncRoles: false`(既定)がそれを保つ
- `defaultRole` の既定 `30` は **Author** である。ソース中のコメントには "Editor" とあるが、ロールの表
  (Author 30 / Editor 40)のほうが正しい

## Access から外しても止まらないもの

- **発行済みの bearer トークン。** 認証は PAT(`ec_pat_`)や OAuth トークンを Access より先に見る。MCP の
  パスは bypass しているので、Access のリストから外した人のトークンは生き続ける。退任時は EmDash 側でトークンを
  失効させるか、ユーザーを無効にする。`disabled` のユーザーは Access を通っても `403 Account disabled` になる
- **Access 自身のセッション。** メールによる判定はログイン時にしか行われない(`setup-cf-access` 参照)

EmDash のセッションは残るが、害は無い。Access 認証が書くセッションは、公開ページで編集者を見分けるためだけに
読まれ、非公開の `/_emdash` では参照されない。
