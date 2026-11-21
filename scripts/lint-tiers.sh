#!/usr/bin/env bash
# Drift lint: checks that the commands, agent files, README, and model-tiers.tsv agree.
# Usage: scripts/lint-tiers.sh   (no arguments; works from any directory)
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1

TSV=model-tiers.tsv
COMMANDS="commands/analyze.md commands/sanitize.md"
AGENTS="agents/analyzer.md agents/sanitizer.md"
README=README.md
COUNT=0

fail() {
  echo "LINT FAIL $1: $2"
  COUNT=$((COUNT + 1))
}

# True when role $1 is a whole word on a README line that starts with "| <tier> |".
readme_has_role() {
  grep -E '^[[:space:]]*\|[[:space:]]*(deep|standard|light)[[:space:]]*\|' "$README" |
    grep -Eq "(^|[^a-z0-9-])$1(\$|[^a-z0-9-])"
}

TIERS=$(awk '/^[[:space:]]*#/ || NF == 0 {next} $1 == "tier" {print $2, $3, $4}' "$TSV")
ROLES=$(awk '/^[[:space:]]*#/ || NF == 0 {next} $1 == "role" {print $2, $3}' "$TSV")
ROLE_NAMES=$(awk '{print $1}' <<<"$ROLES")
TIER_NAMES=$(awk '{print $1}' <<<"$TIERS")

# Names that follow "Role: " in the two command files.
PROMPT_NAMES=$(cat $COMMANDS | grep -Eo 'Role: [a-z][a-z0-9-]*' | sed 's/^Role: //' | sort -u)

# role-without-row
for n in $PROMPT_NAMES; do
  grep -Fxq "$n" <<<"$ROLE_NAMES" || fail role-without-row "$n"
done

# row-without-prompt
for n in $(sort -u <<<"$ROLE_NAMES"); do
  grep -Fxq "$n" <<<"$PROMPT_NAMES" || fail row-without-prompt "$n"
done

# duplicate-row
for n in $(sort <<<"$ROLE_NAMES" | uniq -d); do
  fail duplicate-row "$n"
done

# unknown-tier
while read -r name tier; do
  [ -z "$name" ] && continue
  grep -Fxq "$tier" <<<"$TIER_NAMES" || fail unknown-tier "$name ($tier)"
done <<<"$ROLES"

# agent-default
read -r DEEP_MODEL DEEP_EFFORT <<<"$(awk '$1 == "deep" {print $2, $3}' <<<"$TIERS")"
for f in $AGENTS; do
  fm=$(awk '/^---[[:space:]]*$/ {c++; next} c == 1 {print} c >= 2 {exit}' "$f")
  m=$(sed -n 's/^model:[[:space:]]*//p' <<<"$fm" | sed 's/[[:space:]]*$//')
  e=$(sed -n 's/^effort:[[:space:]]*//p' <<<"$fm" | sed 's/[[:space:]]*$//')
  if [ "$m" != "$DEEP_MODEL" ] || [ "$e" != "$DEEP_EFFORT" ]; then
    fail agent-default "$f"
  fi
done

# readme-tier
while read -r t m e; do
  [ -z "$t" ] && continue
  grep -Eq "^[[:space:]]*\|[[:space:]]*$t[[:space:]]*\|[[:space:]]*$m[[:space:]]*\|[[:space:]]*$e[[:space:]]*\|" "$README" ||
    fail readme-tier "$t"
done <<<"$TIERS"

# readme-role
for n in $(sort -u <<<"$ROLE_NAMES"); do
  readme_has_role "$n" || fail readme-role "$n"
done

if [ "$COUNT" -eq 0 ]; then
  echo "LINT OK"
  exit 0
fi
echo "LINT FAIL: $COUNT problems"
exit 1
