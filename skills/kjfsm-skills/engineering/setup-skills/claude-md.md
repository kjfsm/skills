# 本体が `CLAUDE.md` のまま残るとき

`SKILL.md` の手順4で `AGENTS.md` への移行を断られ、`CLAUDE.md` を本体として編集する場合だけ読む。

## 記述の規約は rule へ移す

記述の規約(`### Conventions` のうち応答言語の行を除く残り)をブロックに置かず、`.claude/rules/writing-conventions.md` を作る。`# 書いたものの宛先` を見出しにし、その下へ `SKILL.md` のテンプレートの本文をそのまま置く。`paths:` の無い rule は `CLAUDE.md` と同じ優先度で毎セッション読まれるので、届き方は変わらず `CLAUDE.md` だけが短くなる。

ブロックに残るのは2行になる:

```markdown
### Conventions

[応答言語の指定を1行]。

書いたものの宛先は `.claude/rules/writing-conventions.md` にある。
```

- **どちらか一方にだけ置く。** ブロックと rule の両方に本文があると、片方だけ直った日にもう片方が嘘をつく
- **rule に `paths:` を付けない。** マッチするファイルを **読んだ** ときにしかロードされず、新規ファイルやコミットメッセージを書く場面で消える

本体が `AGENTS.md` なら、この形は採らない — Codex など `.claude/rules/` を読まないハーネスも本体は読むので、本文はブロックの中に置く。
