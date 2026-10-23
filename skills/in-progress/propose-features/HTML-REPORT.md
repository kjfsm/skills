# HTML レポートの形

1つの自己完結した HTML。スクリプトは Tailwind の CDN だけで、ほかは静的に書く。

## 骨組み

```html
<!doctype html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{{アプリ名}} の機能提案</title>
    <script src="https://cdn.tailwindcss.com/3.4.16"></script>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-4xl mx-auto px-4 py-12 space-y-12">
      <header>...</header>
      <section id="purpose">...</section>
      <section id="candidates" class="space-y-10">...</section>
      <section id="dropped">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## ヘッダーと目的

アプリ名・日付・読んだ根拠(目的のファイルのパス、棚卸しした範囲、ログを読んだか)を1行ずつ。続けて `docs/product.md` の3節を短く引く — 各カードの根拠はここを指す。ユーザーがまだ認めていない行には amber の「未確認」バッジを付ける。前置きの段落は書かない。

## 候補のカード

1つの候補を1つの `<article id="...">` にする。

- **タイトル** — 利用者ができるようになることを、利用者の言葉で(「先週の出欠を一覧で見返せる」)。機能名(「履歴画面」)にしない
- **バッジ** — 強さ(`Strong` = emerald、`Worth exploring` = amber、`Speculative` = slate)と大きさ(`S` / `M` / `L`)
- **誰が・いつ** — 目的のファイルの利用者と場面を1文で
- **今 → 足したら** — 中心に置く図。利用者がそれを片付けるまでの手順を、左に今、右に足したあとで、横並びの段で描く。今の側の回避策(別のツール、手作業、誰かに頼む)は赤で印す。段の数の差が、そのまま便利さの量である
- **根拠** — 3つを分けて並べる
  - 目的の文 — `docs/product.md` から引用(`<blockquote>`)
  - コード — ファイルの場所を `font-mono text-sm` で。何が欠けているかを各行に一言
  - ログ — 数字があれば。無ければこの行ごと出さない
- **触るもの** — 画面・API・テーブルを1行ずつ。データモデルを変えるならそう書く
- **しないこと** — この候補の範囲から外すものを1〜2行

段落の説明を足さない。図が段落なしで読めないなら、図を描き直す。

## 落とした候補

`<details>` に畳む。手順4で落としたものを、落とした理由(目的の文を引けない / 何をしないかに触れる / 名前を入れ替えても通る / 他の領分)と1行ずつ。ユーザーが「なぜあれが無いのか」と思ったときに答えるためにある。

## いちばんの推奨

大きめのカードを1つ。候補名、なぜそれからかを1文、そのカードへのアンカー。強さが同じなら大きさの小さい方を推す。

## 書き方

- 色は控えめに。アクセント1色(emerald か indigo)と、回避策の赤、注意の amber
- 用語は用語集(`GLOSSARY.md` か `CONTEXT.md`)の言葉を使う。用語集が「出欠」と呼ぶものを「attendance」や「参加状況」と書かない
- 「便利になる」「使いやすくなる」で締めない。どの手順が何段減るか、誰に頼まずに済むかで書く
- ぼかさない。「〜かもしれません」と書きたくなった候補は `Speculative` を付けて言い切る
