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

floor_one() {  # floor_one <fixture>: a workspace with one Layer 1 record
  ws=$(mkws); put "$ws" "$1" L1-chunk-analyzer.md; run floor "$ws" 1
}

floor_one at-floor.md
ok "floor at floor"         [ "$RC" = 0 ] && ok "floor pass line" has "PASS L1-chunk-analyzer.md chunk-analyzer opus/high"
ok "floor summary pass"     has "FLOOR L1: PASS"
floor_one below-model.md
ok "floor below model"      [ "$RC" = 1 ] && ok "below model text" has "FAIL L1-chunk-analyzer.md: model sonnet is below the floor opus for chunk-analyzer"
ok "floor summary fail"     has "FLOOR L1: FAIL"
floor_one below-effort.md
ok "floor below effort"     [ "$RC" = 1 ] && ok "below effort text" has "effort medium is below the floor high for chunk-analyzer"
floor_one no-model-line.md
ok "floor missing line"     [ "$RC" = 1 ] && ok "missing text" has "missing **Model:** line"
floor_one above-raised-no.md
ok "floor raised no"        [ "$RC" = 1 ] && ok "raised no text" has "above the floor but **Raised:** is no"
floor_one above-raised-yes.md
ok "floor raised yes"       [ "$RC" = 0 ]
floor_one unknown-model.md
ok "floor unknown model"    [ "$RC" = 1 ] && ok "unknown model text" has "unknown model 'claude-opus-5-5'"
floor_one prompt-quotes-model.md      # Review Focus 3
ok "floor prompt quote"     [ "$RC" = 0 ] && ok "prompt quote line" has "PASS L1-chunk-analyzer.md chunk-analyzer opus/high"

ws=$(mkws); run floor "$ws" 1
ok "floor no records"       [ "$RC" = 1 ] && ok "no records text" has "FAIL L1: no dispatch records"

ws=$(mkws); put "$ws" at-floor.md L2-chunk-analyzer.md; put "$ws" below-model.md L1-chunk-analyzer.md
run floor "$ws" 2;          ok "floor reads own layer" [ "$RC" = 0 ]

ws=$(mkws); put "$ws" below-model.md L1-chunk-analyzer.md; put "$ws" supersedes-below.md L1-chunk-analyzer-2.md
run floor "$ws" 1
ok "floor superseded"       [ "$RC" = 0 ] && ok "superseded text" has "SKIP L1-chunk-analyzer.md: superseded by L1-chunk-analyzer-2.md"

ws=$(mkws); put "$ws" no-model-line.md L1-doc-researcher.md; put "$ws" at-floor.md L1-chunk-analyzer.md
echo "L1-doc-researcher.md" > "$ws/provenance/model-tiers-baseline.txt"
run floor "$ws" 1
ok "floor baseline"         [ "$RC" = 0 ] && ok "baseline text" has "SKIP L1-doc-researcher.md: predates model tiers"

run floor "$ws" 8;          ok "floor bad layer"       [ "$RC" = 2 ]

floor_log() {  # floor_log <log fixture or "null">: one at-floor record plus one agent_runs entry
  ws=$(mkws); put "$ws" at-floor.md L1-chunk-analyzer.md; mkdir -p "$ws/provenance/sessions"
  if [ "$1" = null ]; then log=null; else
    cp "tests/fixtures/logs/$1" "$ws/provenance/sessions/$1"; log="\"provenance/sessions/$1\""; fi
  printf '{"agent_runs":[{"role":"chunk-analyzer","dispatch_record":"provenance/dispatch/L1-chunk-analyzer.md","session_log":%s}]}\n' "$log" > "$ws/workspace.json"
  run floor "$ws" 1
}

if command -v jq >/dev/null; then
  floor_log opus.jsonl
  ok "log at floor"         [ "$RC" = 0 ] && ok "log no warn" hasnt "WARN"
  floor_log sonnet.jsonl
  ok "log below floor"      [ "$RC" = 1 ] && ok "log below text" has "FAIL sonnet.jsonl: ran on claude-sonnet-5-5, below the floor opus for chunk-analyzer"
  floor_log synthetic.jsonl             # Review Focus 4
  ok "log synthetic"        [ "$RC" = 0 ] && ok "synthetic text" has "WARN synthetic.jsonl: model ID '<synthetic>' names no known alias"
  floor_log null
  ok "log null"             [ "$RC" = 0 ] && ok "log null text" has "WARN L1-chunk-analyzer.md: no session log"
  ws=$(mkws); put "$ws" at-floor.md L1-chunk-analyzer.md; mkdir -p "$ws/provenance/sessions"
  cp tests/fixtures/logs/opus.jsonl "$ws/provenance/sessions/opus.jsonl"
  printf '{"agent_runs":[{"role":"ghost-role","dispatch_record":"provenance/dispatch/L1-chunk-analyzer.md","session_log":"provenance/sessions/opus.jsonl"}]}\n' > "$ws/workspace.json"
  run floor "$ws" 1
  ok "log unknown role"     [ "$RC" = 0 ] && ok "unknown role text" has "WARN L1-chunk-analyzer.md: agent_runs role 'ghost-role' is not in the tier file"
  ws=$(mkws); put "$ws" at-floor.md L1-chunk-analyzer.md; run floor "$ws" 1
  ok "log no entry"        [ "$RC" = 0 ] && ok "no entry text" has "WARN L1-chunk-analyzer.md: no agent_runs entry"
  ws=$(mkws); put "$ws" below-model.md L1-chunk-analyzer.md; put "$ws" supersedes-below.md L1-chunk-analyzer-2.md
  mkdir -p "$ws/provenance/sessions"; cp tests/fixtures/logs/sonnet.jsonl "$ws/provenance/sessions/"
  printf '{"agent_runs":[{"role":"chunk-analyzer","dispatch_record":"provenance/dispatch/L1-chunk-analyzer.md","session_log":"provenance/sessions/sonnet.jsonl"}]}\n' > "$ws/workspace.json"
  run floor "$ws" 1;        ok "log superseded entry" [ "$RC" = 0 ]
