---
name: implement
description: "スペックやチケットの集合に基づいて、1つの作業をビルドする。"
disable-model-invocation: true
---

ユーザーがスペックやチケットで記述した作業を実装する。

可能な場所では、事前に合意したシームで /tdd を使う。

作業が完了したと思ったら /verification-loop でクリーンランを取る。

クリーンランが取れたら /code-review を使って作業をレビューする。

作業を現在のブランチにコミットする。
