#!/usr/bin/env bash
set -uo pipefail

# このリポジトリのスキルを、このリポジトリ自身で有効にする。
#
# Claude Code がプロジェクトスキルとして拾うのは `.claude/skills/<名前>/SKILL.md`
# だけで、このリポジトリの `skills/<バケット>/<名前>/` は見に行かない。だから
# `.claude/skills/` を実体へのシンボリックリンクで埋める — 公式がこの位置での
# シンボリックリンクを追従対象として認めており、実体は1つのままでいい。
#
# `scripts/link-skills.sh` とは宛先が違う。あちらは端末全体(`~/.claude/skills`)
# 向けの、メンテナ専用のセットアップである。こちらはリポジトリに **コミットされる**
# ので、クローンした誰にでも、`~` を書き換えられないクラウドセッションにも届く。
#
# `deprecated/` は除く — link-skills.sh と同じ規則である。それ以外は昇格していない
# バケットも含めて張る: `in-progress/` の下書きは、ここで使ってみて初めて直せる。
#
# 使い方:
#   scripts/sync-project-skills.sh           リンクを張り直す(不要なものは消す)
#   scripts/sync-project-skills.sh --check    書き込まず、ずれを報告して非ゼロで抜ける

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

DEST=".claude/skills"

check=0
if [ "${1:-}" = "--check" ]; then
  check=1
elif [ "$#" -gt 0 ]; then
  echo "usage: $0 [--check]" >&2
  exit 2
fi

drift=0
note() {
  if [ "$check" -eq 1 ]; then
    echo "DRIFT: $1" >&2
    drift=1
  else
    echo "$1"
  fi
}

# 連想配列は bash 4 以降にしか無く、macOS の bash は 3.2 で止まっているので、
# link-skills.sh と同じく添字配列を2本並べる。
names=()
targets=()
while IFS= read -r skill_md; do
  src="${skill_md%/SKILL.md}"
  names+=("$(basename "$src")")
  # `.claude/skills/` は2階層下なので、`../..` がリポジトリルートに解決される。
  # 相対にしておくとクローン先のパスに依存しない。
  targets+=("../../$src")
done < <(find skills -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' | sort)

if [ "${#names[@]}" -eq 0 ]; then
  echo "error: no skills found under skills/; run this from a full checkout" >&2
  exit 1
fi

if [ "$check" -eq 0 ]; then
  mkdir -p "$DEST"
elif [ ! -d "$DEST" ]; then
  note "$DEST is missing"
  echo "run scripts/sync-project-skills.sh to fix" >&2
  exit 1
fi

for i in "${!names[@]}"; do
  name="${names[$i]}"
  target="${targets[$i]}"
  link="$DEST/$name"

  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    continue
  fi

  if [ -e "$link" ] && [ ! -L "$link" ]; then
    note "$link exists but is not a symlink"
    [ "$check" -eq 1 ] || rm -rf "$link"
  else
    note "$link -> $target"
  fi

  [ "$check" -eq 1 ] || ln -sfn "$target" "$link"
done

# 消す — 改名や退役でリンクだけ残ると、実体の無いスキルが名前だけ生き続ける
if [ -d "$DEST" ]; then
  while IFS= read -r stale; do
    [ -n "$stale" ] || continue
    name="$(basename "$stale")"
    known=0
    for n in "${names[@]}"; do
      if [ "$n" = "$name" ]; then
        known=1
        break
      fi
    done
    [ "$known" -eq 1 ] && continue
    note "$stale is stale (no such skill)"
    [ "$check" -eq 1 ] || rm -rf "$stale"
  done < <(find "$DEST" -mindepth 1 -maxdepth 1 | sort)
fi

if [ "$check" -eq 1 ]; then
  if [ "$drift" -ne 0 ]; then
    echo "run scripts/sync-project-skills.sh to fix" >&2
    exit 1
  fi
  exit 0
fi

echo "synced ${#names[@]} skills into $DEST"
