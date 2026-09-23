#!/usr/bin/env bash
set -euo pipefail

#   scripts/eval.sh --case start-from-zero --runs 1 --ablation none
#   scripts/eval.sh --tag uplift
#
# リポジトリをそのまま対象にしない: eval の実行は他のプラグインを一切載せないので、
# `dependencies` の mattpocock-skills が満たせず、kjfsm-skills ごと無効になる
# (エラーは出ず、スキルが一覧に無いまま全ケースが 0 点になる)。依存を外した写しを
# 一時ディレクトリに組んで、そちらを対象にする。本家のスキルを呼ぶ手順はこの写しでは
# 何も起きないので、ケースは kjfsm のスキル単体で答えが出るものに限る。

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/.claude-plugin"
cp -r "$REPO/skills" "$REPO/agents" "$REPO/hooks" "$REPO/output-styles" "$BUILD/"
rsync -a --exclude results "$REPO/evals/" "$BUILD/evals/"
python3 - "$REPO/.claude-plugin/plugin.json" "$BUILD/.claude-plugin/plugin.json" <<'EOF'
import json, sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
manifest.pop("dependencies", None)
json.dump(manifest, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
EOF

status=0
claude plugin eval "$BUILD" --trust-plugin "$@" || status=$?

if [ -d "$BUILD/evals/results" ]; then
  mkdir -p "$REPO/evals/results"
  cp -r "$BUILD/evals/results/." "$REPO/evals/results/"
  echo "results copied to evals/results/"
fi
exit "$status"
