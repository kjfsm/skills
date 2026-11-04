#!/usr/bin/env bash
#   cross-slice.sh <作業ディレクトリ>
#
# 1つのスライスの中でだけ現れる対象は数えない — そのスライスを読んだエージェントが
# 既に重複を見ている。ファイルをまたぐだけの対象まで渡すと、突き合わせが
# スライスの判定をやり直すだけになる。

set -euo pipefail
cd "$1"

shopt -s nullglob
slices=(slice-*.tsv)
[ ${#slices[@]} -gt 0 ] || { echo "slice-*.tsv が無い" >&2; exit 1; }
gap_files=(gaps-*.tsv)

cat "${slices[@]}" > all.tsv
# /dev/null を先に置く: gaps-*.tsv が1つも無いと cat が引数なしで標準入力を待つ。
cat /dev/null "${gap_files[@]}" > gaps.tsv

{
  # 列 4 が空か `-` の行を束ねると、無関係なテストが1つの「共通の対象」になる。
  for f in "${slices[@]}"; do cut -f4 "$f" | awk 'NF && $0 != "-"' | sort -u; done | sort | uniq -d

  # 欠けは、別のスライスの表が同じ対象を既に守っているかもしれない。
  for g in "${gap_files[@]}"; do
    own="slice-${g#gaps-}"
    others=()
    for f in "${slices[@]}"; do [ "$f" = "$own" ] || others+=("$f"); done
    [ ${#others[@]} -gt 0 ] || continue
    comm -12 <(cut -f1 "$g" | sort -u) <(cut -f4 "${others[@]}" | sort -u)
  done
} | sort -u > shared-targets.txt

awk -F'\t' 'NR==FNR { t[$0]; next } $4 in t' shared-targets.txt all.tsv |
  sort -t$'\t' -k4,4 > groups.tsv
awk -F'\t' 'NR==FNR { t[$0]; next } $1 in t' shared-targets.txt gaps.tsv |
  sort -t$'\t' -k1,1 > groups-gaps.tsv

wc -l < shared-targets.txt
