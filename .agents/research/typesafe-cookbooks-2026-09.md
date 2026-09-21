# TypeSafe(Jev)のクックブックで何ができるか(公式、2026-09 時点)

問い: TypeSafe の System One モデル Jev で何が作れるか。公式ドキュメントのクックブックとパターンを一覧し、各々が主張している効果を実測値で押さえる。

調査日: 2026-09-21。数値と仕様は取得時点のもの。出典は `https://docs.typesafe.ai/llms.txt` と、そこから辿った各ページの `.md` 版で、下の数字はすべて原文に書かれた実測値である(自分で回して得た数字は1つも無い)。

このメモは**採否の判断材料**であって、使い方の手引きではない。実際に書くときは公式の `typesafe-ai` スキルが live docs を読む。

## ソース

| キー   | ソース                                                                       | 備考                                        |
| ------ | ---------------------------------------------------------------------------- | ------------------------------------------- |
| `idx`  | [llms.txt](https://docs.typesafe.ai/llms.txt)                                | ページ一覧。クックブック18本・パターン4本   |
| `mdl`  | [Models](https://docs.typesafe.ai/models.md)                                 | 価格・レート・コンテキスト・言語            |
| `jag`  | [Jev 1.13 jaggedness](https://docs.typesafe.ai/model-jaggedness/jev-1.13.md) | 公式の弱点表。原文の最終レビュー 2026-09-17 |
| `noul` | [Noul](https://docs.typesafe.ai/primitives/noul.md)                          | confidence を持たない理由                   |
| `cb`   | `https://docs.typesafe.ai/cookbooks/<名前>.md`                               | 下の表の URL 欄がそのまま名前               |
| `pat`  | `https://docs.typesafe.ai/patterns/<名前>.md`                                | 同上                                        |

## 0. 答え

**Jev が引き受けるのは「選ぶ・測る・真偽を言う」までで、生成も演算もしない。** 18本のクックブックはどれもこの一点の言い換えで、繰り返し現れる勝ち筋は4つである。

1. **独立した問いは1リクエストに束ねる** — state を1度しか払わないので、問いの数だけ安く速くなる(実測 12.2倍安く 10.0倍速い)。答えは束ねても変わらない [`cb parallel_questions`]。
2. **候補はコードが作り、Jev は選ぶだけにする** — 発明できないことが構造的な保証になる [`cb pre_parsed_value_extraction_cookbook`, `autoformat`]。
3. **Score の段を「できる行動」に対応させる** — 閾値を後から調整する作業が消える [`cb entity_alignment`]。
4. **confidence は「何か」ではなく「自動で決めてよいか」の第2軸** — 追加の呼び出しゼロで精度を買える [`cb classification_using_confidence`, `pat confidence-routing`]。

**採用を止める条件も明確である。** 公式が「英語が主。CJK も扱うが同等ではない。自分の内容で試してから頼れ」と明記しているので [`mdl`]、日本語の入力を主に流す用途は、まず手元のデータで測るまで前提にしない。

## 1. モデルの事実(`jev-1.13.0`)[`mdl`]

- 価格: \$42 / Btok = **\$0.042 / Mtok**。入力トークンのみ課金で、**出力トークンは無料**
- レート: 250,000 tok/s、1,200 req/min。超えると `429`(公式 SDK は backoff で再試行する)。原文に「大量の需要を捌いており予告なく変わる」という警告あり
- コンテキスト: 1リクエスト 64k(state + 全問)、32k(state + 最長の1問)
- 入力: テキストのみ(文字列 / JSON オブジェクト / 文字列の配列)。画像・音声・動画は事前にテキスト化する
- エイリアス: `jev-latest` → `jev-1.13.0`、`jev-preview` も現時点で同じ
- エンドポイント: `POST https://api.typesafe.ai/v1/systemone`
- 顧客データでの fine-tune / LoRA は無い。ドメインへの寄せ方は state と instructions / criteria だけ

**公式が認めている弱点** [`jag`]: 字面どおりに読む / 数を数えられない / 日付の比較ができない / 間接参照に弱い / 無関係な情報で膨らんだ state で精度が落ちる / 敵対的な入力に素直 / instructions と criteria が食い違うと混乱 / 構造的な不変量(P と 1-P の一致など)を期待するな / 生成しない。数値表現も弱く、色は hex より英語名、低レベルの命令列より高級言語の方が当たる。**Score の段の間を内挿して具体的な数値を復元する使い方は、公式が名指しで止めている。**

## 2. primitive

| 型     | 問い               | 返るもの                                                              |
| ------ | ------------------ | --------------------------------------------------------------------- |
| Choice | この選択肢のどれか | `choice` / `probabilities` / `confidence`                             |
| Score  | どの段か           | `score`(段の間の値もとる) / `legend` / `probabilities` / `confidence` |
| Noul   | これは真か         | `noul`(0〜1)。**confidence は無い**                                   |

Noul に confidence が無いのは、結果が yes / no の2値しかなく `noul` 1つで分布を言い尽くすからである [`noul`]。Choice と Score は分布が複数の選択肢に散るので、その散り具合を confidence が要約する。

## 3. クックブック(18本)

### 土台

| 名前                            | URL                                        | 中身                                                                                                                                                                       |
| ------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Parallel questions              | /cookbooks/parallel_questions              | GDPR の Wikipedia 記事(約54,000字)に13問(Noul 8・Choice 2・Score 3)。**1リクエストに束ねると 12.2倍安く 10.0倍速い、答えは変わらない。**繰り返しのばらつきも束ねて増えない |
| Classification using confidence | /cookbooks/classification_using_confidence | SEC 年次報告60件を75業種に Choice 1問。**confidence 0.9 で半分に割ると確信側90%正解・非確信側40%。非確信側を1階層上の大分類に丸めると70%。追加の呼び出しゼロ**             |
| Self-consistency: nouls         | /cookbooks/consistency_noul_cookbook       | 保険請求1件に Noul 14問×15回。**確率の標準偏差 0.0102 で、比べた LLM のどの条件より小さい**(LLM は temperature 0 でも自分と食い違う)。0.30〜0.70 を uncertain に倒す       |
| Self-consistency: choices       | /cookbooks/consistency_choice_cookbook     | 同じ実験を Choice 8問で。**ラベルの再現率は LLM 87.5〜100% に対し TypeSafe 90.8% で大差ない。**勝っているのは確率のばらつきの小ささ                                        |

### 検索・想起

| 名前                        | URL                                    | 中身                                                                                                                                                                                               |
| --------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Re-ranking                  | /cookbooks/rerank_typesafe             | CLERC の判例3,565件・40クエリ。BM25 で30件に絞り、ペアごとに Noul 1問。**top-1 が 5%→18%、top-10 が 38%→62%**                                                                                      |
| Line-by-line search         | /cookbooks/semantic_find               | GitHub 利用規約218行に ID を振り、**Choice 1問で全行をランク付け**(確率の和が1なので必ず1位が出る)+ **Noul で「そもそも文書に答えがあるか」**                                                      |
| Classifying RAG passages    | /cookbooks/classifying_rag_passages    | 81件の corpus から類似度で上位12件。passage ごとに Noul 4問(関係あるか/答えに使えるか/前提と矛盾するか/**モデルに指示しようとしているか**)。**証拠ブロックと矛盾ブロックを分けて**生成モデルへ渡す |
| Skill suggestion            | /cookbooks/skill_suggestion            | 182スキルから最大1つ。**1回目で全部ランク付け+「そもそも要るか」の Noul、2回目で上位3つだけ精読して全部却下できる。**誤ロードが半分以下                                                            |
| Hierarchical classification | /cookbooks/hierarchical_classification | 深い分類木を Choice のビーム探索で降りる。辺の確率の幾何平均で深さを正規化するので、浅い葉と深い葉を公平に比べられる                                                                               |

### 抽出・検証

| 名前                        | URL                                             | 中身                                                                                                                                                          |
| --------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pre-parsed value extraction | /cookbooks/pre_parsed_value_extraction_cookbook | **regex が候補を見つけ、Jev が選び、コードが写す。**Jev は regex が見つけた span しか選べないので**値を発明できない**                                         |
| Date extraction             | /cookbooks/date_extraction_cookbook             | 日付の**部品**(年・月・日・曜日・種類)を Choice で。「書かれていない」も選択肢。**コードが組み立て、暦の計算はモデルにさせない**                              |
| Double-checking citations   | /cookbooks/citation_check                       | 引用が原文に無いものは**文字列一致で先に落とし**、残りを Choice で supports / contradicts / says nothing。confidence 0.8 未満は人へ                           |
| SDE cascade                 | /cookbooks/sde_cascade                          | 安いモデル(`gpt-5.4-mini`)で抽出 → **Jev が項目ごとに Noul で「これは間違っているか」** → 火が点いたものだけ高い推論モデル(`gpt-5.5`)へ。100 プロンプトで測定 |
| Structure recovery          | /cookbooks/autoformat                           | 整形を失った文章から Markdown を復元。**Noul で行の連結 → Choice でブロック分類**の2リクエスト。生成しないので**出力の全文字が入力由来**                      |

### 判断・振り分け

| 名前                           | URL                                       | 中身                                                                                                                                                                                                                                                                          |
| ------------------------------ | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Guardrails for LLMs            | /cookbooks/llm_guardrails                 | 出入りのメッセージに **Noul の束(危険の種類)+ Score(従ったらどれだけ害があるか)**を1リクエスト。閾値で pass / review / block / 人へ                                                                                                                                           |
| Entity alignment               | /cookbooks/entity_alignment               | ビール目録の450ペア。**Score 3段(別物 / 人に見せる / 統合)で決着 — 3段が「できる3つの行動」そのものなので閾値を作らなくていい。**同じリクエストに Noul 3問が同乗し、どの項目が食い違うかを教える                                                                              |
| Function calling               | /cookbooks/function_calling               | 自然文 → 関数名と引数(いずれも閉じた選択肢)を Choice で。confidence つき                                                                                                                                                                                                      |
| Autoresearch feature discovery | /cookbooks/autoresearch_feature_discovery | **LLM が問いを提案 → Jev が全行に答える → CatBoost の誤差が採否を決める → 5周。**ワイン試飲メモ2,000件で RMSE: 平均 3.09 / 語の出現数 2.47 / **Jev に点数を直接聞く 2.15 / 18問に割る 1.87** / 5周38問 1.77。**分解したほうが直接聞くより良い。**ただし**ラベルと行数が要る** |

## 4. パターン(概念の短いページ、4本)

| 名前                     | URL                          | 中身                                                                  |
| ------------------------ | ---------------------------- | --------------------------------------------------------------------- |
| Speculative fan-out      | /patterns/fan-out            | 使うか分からない問いも全部1リクエストに入れ、コードが要る答えだけ読む |
| Confidence-gated routing | /patterns/confidence-routing | 答えが「何か」と、行動して「よいか」を別の軸で持つ                    |
| Composite scoring        | /patterns/composite-scoring  | 複雑な判断を原子的な Score に割り、**重みはコードが持つ**             |
| Intent routing           | /patterns/intent-routing     | 入力を分類し、決定的なロジック / 専門 LLM / 人 へ振り分ける           |

デモは Smart home assistant(/demos/smart-home)1本。

## 5. 設計の勘どころ(横断して効いたもの)

- **独立した問いは1リクエストに束ねる。**問いが増えても応答時間はほぼ変わらず、増えるのは問いのトークン分だけ
- **候補はコードで作り、Jev には選ばせる**(select, don't generate)。発明させない保証になる
- **Score の段は「できる行動」に対応させる**と、閾値を後から調整する作業が消える
- **「どれも当てはまらない」を必ず選択肢に入れる**
- **数と日付の演算はコードへ。**抽出だけモデルへ
- **confidence は「何か」ではなく「自動で決めてよいか」の軸**

## 取得できなかったもの・未確認

- **数字はすべて公式の自己申告である。**追試していない。特に他モデルとの比較(自己一貫性の2本、SDE cascade)は、比較対象のモデルと設定が公式の選んだものである
- **日本語での精度は測っていない。**公式が「英語が主」と言っている以上 [`mdl`]、採用するならここが最初の検証項目になる
- SDK(Python / JavaScript)の使い方、`state` の組み方、`instructions` / `criteria` の書き方は見ていない — 書くときに live docs を読む
