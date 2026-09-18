# HTML レポートの形式

テンプレートは **形** の見本である。書く言語はリポジトリの既存文書に合わせる — 見本が英語であることは、英語で書く理由にならない。

このアーキテクチャレビューは、OS の一時ディレクトリにある単一の自己完結した HTML ファイルとして描画される。Tailwind と Mermaid はどちらも CDN から読み込む。Mermaid はグラフ的な図を確実に扱い、手作りの div とインライン SVG はもっと編集的なビジュアル(マス図、断面図)を扱う。両者を混ぜること — すべてを Mermaid に頼らない。ありきたりな見た目になり始める。

## 目次

- [骨格](#骨格)
- [ヘッダー](#ヘッダー)
- [候補カード](#候補カード)
- [図のパターン](#図のパターン)
- [スタイルの指針](#スタイルの指針)
- [一番のおすすめセクション](#一番のおすすめセクション)
- [トーン](#トーン)

## 骨格

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Architecture review — {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
    </script>
    <style>
      /* small custom layer for things Tailwind doesn't cover cleanly:
         dashed seam lines, hand-drawn-feeling arrow heads, etc. */
      .seam {
        stroke-dasharray: 4 4;
      }
      .leak {
        stroke: #dc2626;
      }
      .deep {
        background: linear-gradient(135deg, #0f172a, #1e293b);
      }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## ヘッダー

リポジトリ名、日付、そしてコンパクトな凡例: 実線の箱 = モジュール、破線 = シーム、赤い矢印 = 漏れ、太い濃い箱 = 深いモジュール。導入の段落はなし — いきなり候補に入る。

## 候補カード

図が主役を担う。プロースはまばらで平易であり、(`codebase-design` スキルの)用語集の言葉を、もったいぶらずに使う。

各候補は1つの `<article>`:

- **タイトル** — 短く、その深化に名前を付ける(例:「Order intake パイプラインを畳み込む」)。
- **バッジの列** — 推奨の強さ(`Strong` = エメラルド、`Worth exploring` = アンバー、`Speculative` = スレート)に加え、依存カテゴリ(`in-process`、`local-substitutable`、`ports & adapters`、`mock`)のタグ。
- **ファイル** — 等幅フォントのリスト、`font-mono text-sm`。
- **ビフォー/アフター図** — 中心となる要素。2列を並べる。下記のパターンを参照。
- **問題** — 1文。何が痛むか。
- **解決策** — 1文。何が変わるか。
- **成果** — 箇条書き、それぞれ6語以内。例:「テストが1つのインターフェースに当たる」「価格ロジックの漏れが止まる」「浅いラッパーを4つ削除」。
- **ADR コールアウト**(該当する場合) — アンバー色の箱の中に1行。

説明の段落はなし。図を理解するのに段落が必要なら、その図を描き直す。

## 図のパターン

候補に合うパターンを選ぶ。組み合わせる。すべての図を同じ見た目にしない — 多様性もこの狙いの一部である。

### Mermaid グラフ(依存関係/呼び出しフローの主力)

「X が Y を呼び、Y が Z を呼び、この混乱ぶりを見てくれ」というのが要点のときは、Mermaid の `flowchart` か `graph` を使う。それを Tailwind でスタイリングしたカードで包み、唐突に降ってきた感じにならないようにする。classDef でスタイリングし、漏れているエッジを赤に、深いモジュールを濃い色にする。シーケンス図は「ビフォー: 6往復、アフター: 1回」のようなケースによく合う。

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A[OrderHandler] --> B[OrderValidator]
      B --> C[OrderRepo]
      C -.leak.-> D[PricingClient]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

### 手作りの箱と矢印(Mermaid のレイアウトが思い通りにならないとき)

モジュールは枠線とラベルを持つ `<div>` として。矢印は、相対配置のコンテナの上に絶対配置されたインライン SVG の `<line>` や `<path>` 要素として。「アフター」の図を、内部がグレーアウトされた1つの太枠の深いモジュールのように見せたいときにこれを使う — Mermaid はそれを適切な太さで描画してくれない。

### 断面図(層状の浅さに向く)

呼び出しが通過する層を示すため、水平な帯(`h-12 border-l-4`)を積み重ねる。ビフォー: 何もしていない薄い層が6つ。アフター: 統合された責務のラベルが付いた太い帯が1つ。

### マス図(「インターフェースが実装と同じくらい広い」場合に向く)

モジュールごとに2つの長方形 — 1つはインターフェースの表面積、もう1つは実装。ビフォー: インターフェースの長方形が実装の長方形とほぼ同じ高さ(浅い)。アフター: インターフェースの長方形は低く、実装の長方形は高い(深い)。

### 呼び出しグラフの折りたたみ

ビフォー: 入れ子の箱として描かれた関数呼び出しの木。アフター: 同じ木が1つの箱に折りたたまれ、今や内部にある呼び出しがその中に薄く表示される。

## スタイルの指針

- コーポレートダッシュボードではなく、編集的な方向に寄せる。余白は潤沢に。見出しにセリフ体を使ってもよい(`font-serif` は stone/slate とよく合う)。
- 色は控えめに: アクセント1色(エメラルドかインディゴ)に加え、漏れには赤、警告にはアンバー。
- 図はおよそ320px の高さに保ち、ビフォー/アフターがスクロールなしで気持ちよく並ぶようにする。
- 図の中のモジュールラベルには `text-xs uppercase tracking-wider` を使う — それらは UI ではなく図式として読めるべきである。
- スクリプトは Tailwind の CDN と Mermaid の ESM インポートのみ。それ以外、このレポートは静的である — アプリのコードはなく、Mermaid 自身の描画を超えたインタラクティブ性もない。

## 一番のおすすめセクション

1つの大きめのカード。候補の名前、なぜそれなのかの1文、そのカードへのアンカーリンク。それだけ。

## トーン

平易で簡潔な英語で — ただしアーキテクチャに関する名詞と動詞は、`codebase-design` スキルからそのまま持ってくる。簡潔さは、それらから逸れる言い訳にはならない。

**正確に使う言葉:** module、interface、implementation、depth、deep、shallow、seam、adapter、leverage、locality。

**決して置き換えない:** component、service、unit(module の代わりに)・API、signature(interface の代わりに)・boundary(seam の代わりに)・layer、wrapper(module を意味しているのに、その代わりに)。

**このスタイルに合う言い回し:**

- 「Order intake モジュールは浅い — インターフェースがほぼ実装と一致している。」
- 「Pricing がそのシームを越えて漏れている。」
- 「深化させる: 1つのインターフェース、テストする場所も1つ。」
- 「2つのアダプターがそのシームを正当化する: 本番では HTTP、テストではインメモリ。」

**成果の箇条書き** は、用語集の言葉で得られるものを名指しする: _「局所性: バグが1つのモジュールに集約される」_、_「レバレッジ: 1つのインターフェース、N か所の呼び出し箇所」_、_「インターフェースは縮み、実装がラッパーを吸収する」_。_「保守しやすくなる」_ や _「コードがきれいになる」_ とは書かない — それらの言葉は用語集になく、そこに載る資格がない。

言い訳めいた前置きや、意味のない前置き(「特筆すべきは…」)は書かない。文が箇条書きにできるなら、箇条書きにする。箇条書きが削れるなら、削る。ある用語が `codebase-design` の用語集にないなら、新しい言葉を発明する前に、すでにある言葉に手を伸ばす。