else
  echo "SKIP: jq is not installed, session log tests not run"
fi
floor_log sonnet.jsonl; GREENFIELD_NO_JQ=1 run floor "$ws" 1
ok "log without jq"         [ "$RC" = 0 ] && ok "without jq text" has "WARN L1: jq is not installed, session logs not compared"

pf() { env -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE -u CLAUDE_CODE_EFFORT_LEVEL "$@" bin/greenfield-tiers preflight; }
runpf() { OUT=$(pf "$@" 2>&1); RC=$?; }

runpf GREENFIELD_CLAUDE_VERSION="2.1.330 (Claude Code)"
ok "preflight ok"           [ "$RC" = 0 -a "$OUT" = "PREFLIGHT OK" ]
runpf GREENFIELD_CLAUDE_VERSION=2.1.292;   ok "preflight min version"  [ "$RC" = 0 ]
runpf GREENFIELD_CLAUDE_VERSION=2.1.291
ok "preflight old version"  [ "$RC" = 3 ] && ok "old version text" has "OVERRIDE Claude Code 2.1.291 is older than 2.1.292"
runpf GREENFIELD_CLAUDE_VERSION=2.10.0;    ok "preflight numeric"      [ "$RC" = 0 ]    # Review Focus 5
runpf GREENFIELD_CLAUDE_VERSION=3.0.0;     ok "preflight major"        [ "$RC" = 0 ]
runpf GREENFIELD_CLAUDE_VERSION=unknown
ok "preflight no version"   [ "$RC" = 3 ] && ok "no version text" has "OVERRIDE Claude Code version is unknown"
runpf GREENFIELD_CLAUDE_VERSION=2.1.330 CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1
ok "preflight model force"  [ "$RC" = 3 ] && ok "model force text" has "OVERRIDE CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set"
runpf GREENFIELD_CLAUDE_VERSION=2.1.330 CLAUDE_CODE_EFFORT_LEVEL=low
ok "preflight effort level" [ "$RC" = 3 ] && ok "effort level text" has "OVERRIDE CLAUDE_CODE_EFFORT_LEVEL is set"
runpf GREENFIELD_CLAUDE_VERSION=2.01.292;  ok "preflight leading zero" [ "$RC" = 0 ]

ws=$(mkws)
run substitute "$ws" deep opus xhigh "no Fable access"
ok "substitute ok"          [ "$RC" = 0 -a "$OUT" = "SUBSTITUTED deep: fable/high -> opus/xhigh" ]
ok "substitute comment"     grep -q "^# substituted deep: fable/high -> opus/xhigh at .*: no Fable access$" "$ws/provenance/model-tiers.tsv"
run lookup "$ws" deep-dive-analyzer;     ok "substitute lookup"   [ "$OUT" = "opus xhigh" ]
run lookup "$ws" deep-dive-analyzer 1;   ok "substitute ceiling"  [ "$OUT" = "opus xhigh" ]
run lookup "$ws" chunk-analyzer 1;       ok "substitute raise"    [ "$OUT" = "opus xhigh" ]
put "$ws" at-floor.md L3-deep-dive-x.md
sed -i.bak -e 's/chunk-analyzer$/deep-dive-analyzer/' -e 's/^\*\*Effort:\*\* high/**Effort:** xhigh/' "$ws/provenance/dispatch/L3-deep-dive-x.md"
rm "$ws/provenance/dispatch/L3-deep-dive-x.md.bak"
run floor "$ws" 3;          ok "substitute floor"    [ "$RC" = 0 ]
run substitute "$ws" deep gpt high "x";      ok "substitute bad model"  [ "$RC" = 2 ]
run substitute "$ws" huge opus high "x";     ok "substitute bad tier"   [ "$RC" = 2 ]
run substitute "$ws" deep opus high "";      ok "substitute no reason"  [ "$RC" = 2 ]

# substitute on a hand-edited copy (spaces, CRLF) keeps other lines
ws=$(mkws)
awk '{gsub(/\t/,"    "); printf "%s\r\n", $0}' "$ws/provenance/model-tiers.tsv" > "$ws/t" && mv "$ws/t" "$ws/provenance/model-tiers.tsv"
run substitute "$ws" light haiku low "multi
line"
ok "substitute crlf"        [ "$RC" = 0 -a "$OUT" = "SUBSTITUTED light: sonnet/medium -> haiku/low" ]
run lookup "$ws" function-analyzer;      ok "substitute crlf lookup" [ "$OUT" = "haiku low" ]
ok "substitute keeps rows"  grep -q "^role  *chunk-analyzer" "$ws/provenance/model-tiers.tsv"
ok "substitute one reason line" grep -q "^# substituted light: .*: multi line$" "$ws/provenance/model-tiers.tsv"

echo "test-tiers: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
