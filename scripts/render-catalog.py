#!/usr/bin/env python3
"""スキル一覧を SKILL.md の frontmatter から書き出す。

一覧の各項目は `description` そのものである。要約を別に書くと、トップの README と
バケットの README とで同じスキルの要約が2部になり、片方だけ直る日が来る。

書き出し先:
  - README.md の `<!-- catalog:begin <バケット> -->` 〜 `<!-- catalog:end -->`
  - skills/**/README.md の `<!-- catalog:begin -->` 〜 `<!-- catalog:end -->`
  - .claude-plugin/plugin.json の `skills` 配列(昇格済みのバケットだけ)

使い方:
  scripts/render-catalog.py           書き出す
  scripts/render-catalog.py --check   書き込まず、ずれを報告して非ゼロで抜ける
"""

import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
# check-invariants.sh の PROMOTED_BUCKETS と同じ集合。
PROMOTED = ["kjfsm-skills/engineering", "kjfsm-skills/productivity"]
PLUGIN = REPO / ".claude-plugin/plugin.json"

BEGIN = re.compile(r"<!-- catalog:begin(?: (\S+))? -->")
END = "<!-- catalog:end -->"


def frontmatter(path):
    lines = path.read_text(encoding="utf-8").split("\n")
    if lines[0] != "---":
        return {}
    fields = {}
    for line in lines[1:]:
        if line == "---":
            break
        m = re.match(r"^([a-z-]+):\s*(.*)$", line)
        if not m:
            continue
        value = m.group(2)
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1].replace('\\"', '"')
        fields[m.group(1)] = value
    return fields


def skills_in(bucket):
    out = []
    for skill_md in sorted((REPO / "skills" / bucket).glob("*/SKILL.md")):
        fm = frontmatter(skill_md)
        user_invoked = fm.get("disable-model-invocation", "").lower() in ("true", "yes", "on", "1")
        out.append((skill_md.parent.name, fm.get("description", ""), user_invoked))
    return out


def entries(bucket, prefix):
    skills = skills_in(bucket)
    line = lambda name, desc: f"- **[{name}]({prefix}{name}/SKILL.md)** — {desc}"
    if bucket not in PROMOTED:
        return "\n".join(line(n, d) for n, d, _ in skills) or "(いまは無い)"
    groups = []
    for label, want in (("ユーザー呼び出し型", True), ("モデル呼び出し型", False)):
        items = [line(n, d) for n, d, u in skills if u == want]
        if items:
            groups.append(f"**{label}**\n\n" + "\n".join(items))
    return "\n\n".join(groups)


def render_regions(path, bucket_of, required):
    text = path.read_text(encoding="utf-8")
    found = {m.group(1) for m in BEGIN.finditer(text)}
    for want in required:
        if want not in found:
            marker = f"<!-- catalog:begin {want} -->" if want else "<!-- catalog:begin -->"
            sys.exit(f"{path.relative_to(REPO)} has no {marker}; a bucket nobody lists is invisible")
    out, pos = [], 0
    for m in BEGIN.finditer(text):
        end = text.find(END, m.end())
        if end < 0:
            sys.exit(f"{path}: {m.group(0)} has no {END}")
        bucket, prefix = bucket_of(m.group(1))
        out.append(text[pos : m.end()])
        out.append("\n\n" + entries(bucket, prefix) + "\n\n")
        pos = end
    out.append(text[pos:])
    return text, "".join(out)


def render_plugin():
    text = PLUGIN.read_text(encoding="utf-8")
    paths = [f"./skills/{b}/{n}" for b in PROMOTED for n, _, _ in skills_in(b)]
    body = ",\n".join(f"    {json.dumps(p)}" for p in paths)
    new = re.sub(r'"skills": \[[^\]]*\]', lambda _: f'"skills": [\n{body}\n  ]', text, count=1)
    return text, new


def main():
    check = sys.argv[1:] == ["--check"]
    if sys.argv[1:] and not check:
        sys.exit("usage: render-catalog.py [--check]")

    targets = [(REPO / "README.md", render_regions(REPO / "README.md", lambda b: (b, f"./skills/{b}/"), PROMOTED))]
    for readme in sorted((REPO / "skills").glob("**/README.md")):
        bucket = str(readme.parent.relative_to(REPO / "skills"))
        targets.append((readme, render_regions(readme, lambda _, b=bucket: (b, "./"), [None])))
    targets.append((PLUGIN, render_plugin()))

    drift = False
    for path, (old, new) in targets:
        if old == new:
            continue
        drift = True
        rel = path.relative_to(REPO)
        if check:
            print(f"DRIFT: {rel} is not what render-catalog.py would write", file=sys.stderr)
        else:
            path.write_text(new, encoding="utf-8")
            print(f"rendered {rel}")

    if check and drift:
        print("run scripts/render-catalog.py to fix", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
