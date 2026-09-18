#!/usr/bin/env python3
"""Run drizzle-kit generate under a pty and answer its select prompts from --answer.

drizzle-kit 0.31.x renders rename-vs-create prompts with a raw-mode reader and
refuses to run at all when stdin is not a tty, so a pty is the only way to reach
them from an agent. Answers are matched against the option text rather than an
index because the option order is not part of drizzle-kit's contract.
"""

import argparse
import errno
import os
import pty
import re
import select
import sys
import time

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
DOWN, ENTER = b"\x1b[B", b"\r"
IDLE_UNTIL_PROMPT = 0.7
HARD_TIMEOUT = 300


def visible(chunk: bytes) -> str:
    return ANSI.sub("", chunk.decode("utf-8", "replace")).replace("\r", "")


def options(screen: str) -> list[str]:
    """Option lines of the pending prompt: the trailing run of `❯ `/`  ` lines."""
    found = []
    for line in reversed(screen.splitlines()):
        if re.match(r"^[❯>]?\s{1,2}[+~\-]", line):
            found.append(line.strip())
        elif found:
            break
    return list(reversed(found))


def question(screen: str) -> str:
    for line in reversed(screen.splitlines()):
        if line.strip().endswith("?"):
            return line.strip()
    return "(question not found)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--answer",
        action="append",
        default=[],
        metavar="SUBSTRING",
        help="matched case-insensitively against one option line; repeat once per prompt, in order",
    )
    ap.add_argument("--cwd", default=".")
    ap.add_argument("rest", nargs=argparse.REMAINDER, help="-- <args passed to drizzle-kit generate>")
    args = ap.parse_args()

    extra = args.rest[1:] if args.rest[:1] == ["--"] else args.rest
    argv = ["npx", "drizzle-kit", "generate", *extra]

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(args.cwd)
        os.environ["FORCE_COLOR"] = "0"
        os.execvp(argv[0], argv)

    transcript, screen, pending, deadline = [], "", list(args.answer), time.time() + HARD_TIMEOUT
    unanswered = None
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], IDLE_UNTIL_PROMPT)
        if ready:
            try:
                chunk = os.read(fd, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            text = visible(chunk)
            transcript.append(text)
            screen += text
            continue

        # Output has gone quiet. A pending prompt is waiting for a keystroke.
        opts = options(screen)
        if not opts:
            continue
        if not pending:
            unanswered = (question(screen), opts)
            break
        want = pending.pop(0).lower()
        matches = [i for i, o in enumerate(opts) if want in o.lower()]
        if len(matches) != 1:
            unanswered = (f"--answer {want!r} matched {len(matches)} options, need exactly 1", opts)
            break
        cursor = next((i for i, o in enumerate(opts) if o.startswith(("❯", ">"))), 0)
        os.write(fd, DOWN * ((matches[0] - cursor) % len(opts)) + ENTER)
        screen = ""

    os.close(fd)
    _, status = os.waitpid(pid, 0) if unanswered is None else (0, 0)
    sys.stdout.write("".join(transcript))

    if unanswered:
        head, opts = unanswered
        print(f"\nunanswered_prompt: {head}", file=sys.stderr)
        for o in opts:
            print(f"  {o}", file=sys.stderr)
        print("\nRe-run with one --answer per prompt, in order.", file=sys.stderr)
        return 2
    if pending:
        print(f"\nunused answers: {pending}", file=sys.stderr)
        return 2
    return os.waitstatus_to_exitcode(status)


if __name__ == "__main__":
    sys.exit(main())
