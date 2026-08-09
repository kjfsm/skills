#!/usr/bin/env python3
"""あるスキルの description が、発火すべきときに発火し、すべきでないときに黙るかを測る。

なぜ skill-creator の run_eval.py を使わないか
------------------------------------------------
skill-creator にも同じ目的のトリガー eval があるが、その判定は「最初のツール呼び出しが
Skill か Read でなければ、その時点で非発火と断定する」実装になっている。中身のある
作業ディレクトリではモデルはまず Bash で状況を掴んでから発火するので、実際には発火して
いる実行が軒並み「非発火」として記録される。

実測: tdd スキルに教科書どおりの TDD クエリを当てて 0/9。ストリームを直接見ると Skill は
呼ばれており、順序は Bash -> Read -> Read -> Skill だった。writing-great-skills でも
同じ理由で 0/10 が出ていた。どちらも description ではなく計測の問題である。

このスクリプトはストリームを最後まで走査し、実行中に一度でも対象スキルが呼ばれたかを見る。
あわせて「代わりに発火した他のスキル」を記録する — スキルどうしの競合を調べるのが本来の
目的なので、誰が勝ったかが分からなければ測る意味がない。

使い方
------
    python3 .agents/evals/measure-triggering.py \
        --skill-path skills/productivity/writing-great-skills \
        --eval-set .agents/evals/writing-great-skills-trigger.json \
        --model claude-opus-5

eval セットは {"query": ..., "should_trigger": true|false} の配列。should-not-trigger は
「近いが別のスキルが正解」の引っかけにする — 明らかに無関係なクエリは何も検証しない。

注意
----
実行ごとに、合成したコマンド1本だけを置いた空のテンポラリディレクトリで claude -p を回す。
測っているのが description の力だけになるが、その分だけ実際の使用環境より発火に有利である
(ファイルのあるリポジトリでは、モデルは探索を挟んでから発火する)。
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def read_description(skill_md: Path) -> str:
    """SKILL.md の frontmatter から description を取り出す。"""
    lines = skill_md.read_text().splitlines()
    if not lines or lines[0] != "---":
        raise SystemExit(f"{skill_md} に frontmatter がない")
    for i, line in enumerate(lines[1:], start=1):
        if line == "---":
            break
        m = re.match(r"^description:\s*(.*)$", line)
        if m:
            return m.group(1).strip().strip('"')
    raise SystemExit(f"{skill_md} に description がない")


def run_once(query: str, name: str, description: str, model: str, timeout: int) -> dict:
    workspace = Path(tempfile.mkdtemp(prefix="trigger-"))
    commands = workspace / ".claude" / "commands"
    commands.mkdir(parents=True)
    indented = "\n  ".join(description.splitlines())
    (commands / f"{name}.md").write_text(
        f"---\ndescription: |\n  {indented}\n---\n\n# {name}\n\nThis skill handles: {description}\n"
    )

    # CLAUDECODE を落とすと claude -p を Claude Code セッションの中から起動できる。
    # あのガードは対話端末の衝突を防ぐためのもので、サブプロセスとしての利用は安全。
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose"]
    if model:
        cmd += ["--model", model]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, cwd=workspace, env=env, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"target": False, "skills": [], "first_tool": None, "timeout": True}

    skills, tools = [], []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "assistant":
            continue
        for block in event.get("message", {}).get("content", []):
            if block.get("type") != "tool_use":
                continue
            tools.append(block.get("name"))
            if block.get("name") == "Skill":
                skills.append(str(block.get("input", {}).get("skill", "")))
    return {
        "target": any(name in s for s in skills),
        "skills": skills,
        "first_tool": tools[0] if tools else None,
        "timeout": False,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skill-path", required=True, help="スキルのディレクトリ")
    ap.add_argument("--eval-set", required=True, help="クエリの JSON 配列")
    ap.add_argument("--description", default=None, help="SKILL.md の代わりに測る description")
    ap.add_argument("--model", default=None, help="claude -p に渡すモデル")
    ap.add_argument("--runs-per-query", type=int, default=3)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--timeout", type=int, default=180)
    args = ap.parse_args()

    skill_dir = Path(args.skill_path)
    name = skill_dir.name
    description = args.description or read_description(skill_dir / "SKILL.md")
    queries = json.loads(Path(args.eval_set).read_text())

    def work(item: dict) -> dict:
        runs = [
            run_once(item["query"], name, description, args.model, args.timeout)
            for _ in range(args.runs_per_query)
        ]
        return {
            "query": item["query"],
            "should_trigger": item["should_trigger"],
            "hits": sum(1 for r in runs if r["target"]),
            "runs": len(runs),
            "timeouts": sum(1 for r in runs if r["timeout"]),
            "no_tool_calls": sum(1 for r in runs if r["first_tool"] is None),
            "other_skills": sorted({s for r in runs for s in r["skills"] if name not in s}),
        }

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(work, queries))

    positives = [r for r in results if r["should_trigger"]]
    negatives = [r for r in results if not r["should_trigger"]]
    majority = args.runs_per_query / 2
    summary = {
        "skill": name,
        "description_chars": len(description),
        "should_trigger_passed": sum(1 for r in positives if r["hits"] > majority),
        "should_trigger_total": len(positives),
        "should_not_trigger_passed": sum(1 for r in negatives if r["hits"] <= majority),
        "should_not_trigger_total": len(negatives),
        # ツールを1つも呼ばなかった実行は「正しく黙った」ではなく、何も検証していない。
        "uninformative_runs": sum(r["no_tool_calls"] for r in results),
        "timeouts": sum(r["timeouts"] for r in results),
    }
    json.dump(
        {"description": description, "summary": summary, "results": results},
        sys.stdout, ensure_ascii=False, indent=2,
    )
    print(file=sys.stderr)
    print(json.dumps(summary, ensure_ascii=False, indent=2), file=sys.stderr)


if __name__ == "__main__":
    main()
