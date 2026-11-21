#!/usr/bin/env bash
# Tests for bin/greenfield-tiers. Usage: scripts/test-tiers.sh [label-prefix]
set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1
TOOL="$ROOT/bin/greenfield-tiers"
PREFIX=${1:-}
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

PASS=0
FAIL=0
OUT=""
RC=0

# Print the path of a new workspace named "ws with space", after init.
mkws() {
  local d
  d=$(mktemp -d "$TMPROOT/w.XXXXXX")/"ws with space"
  mkdir -p "$d"
  "$TOOL" init "$d" >/dev/null 2>&1
  echo "$d"
}

# put <ws> <fixture> <name>
put() {
  mkdir -p "$1/provenance/dispatch"
  cp "$ROOT/tests/fixtures/records/$2" "$1/provenance/dispatch/$3"
}

run() {
  OUT=$("$TOOL" "$@" 2>&1)
  RC=$?
}

ok() {
  local label=$1
  shift
  case "$label" in "$PREFIX"*) ;; *) return 0 ;; esac
  if "$@"; then
    PASS=$((PASS + 1))
    return 0
  fi
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n%s\n' "$label" "$OUT"
  return 1
}

has() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
hasnt() { case "$OUT" in *"$1"*) return 1 ;; *) return 0 ;; esac; }

ws=$(mkws)
ok "init copies"            [ -f "$ws/provenance/model-tiers.tsv" ]
echo "# edited" >> "$ws/provenance/model-tiers.tsv"
run init "$ws";             ok "init keeps"           [ "$RC" = 0 -a "$OUT" = "INIT kept" ]
ok "init keeps content"     grep -q "# edited" "$ws/provenance/model-tiers.tsv"
run init "/no/such/dir";    ok "init missing ws"      [ "$RC" = 2 ]

run lookup "$ws" function-analyzer;      ok "lookup light 0"    [ "$RC" = 0 -a "$OUT" = "sonnet medium" ]
run lookup "$ws" function-analyzer 1;    ok "lookup light 1"    [ "$OUT" = "opus high" ]
run lookup "$ws" function-analyzer 2;    ok "lookup light 2"    [ "$OUT" = "fable high" ]
run lookup "$ws" function-analyzer 5;    ok "lookup light 5"    [ "$OUT" = "fable xhigh" ]
run lookup "$ws" chunk-analyzer;         ok "lookup standard 0" [ "$OUT" = "opus high" ]
run lookup "$ws" chunk-analyzer 1;       ok "lookup standard 1" [ "$OUT" = "fable high" ]
run lookup "$ws" chunk-analyzer 2;       ok "lookup standard 2" [ "$OUT" = "fable xhigh" ]
run lookup "$ws" chunk-analyzer 5;       ok "lookup standard 5" [ "$OUT" = "fable xhigh" ]
run lookup "$ws" deep-dive-analyzer;     ok "lookup deep 0"     [ "$OUT" = "fable high" ]
run lookup "$ws" deep-dive-analyzer 1;   ok "lookup deep 1"     [ "$OUT" = "fable xhigh" ]
run lookup "$ws" deep-dive-analyzer 5;   ok "lookup deep 5"     [ "$OUT" = "fable xhigh" ]
run lookup "$ws" no-such-role;           ok "lookup unknown"    [ "$RC" = 1 ]
run lookup "$ws" chunk-analyzer -1;      ok "lookup bad steps"  [ "$RC" = 2 ]
run lookup "$ws" chunk-analyzer x;       ok "lookup text steps" [ "$RC" = 2 ]

bare=$(mktemp -d "$TMPROOT/b.XXXXXX")
run lookup "$bare" chunk-analyzer
ok "lookup before init"     [ "$RC" = 2 ] && ok "lookup init hint" has "run greenfield-tiers init"

# Review Focus 1: spaces between fields and CRLF line ends
awk '{gsub(/\t/,"    "); printf "%s\r\n", $0}' "$ws/provenance/model-tiers.tsv" > "$ws/t" && mv "$ws/t" "$ws/provenance/model-tiers.tsv"
run lookup "$ws" chunk-analyzer;         ok "lookup spaces crlf" [ "$RC" = 0 -a "$OUT" = "opus high" ]

ws=$(mkws)
printf 'role\tghost-role\tno-such-tier\n' >> "$ws/provenance/model-tiers.tsv"
run lookup "$ws" chunk-analyzer;         ok "lookup invalid file" [ "$RC" = 2 ] && ok "invalid text" has "invalid tier file"

# Earlier workspace: records without model lines go to the baseline file
old=$(mktemp -d "$TMPROOT/o.XXXXXX")/"old ws"; mkdir -p "$old/provenance/dispatch"
printf '**Dispatched:** 2026-01-01T12:00:00Z\n**Scope:** full\n' > "$old/provenance/dispatch/L1-doc-researcher.md"
run init "$old"
ok "init baseline"          grep -qx "L1-doc-researcher.md" "$old/provenance/model-tiers-baseline.txt"

echo "test-tiers: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
