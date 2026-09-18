#!/usr/bin/env python3
"""Apply a migrations directory to a throwaway local D1 and print a fingerprint of the result.

Two runs of this — one before a squash, one after — are the only evidence that the
squash preserved the database. Quoting and whitespace are normalised away because
drizzle-kit emits backtick-quoted DDL while hand-written migrations usually do not;
that difference is cosmetic and would otherwise bury the differences that matter.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys

SCHEMA_QUERY = (
    "SELECT type, name, COALESCE(sql, '') AS ddl FROM sqlite_master "
    "WHERE name NOT LIKE 'sqlite_%' AND name NOT IN ('d1_migrations', '_cf_METADATA') "
    "ORDER BY type, name"
)


def wrangler(args: list[str], state: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["npx", "--no-install", "wrangler", *args, "--local", "--persist-to", state],
        capture_output=True,
        text=True,
    )


def execute(sql: str, db: str, state: str) -> list[list[dict]]:
    """Run one or more `;`-separated statements; returns one result set per statement."""
    done = wrangler(["d1", "execute", db, "--json", "--command", sql], state)
    if done.returncode != 0:
        sys.stderr.write(done.stdout + done.stderr)
        sys.exit(done.returncode)
    return [batch["results"] for batch in json.loads(done.stdout)]


def normalise(ddl: str) -> str:
    """Strip identifier quoting and punctuation spacing so cosmetic DDL differences do not read as changes.

    drizzle-kit and hand-written SQL disagree on backticks and on the space after a comma;
    neither changes the database. Column ORDER is left alone — it genuinely differs between
    a column added by ALTER and the same column regenerated from the schema.
    """
    ddl = re.sub(r"[`\"\[\]]", "", re.sub(r"\s+", " ", ddl))
    return re.sub(r"\s*([(),])\s*", r"\1 ", ddl).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--database", required=True, help="d1_databases[].database_name from the wrangler config")
    ap.add_argument("--state", required=True, help="throwaway directory for this run's local D1; deleted first")
    ap.add_argument("--migrations", help="override migrations_dir")
    args = ap.parse_args()

    shutil.rmtree(args.state, ignore_errors=True)

    apply_args = ["d1", "migrations", "apply", args.database]
    if args.migrations:
        apply_args += ["--migrations-dir", args.migrations]
    done = wrangler(apply_args, args.state)
    if done.returncode != 0:
        sys.stderr.write(done.stdout + done.stderr)
        print("\napply failed — this migration set does not build an empty database.", file=sys.stderr)
        return 1

    objects = execute(SCHEMA_QUERY, args.database, args.state)[0]
    lines = [f'{o["type"]} {o["name"]} :: {normalise(o["ddl"])}' for o in objects]

    # One statement per table rather than one UNION: D1 caps the number of terms in a
    # compound SELECT, and a schema with enough tables trips it.
    tables = sorted(o["name"] for o in objects if o["type"] == "table")
    if tables:
        counts = execute("; ".join(f"SELECT COUNT(*) AS n FROM `{t}`" for t in tables),
                         args.database, args.state)
        lines += [f"rows {t} = {c[0]['n']}" for t, c in zip(tables, counts)]

    print("\n".join(sorted(lines)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
