# マップとチケットの形

`wayfinder` のマップ、その子チケット、チケットの種類の書式。マップやチケットを **書く / 作る** ときに開く — 読むだけのセッションには要らない。

テンプレートは **形** の見本である。書く言語はリポジトリの既存文書に合わせる。

## マップの本文

マップは **索引** であり、保管庫ではない。下された決定を列挙し、その詳細を保持するチケットを指し示す。決定はちょうど1か所 — そのチケット — にだけ存在するので、マップはそれを繰り返さず、要点とリンクだけを載せる。

開いているチケットは **列挙しない** — それらは問い合わせによって見つかる、開いている子イシューである。

```markdown
## Destination

<what reaching the end of this map looks like — the spec, decision, or change this effort is finding its way to. One or two lines; every session orients to it before choosing a ticket.>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- the index — one line per closed ticket: enough to judge relevance, then zoom the link for the detail the ticket holds -->

- [<closed ticket title>](link) — <one-line gist of the answer>

## Not yet specified

<!-- in-scope fog you can't ticket yet; graduates as the frontier advances -->

## Out of scope

<!-- work ruled beyond the destination; closed, never graduates -->
```

## チケットの本文

各チケットはマップの **子イシュー** であり、トラッカーのイシュー id がその識別子である。本文は問いであり、1回の10万トークンのエージェントセッションに収まる大きさにする。

```markdown
## Question

<the decision or investigation this ticket resolves>
```

答えは本文には含まれない — 解決時に **解決コメント** として記録される。解決の過程で作られた成果物は、貼り付けるのではなくイシューからリンクする。

各チケットは `wayfinder:<type>` ラベルをちょうど1つ持つ。

## チケットの種類

すべてのチケットは **HITL**(human in the loop — 自分自身の言葉で語る人間と _一緒に_ 作業する)か **AFK**(エージェントだけで駆動する)のいずれかである。HITL チケットは、その生きたやり取りを通してのみ解決する。**エージェントが人間の側を代わりに演じることは決してない** — 自分自身の問いに自分で答えるグリリングエージェントは、これを破っている。

| ラベル      | HITL / AFK  | 何をするか                                                                                                                                                 | いつ選ぶか                                                     |
| ----------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `research`  | AFK         | ドキュメント、サードパーティ API、ローカルのナレッジベースを読み、決定が待っている事実を表面化させる。`research` スキルを呼ぶサブエージェントで解決する    | 現在の作業ディレクトリの外にある知識が要るとき                 |
| `prototype` | HITL        | 反応を返せる、安価で粗く具体的な成果物(アウトライン、ラフな試作、スタブ、`prototype` スキルによる UI/ロジック)で議論の解像度を上げ、成果物としてリンクする | 「どう見えるべきか」「どう振る舞うべきか」が肝心の問いのとき   |
| `grilling`  | HITL        | `grilling` と `domain-modeling` の2つを呼ぶ、ラウンド単位の会話                                                                                            | **デフォルト**                                                 |
| `task`      | HITL or AFK | 決めることも試作も調査も無いが、それが終わるまで議論がブロックされている手作業                                                                             | サービスへの登録、アクセスのプロビジョニング、データの移動など |

`task` だけが _決める_ のではなく _やる_ 種類であり、その存在意義は目的地を届けることではなく、ある決定のブロックを解除することにある。エージェントは可能な限り単独で進め(AFK)、できない場合は正確なチェックリストを人間に手渡す(HITL)。完了したら解決とし、その答えに **何が行われたか** と、以降のチケットが依存する結果としての事実(認証情報の場所、新しい URL、行数など)を記録する。
