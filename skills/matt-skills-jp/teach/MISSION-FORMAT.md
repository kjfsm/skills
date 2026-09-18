# MISSION.md の形式

テンプレートは **形** の見本である。書く言語はリポジトリの既存文書に合わせる — 見本が英語であることは、英語で書く理由にならない。

`MISSION.md` はワークスペースのルートに置かれる。ユーザーがこのトピックを学んでいる _理由_ を記録する。何を次に教えるか、どのリソースを提示するか、どんな演習を設計するかといった、あらゆる指導上の決定は、このドキュメントにたどれるべきである。

## テンプレート

```md
# Mission: {Topic}

## Why

{1-3 sentences. The concrete real-world goal the user is chasing. What changes in their life or work when they have this skill? Avoid abstract framings like "to understand X" — push for the underlying outcome.}

## Success looks like

- {A specific, observable thing the user will be able to do}
- {Another specific thing}
- {…}

## Constraints

- {Time, budget, prior commitments, learning preferences, anything that bounds the approach}

## Out of scope

- {Adjacent topics the user explicitly does not want to chase right now — protects the zone of proximal development}
```

## ルール

- **ワークスペースごとにミッションは1つ。** ユーザーが2つの無関係なことを学びたいなら、それは2つのワークスペースである。
- **抽象より具体を。** 「10月までにハーフマラソンを走る」は「もっと健康になる」に勝る。「チームに Rust の CLI を出荷する」は「Rust を学ぶ」に勝る。
- **曖昧さには押し返す。** ユーザーが理由を言葉にできないなら、何かを書く前にインタビューする。悪いミッションは、ミッションがないより悪い。
- **現実が変わったら改訂する。** ミッションは変わる。ユーザーの目標が動いたら、このファイルを更新する — 古びたミッションが今後のセッションを方向づけたままにしない。
- **短く保つ。** `MISSION.md` が画面をはみ出すようになったら、それはもう羅針盤ではなく、計画になってしまっている。
