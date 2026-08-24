#!/usr/bin/env python3
"""本家 mattpocock/skills の2リビジョン間から、実質変更だけを抜き出す。

行単位の diff では測れない。本家は em-dash(`—`)を `:` / `,` に置き換える
文体スイープを繰り返しており、ed37663..5b15a47 では変更行の過半がそれだった。
日本語のこのフォークには1行も当たらないので、句読点だけの差を落とさないと
実質変更が埋もれる。

各リビジョンのファイルを段落単位で正規化してから比較する。行単位でペアリング
すると、段落の折り返しが変わっただけで「追加」と数えられ、誤検知が出る。

  usage: scripts/upstream-diff.py <本家のクローン先> <base> <head>

base は .agents/upstream-sync.md の「最後に突き合わせた地点」。既定値は
持たせない — 焼き付けた既定値は、次に同期した日から黙って嘘になる。
"""

import difflib
import re
import subprocess
import sys

PUNCT = re.compile(r'[—–:;,.()"\'`*_]')
WS = re.compile(r"\s+")


def normalize(paragraph):
    return WS.sub(" ", PUNCT.sub(" ", paragraph.lower())).strip()


def git(repo, *args):
    return subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True
    )


def tracked(repo, rev):
    out = git(repo, "ls-tree", "-r", "--name-only", rev).stdout.split()
    return {f for f in out if f.startswith("skills/") and f.endswith((".md", ".sh", ".yaml", ".cjs"))}


def read(repo, rev, path):
    r = git(repo, "show", f"{rev}:{path}")
    return r.stdout if r.returncode == 0 else None


def paragraphs(text):
    return [(normalize(p), p) for p in (l.strip() for l in text.split("\n")) if p]


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    repo, base, head = sys.argv[1:4]

    common = tracked(repo, base) & tracked(repo, head)
    changed = 0
    for path in sorted(common):
        before, after = read(repo, base, path), read(repo, head, path)
        if before is None or after is None or before == after:
            continue
        a, b = paragraphs(before), paragraphs(after)
        ops = difflib.SequenceMatcher(None, [x[0] for x in a], [x[0] for x in b]).get_opcodes()
        removed = [a[i][1] for tag, i1, i2, _, _ in ops if tag in ("replace", "delete") for i in range(i1, i2)]
        added = [b[j][1] for tag, _, _, j1, j2 in ops if tag in ("replace", "insert") for j in range(j1, j2)]
        if not removed and not added:
            continue
        changed += 1
        print(f"\n########## {path}  (-{len(removed)} / +{len(added)})")
        for line in removed:
            print("  - " + line)
        for line in added:
            print("  + " + line)

    only_head = tracked(repo, head) - tracked(repo, base)
    only_base = tracked(repo, base) - tracked(repo, head)
    print(f"\n---- 実質変更のあった既存ファイル: {changed}")
    print(f"---- {head} にだけあるファイル: {len(only_head)}")
    for f in sorted(only_head):
        print("  + " + f)
    print(f"---- {base} にだけあったファイル: {len(only_base)}")
    for f in sorted(only_base):
        print("  - " + f)


if __name__ == "__main__":
    main()
