#!/usr/bin/env bash
set -uo pipefail

# Checks the repository invariants that CLAUDE.md and .agents/invocation.md
# state in prose. Run it after adding, renaming, promoting, or deleting a skill,
# and after touching either manifest.
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
  # frontmatter <file> — prints the lines between the opening and closing ---
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1' "$1"
}

field() {
  # field <file> <key> — prints the frontmatter value for <key>, unquoted
  frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1 | sed 's/^"\(.*\)"$/\1/'
}

listed_in_plugin() {
  grep -q "\"\./skills/[a-z-]*/$1\"" "$PLUGIN"
}

# ---------------------------------------------------------------- per skill --
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
done < <(find skills -name SKILL.md -not -path '*/node_modules/*' | sort)

# ------------------------------------------------------------ manifest side --
while IFS= read -r path; do
  [ -f "$path/SKILL.md" ] || err "$PLUGIN lists $path, which has no SKILL.md"
done < <(sed -n 's|^[[:space:]]*"\(\./skills/[^"]*\)",\{0,1\}$|\1|p' "$PLUGIN")

# 7. plugin.json carries no `version` — see CLAUDE.md
! grep -q '^[[:space:]]*"version"' "$PLUGIN" ||
  err "$PLUGIN has a \"version\" field; it pins the cache key and stops updates from reaching installed users"

if [ "$fail" -eq 0 ]; then
  echo "OK: all invariants hold ($(find skills -name SKILL.md | wc -l | tr -d ' ') skills)"
fi
exit "$fail"
