#!/usr/bin/env bash
set -uo pipefail

# Checks the repository invariants that CLAUDE.md and .agents/invocation.md
# state in prose.
#
# `claude plugin validate . --strict` only reaches marketplace.json when handed
# the repo root, so it does not catch a broken path in plugin.json. This does.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

fail=0
err() {
  echo "FAIL: $*" >&2
  fail=1
}

PROMOTED_BUCKETS="engineering productivity"
PLUGIN=".claude-plugin/plugin.json"

frontmatter() {
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1' "$1"
}

field() {
  frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1 | sed 's/^"\(.*\)"$/\1/'
}

listed_in_plugin() {
  grep -q "\"\./skills/[a-z-]*/$1\"" "$PLUGIN"
}

charlen() {
  # charlen <文字列> — UTF-8 の文字数。継続バイトを落とすと1文字1バイトになるので、
  # シェルのロケールが何であれ数が合う。このリポジトリの description は日本語なので、
  # バイト数で数えると約3倍にずれる。
  LC_ALL=C printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

est_tokens() {
  # 正確なトークナイザは手元に無いので近似する: ASCII は概ね4文字で1トークン、
  # 日本語などの非 ASCII は概ね1文字で1トークン。ASCII 側を 0.28/文字 とやや重く
  # 見るぶん、見積もりは実測より上振れする — 上限の検査なので、甘い側ではなく
  # 厳しい側へ倒してある。
  #
  # 行数ではなくトークンを数える理由: 上限がトークンで定められているうえ、
  # 日本語の本文は同じ行数でも英語よりはるかに重く、行数の検査だけを通り抜ける。
  local text ascii total
  text="$(cat)"
  total="$(charlen "$text")"
  ascii="$(LC_ALL=C printf '%s' "$text" | LC_ALL=C tr -cd '\000-\177' | wc -c | tr -d ' ')"
  awk -v a="$ascii" -v t="$total" 'BEGIN { printf "%d\n", a * 0.28 + (t - a) }'
}

strip_code() {
  # スキルはコードブロックの中に例示のリンクを書く(利用側リポジトリへ書き込む
  # コンテキストポインタ、CONTEXT.md の作例)ので、それらは本物の参照ではない。
  # フェンスが閉じずに終わったら非ゼロで抜ける — 13. がこれを閉じ忘れの検査に使う。
  #
  # スキルは例示のためにフェンスを入れ子にする(```` の中に ```)ので、開閉を単純に
  # 反転させると内側で同期がずれる。区間量指定子 {3,} は mawk に無いため、
  # バッククォートは数えて判定する。
  awk '
    {
      line = $0
      sub(/^[ \t]+/, "", line)
      n = 0
      while (substr(line, n + 1, 1) == "`") n++
      if (n >= 3) {
        rest = substr(line, n + 1)
        gsub(/[ \t]/, "", rest)
        if (depth == 0) { depth = n; next }
        if (n >= depth && rest == "") { depth = 0; next }
      }
      if (depth == 0) { gsub(/`[^`]*`/, ""); print }
    }
    END { exit(depth ? 1 : 0) }
  ' "$1"
}

md_links() {
  # 入れ子の参照ファイルからのリンクを SKILL.md が宣言したものと突き合わせられるよう、
  # リンク先はすべて第1引数のスキルディレクトリからの相対で返す。
  local root="$1" file="$2" base rel
  base="$(dirname "$file")"
  base="${base#"$root"}"
  base="${base#/}"
  strip_code "$file" |
    grep -o ']([^)]*\.md[^)]*)' |
    sed 's/^](//; s/)$//; s/#.*$//; s|^\./||' |
    grep -v '^[a-z][a-z0-9+.-]*://' |
    while IFS= read -r rel; do
      [ -n "$base" ] && printf '%s/%s\n' "$base" "$rel" || printf '%s\n' "$rel"
    done
}

seen_names=""
while IFS= read -r skill_md; do
  dir="$(dirname "$skill_md")"
  name="$(basename "$dir")"
  bucket="$(basename "$(dirname "$dir")")"

  # 1. frontmatter parses and `name` matches the directory
  if [ "$(head -1 "$skill_md")" != "---" ]; then
    err "$skill_md has no frontmatter"
    continue
  fi
  declared="$(field "$skill_md" name)"
  [ "$declared" = "$name" ] || err "$skill_md declares name '$declared' but lives in '$name/'"

  # 2. every skill carries its Codex metadata
  yaml="$dir/agents/openai.yaml"
  [ -f "$yaml" ] || err "$name is missing agents/openai.yaml"

  # 3. the two harnesses agree on who may invoke the skill
  if [ -f "$yaml" ]; then
    # Read the frontmatter only — a skill body may quote these fields as an example.
    claude_user_invoked=no
    frontmatter "$skill_md" |
      grep -qi '^disable-model-invocation:[[:space:]]*"\?\(true\|yes\|on\|1\)"\?[[:space:]]*$' &&
      claude_user_invoked=yes
    codex_user_invoked=no
    grep -q 'allow_implicit_invocation:[[:space:]]*false' "$yaml" && codex_user_invoked=yes
    [ "$claude_user_invoked" = "$codex_user_invoked" ] ||
      err "$name: disable-model-invocation=$claude_user_invoked but openai.yaml allow_implicit_invocation:false=$codex_user_invoked"
  fi

  # 4. promoted skills ship; unpromoted skills do not
  case " $PROMOTED_BUCKETS " in
    *" $bucket "*)
      listed_in_plugin "$name" || err "$name is in $bucket/ but missing from $PLUGIN"
      grep -q "](\./skills/$bucket/$name/SKILL\.md)" README.md ||
        err "$name is in $bucket/ but missing from README.md"
      ;;
    *)
      ! listed_in_plugin "$name" || err "$name is in $bucket/ (not promoted) but listed in $PLUGIN"
      ! grep -q "](\./skills/$bucket/$name/SKILL\.md)" README.md ||
        err "$name is in $bucket/ (not promoted) but listed in README.md"
      ;;
  esac

  # 5. every bucket README lists every skill in its bucket
  grep -q "](\./$name/SKILL\.md)" "skills/$bucket/README.md" ||
    err "$name is missing from skills/$bucket/README.md"

  # 6. skill names are unique across buckets — link-skills.sh flattens them
  case " $seen_names " in
    *" $name "*) err "duplicate skill name '$name' across buckets" ;;
  esac
  seen_names="$seen_names $name"

  # 以下の上限は Agent Skills 仕様と Anthropic の執筆ガイダンスに由来する(出典つきの
  # 要約は writing-great-skills/OFFICIAL.md)。散文で頼まず検査にしてあるのは、破った
  # スキルが仕様のバリデータに弾かれるか黙って切り捨てられるかのどちらかで、どちらも
  # 書いている最中には見えないため。

  # 7. `name` が仕様に沿う: 1〜64文字、小文字英数字と単独の中間ハイフン。
  case "$declared" in
    *[!a-z0-9-]* | -* | *- | *--*) err "$name: name '$declared' must be lowercase a-z, 0-9 and single interior hyphens" ;;
  esac
  [ "$(charlen "$declared")" -le 64 ] || err "$name: name is $(charlen "$declared") characters; the spec caps it at 64"

  # 8. `description` が非空で、仕様の上限に収まっている
  desc="$(field "$skill_md" description)"
  if [ -z "$desc" ]; then
    err "$name: description is empty; it is the only thing an agent reads to decide whether to reach for the skill"
  else
    [ "$(charlen "$desc")" -le 1024 ] || err "$name: description is $(charlen "$desc") characters; the spec caps it at 1024"
  fi

  # 9. 本文が推奨の行数の予算に収まっている
  fm_end="$(awk 'NR==1 && $0!="---" {print 0; exit} NR>1 && $0=="---" {print NR; exit}' "$skill_md")"
  body_lines="$(($(wc -l <"$skill_md") - ${fm_end:-0}))"
  [ "$body_lines" -le 500 ] || err "$name: SKILL.md body is $body_lines lines; keep it under 500 and push detail into reference files"

  # 9b. 本文がトークンの予算にも収まっている。仕様が第2層(本文)を5,000トークン未満と
  #     推奨しているのに加え、自動圧縮のあとコンテキストへ繋ぎ直されるのも各スキルの
  #     先頭5,000トークンだけである。
  body_tokens="$(tail -n +$((${fm_end:-0} + 1)) "$skill_md" | est_tokens)"
  [ "$body_tokens" -le 5000 ] ||
    err "$name: SKILL.md body is ~$body_tokens tokens; keep it under 5000 (past that, compaction re-attaches only the first 5000 and the tail is silently dropped)"

  # 10. SKILL.md がリンクする参照ファイルが実在し、スキルの中にあり、1ホップで
  #     到達できる。別の参照ファイル経由でしか届かないファイルは部分読みされ、
  #     末尾が黙って欠ける。
  lvl1=""
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in
      ../* | */../*)
        err "$name: SKILL.md links to $rel, outside its own folder; shared reference material belongs inside the skill that owns it"
        continue
        ;;
    esac
    [ -f "$dir/$rel" ] || {
      err "$name: SKILL.md links to $rel, which does not exist"
      continue
    }
    lvl1="$lvl1 $rel"
  done < <(md_links "$dir" "$skill_md")

  # 10b. スキルの中にあるすべての参照ファイルが、SKILL.md からリンクされている。
  #      10. の逆 — 置いてあるのに誰も指していないファイルを捕まえる。公式は「一度も
  #      読まれないファイルは、不要であるか signal が足りていないかのどちらか」と
  #      名指ししている。
  while IFS= read -r orphan; do
    rel="${orphan#"$dir"/}"
    case " $lvl1 " in *" $rel "*) continue ;; esac
    err "$name: $rel is not linked from SKILL.md; either point at it or delete it — an unreferenced file is one the agent never reads"
  done < <(find "$dir" -name '*.md' ! -name 'SKILL.md' ! -path "$dir/agents/*" | sort)

  for rel in $lvl1; do
    while IFS= read -r deep; do
      [ -n "$deep" ] && [ "$deep" != "SKILL.md" ] || continue
      case " $lvl1 " in *" $deep "*) continue ;; esac
      err "$name: $rel links to $deep, which SKILL.md does not link; keep references one level deep from SKILL.md"
    done < <(md_links "$dir" "$dir/$rel")

    # 14. 100行を超える参照ファイルは目次を持つ。エージェントは長い参照を頭から
    #     100行だけ読んで済ませることがあり、目次があれば、本文を読まなくても
    #     そのファイルに何がどこまで載っているかは見える。
    [ "$(wc -l <"$dir/$rel")" -gt 100 ] || continue
    grep -qiE '^#{1,3}[[:space:]]+(目次|Contents|Table of contents)[[:space:]]*$' \
      < <(strip_code "$dir/$rel") ||
      err "$name: $rel is over 100 lines with no table of contents; a partial read cannot see what else is in it"
  done
done < <(find skills -name SKILL.md -not -path '*/node_modules/*' | sort)

while IFS= read -r path; do
  [ -f "$path/SKILL.md" ] || err "$PLUGIN lists $path, which has no SKILL.md"
done < <(sed -n 's|^[[:space:]]*"\(\./skills/[^"]*\)",\{0,1\}$|\1|p' "$PLUGIN")

# 11. `version` はどこにも無い — plugin.json と marketplace.json の両方。
#     コミット SHA をバージョンとして扱わせる条件が「両方から省く」ことで、片方だけ
#     書いても更新は止まる。see CLAUDE.md
! grep -q '^[[:space:]]*"version"' "$PLUGIN" ||
  err "$PLUGIN has a \"version\" field; it pins the cache key and stops updates from reaching installed users"
! grep -q '"version"' .claude-plugin/marketplace.json ||
  err ".claude-plugin/marketplace.json has a \"version\" field; the commit-SHA versioning needs it omitted from the marketplace entry too"

# 12. 昇格していないバケットはトップレベルの README から辿れる。昇格済みの
#     バケットは自分の節を持つので個々のスキルの掲載を 4. が見ているが、昇格して
#     いないバケットはバケット単位でしか載らないため、丸ごと落ちても誰も気づかない
#     (emdash/ は実際にそうやって抜けていた)。
while IFS= read -r bucket_readme; do
  bucket="$(basename "$(dirname "$bucket_readme")")"
  case " $PROMOTED_BUCKETS " in
    *" $bucket "*) continue ;;
  esac
  grep -q "](\./skills/$bucket/README\.md)" README.md ||
    err "skills/$bucket/ is not linked from README.md; an unpromoted bucket nobody lists is invisible"
done < <(find skills -mindepth 2 -maxdepth 2 -name README.md | sort)

# 13. コードフェンスが閉じている。閉じ忘れると以降の本文がまるごとコードブロックに
#     飲まれ、見出しも指示も本文として読まれなくなる。
while IFS= read -r md; do
  strip_code "$md" >/dev/null ||
    err "$md has an unclosed code fence; everything after it reads as code"
done < <(find skills -name '*.md' -not -path '*/node_modules/*' | sort)

# 14. `.claude/skills/` がこのリポジトリのスキルと一致している。ここが実体への
#     シンボリックリンクで埋まっているあいだだけ、このリポジトリで作業する
#     エージェントが自分のスキルを使える。スキルを足したり改名したりすると
#     真っ先にずれ、しかも「呼べない」以外の症状が出ないので検査で捕まえる。
scripts/sync-project-skills.sh --check ||
  err ".claude/skills/ is out of sync with skills/; run scripts/sync-project-skills.sh"

# 15. 出力スタイルが出荷され、このリポジトリ自身でも選ばれている。壊れたときの症状が
#     「効いていない」だけで黙って通り過ぎるので、sync スクリプトを持たせず検査で見る。
grep -q '"outputStyles"' "$PLUGIN" ||
  err "$PLUGIN does not declare \"outputStyles\"; the style ships only if the manifest points at it"

while IFS= read -r style; do
  name="$(basename "$style" .md)"
  link=".claude/output-styles/$name.md"
  want="../../output-styles/$name.md"

  # 出力スタイルは既定でハーネス組み込みのエンジニアリング指示を **外す**。付け忘れ
  # ると、コメントの規律を足すつもりで既存の規律を消すことになる。see CLAUDE.md
  [ "$(field "$style" "keep-coding-instructions")" = "true" ] ||
    err "$style does not set keep-coding-instructions: true; it would drop the harness's built-in engineering instructions"

  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$want" ] ||
      err "$link points at $(readlink "$link"), not $want"
  else
    err "$link is missing or is not a symlink; this repository cannot use its own output style"
  fi
done < <(find output-styles -name '*.md' | sort)

selected="$(sed -n 's/^[[:space:]]*"outputStyle":[[:space:]]*"\([^"]*\)".*/\1/p' .claude/settings.json | head -1)"
if [ -z "$selected" ]; then
  err ".claude/settings.json does not set \"outputStyle\"; a project style that nobody selects never loads"
elif [ ! -f "output-styles/$selected.md" ]; then
  err ".claude/settings.json selects the \"$selected\" output style, which does not exist under output-styles/"
fi

# 出荷しない側の後始末 — リンクだけ残ると、実体の無いスタイルが名前だけ生き続ける
if [ -d ".claude/output-styles" ]; then
  while IFS= read -r stale; do
    name="$(basename "$stale" .md)"
    [ -f "output-styles/$name.md" ] ||
      err "$stale is stale (no such output style under output-styles/)"
  done < <(find .claude/output-styles -mindepth 1 -maxdepth 1 | sort)
fi

# 16. コメントの判定基準が、常駐する3か所すべてに本文として載っている。スキルは呼ばれて
#     初めて読まれるが、コメントを書く場面でモデルはスキルを呼ばない — 参照 1 行に痩せた
#     瞬間に規律は効かなくなり、しかも症状が出ない。4本の柱を別に見るのはテストの宛先を
#     その1行だけが運んでいるため、優先順位の句を別に見るのはハーネス側の「周囲のコードに
#     合わせろ」と正面からぶつかる唯一の行だからである。
#     see CLAUDE.md, .agents/adr/0003-never-start-from-init-output.md
for resident in output-styles/kjfsm.md CLAUDE.md skills/engineering/setup-skills/SKILL.md; do
  grep -q 'コミットログには Why、コードコメントには Why not' "$resident" ||
    err "$resident lost the four pillars; without them tests have no destination and the routing lives only in a skill nobody calls"
  grep -q 'コードを読めば分かることは書かない' "$resident" ||
    err "$resident lost the comment rule's opening test; the convention only works while its body is resident"
  grep -q '採らなかった素直な書き方' "$resident" ||
    err "$resident lost what a comment may carry; a pointer to where-to-write-what does not fire on its own"
  grep -q 'コメントの密度ではない' "$resident" ||
    err "$resident lost the precedence clause; without it the harness's match-the-surrounding-code line and this rule point opposite ways and the model picks silently"
done

# 17. コメントのフックが、出荷側(プラグイン)と自家用(このリポジトリ)の両方から
#     実在する実行可能スクリプトを指している。そして 4本の柱を復唱していない —
#     復唱した瞬間にこれは常駐 3か所(検査 16.)の同期先 4つ目になり、フックが
#     黙って壊れた日に、揃っていない本文だけが残る。see CLAUDE.md
hook_script="hooks/nudge-comment-check.sh"
if [ ! -x "$hook_script" ]; then
  err "$hook_script is missing or not executable; a hook that cannot run fails silently"
else
  grep -q 'コミットログには Why' "$hook_script" &&
    err "$hook_script restates the four pillars; it would become a fourth copy to keep in sync (see invariant 16)"
fi

for manifest in hooks/hooks.json .claude/settings.json; do
  grep -q 'nudge-comment-check.sh' "$manifest" ||
    err "$manifest does not wire $hook_script; the repository would ship a discipline it does not run on itself"
done

if [ "$fail" -eq 0 ]; then
  echo "OK: all invariants hold ($(find skills -name SKILL.md | wc -l | tr -d ' ') skills)"
fi
exit "$fail"
