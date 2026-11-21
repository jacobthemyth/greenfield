# Subagent Model Tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each Greenfield subagent role a fixed model and effort floor, enforced at every gate.

**Architecture:** One tier file, `model-tiers.tsv`, holds the tiers and the role assignments. One bash tool, `bin/greenfield-tiers`, copies the file into a workspace and prints the values for a dispatch. The tool also applies the floor rule to dispatch records and session logs. The two commands call the tool, and the two agent definitions default to the top tier.

**Tech Stack:** bash 3.2 (the macOS system bash), awk, `jq` (optional at run time), Markdown command files for Claude Code.

**Spec:** `docs/superpowers/specs/2026-11-21-subagent-model-tiers-design.md`

## Global Constraints

- Tiers: deep is `fable` / `high`, standard is `opus` / `high`, light is `sonnet` / `medium`.
- Model order, weakest first: `haiku`, `sonnet`, `opus`, `fable`.
- Effort order, lowest first: `low`, `medium`, `high`, `xhigh`, `max`.
- The raise ceiling is the deep model at `xhigh`. No dispatch uses `max`.
- The minimum Claude Code version is 2.1.292.
- Scripts run on bash 3.2. Do not use associative arrays, `mapfile`, or `${var,,}`.
- `jq` is optional at run time. Without `jq`, the tool prints a WARN line and continues.
- Every `git add` names explicit paths. Never run `git add -A` or `git add .` in this repository. The root holds an untracked 25 GB file, `greenfield-tahoe-base.tvm`.
- Find each edit location in `commands/analyze.md` by its heading. Line numbers move as tasks land.
- Change only the sections that a task names.
- New prose in Markdown files follows the simple-english hook rules: short sentences, condition first, no contractions, no em-dashes.
- The hook also reports earlier violations in `commands/*.md` and `README.md`. Leave the earlier text as it is.
- End each commit message with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.

## Review Focus

These five conditions are likely in real use. Each one has a test in the task that owns the code.

1. A user edits the `tier deep` row, and the editor writes spaces or CRLF line ends. `lookup` must print the same values. Test in Task 1.
2. A workspace path holds a space, as many macOS paths do. Every subcommand must work. Every test workspace in Task 1 has a space in its path.
3. A dispatch prompt quotes a `**Model:**` line inside its fence. Only the header lines decide the result. Test in Task 2.
4. A session log holds a model ID that names no alias, such as `<synthetic>`. The result is WARN, not FAIL. Test in Task 3.
5. The Claude Code version is `2.10.0`. A string comparison ranks it below `2.1.292`. The comparison must be numeric. Test in Task 4.

## File Structure

| File | Responsibility |
|------|----------------|
| `model-tiers.tsv` | The only copy of the tiers and the role assignments. |
| `bin/greenfield-tiers` | Subcommands `init`, `lookup`, `floor`, `preflight`, `substitute`. |
| `scripts/test-tiers.sh` | Runs `bin/greenfield-tiers` against fixtures. Calls no model. |
| `scripts/lint-tiers.sh` | Fails on drift between commands, agents, README, and the tier file. |
| `tests/fixtures/records/` | Dispatch record fixtures. |
| `tests/fixtures/logs/` | Session log fixtures. |
| `agents/analyzer.md`, `agents/sanitizer.md` | Default to the deep tier. |
| `commands/analyze.md` | Calls the tool at preflight, at each dispatch, and at each gate. |
| `commands/sanitize.md` | The same protocol for the standalone command. |
| `README.md` | "Model tiers" section. |

---

### Task 1: Tier file, `init`, and `lookup`

**Files:**
- Create: `model-tiers.tsv`
- Create: `bin/greenfield-tiers` (mode 755)
- Create: `scripts/test-tiers.sh` (mode 755)

**Interfaces:**
- Produces, command line:
  - `greenfield-tiers init <workspace>` prints `INIT copied` or `INIT kept`. Exit 0, or 2 for a missing workspace directory.
  - `greenfield-tiers lookup <workspace> <role> [steps]` prints `<model> <effort>`. Exit 0, 1 for an unknown role, 2 for a usage error or an invalid tier file.
  - Environment variable `GREENFIELD_TIERS_FILE` replaces the plugin tier file path. The default is `<directory of the script>/../model-tiers.tsv`.
- Produces, shell functions inside `bin/greenfield-tiers` that later tasks call:
  - `die <code> <message>` writes `greenfield-tiers: <message>` to stderr and exits.
  - `ws_tiers <workspace>` prints `<workspace>/provenance/model-tiers.tsv`, or dies with code 2 and the text `run greenfield-tiers init`.
  - `load_tiers <file>` prints normalized rows, `tier <name> <model> <effort>` and `role <name> <tier>`, or dies with code 2 and the text `invalid tier file`.
  - `model_rank <alias>` prints 0 to 3 and returns 1 for an unknown alias.
  - `effort_rank <level>` prints 0 to 4 and returns 1 for an unknown level.
  - `role_floor <file> <role>` prints `<model> <effort>` and returns 1 for an unknown role.
- Produces, helpers inside `scripts/test-tiers.sh` that later tasks call:
  - `mkws` prints the path of a new temporary workspace named `ws with space`, after it runs `init`.
  - `put <ws> <fixture> <name>` copies `tests/fixtures/records/<fixture>` to `<ws>/provenance/dispatch/<name>`.
  - `run <args...>` runs `bin/greenfield-tiers`, then sets `OUT` (stdout and stderr) and `RC`.
  - `ok <label> <command...>` runs the command. It records a pass, or prints `FAIL: <label>` with `OUT`.
  - `has <text>` succeeds for an `OUT` that holds the text. `hasnt <text>` succeeds for an `OUT` that does not.
  - The script changes to the repository root before it runs a test.
  - The script takes an optional label prefix as its first argument and runs only the matching tests.
  - The last line is `test-tiers: <n> passed, <m> failed`. If `m` is above 0, the exit status is 1.

- [ ] **Step 1: Write `model-tiers.tsv`**

This is the whole file: 3 `tier` rows and 46 `role` rows. Use one tab character between fields.

```text
tier	deep	fable	high
tier	standard	opus	high
tier	light	sonnet	medium
role	feature-discoverer	deep
role	architecture-analyst	deep
role	api-extractor	deep
role	analysis-synthesizer	deep
role	module-mapper	deep
role	deep-dive-analyzer	deep
role	behavior-documenter	deep
role	user-journey-analyzer	deep
role	contract-extractor	deep
role	spec-verifier	deep
role	source-completeness-checker	deep
role	spec-reviewer	deep
role	spec-remediator	deep
role	sanitizer	deep
role	contamination-judge	deep
role	structural-leakage-reviewer	deep
role	content-contamination-reviewer	deep
role	behavioral-completeness-reviewer	deep
role	deep-read-auditor	deep
role	fidelity-validator	deep
role	discovery-agent	standard
role	bundle-splitter	standard
role	chunk-analyzer	standard
role	doc-researcher	standard
role	test-reader	standard
role	binary-deep-analyzer	standard
role	cli-explorer	standard
role	web-ui-explorer	standard
role	behavior-observer	standard
role	ux-documenter	standard
role	visual-explorer	standard
role	bundle-inspector	standard
role	applescript-explorer	standard
role	ui-observer	standard
role	data-inspector	standard
role	test-vector-generator	standard
role	test-generator	standard
role	acceptance-criteria-writer	standard
role	function-analyzer	light
role	contract-parser	light
role	test-runner	light
role	binary-surveyor	light
role	git-archaeologist	light
role	community-analyst	light
role	sdk-analyzer	light
role	integration-test-miner	light
```

- [ ] **Step 2: Write the failing tests in `scripts/test-tiers.sh`**

Write the helpers from the Interfaces block, then these tests.

```bash
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

bare=$(mktemp -d)
run lookup "$bare" chunk-analyzer
ok "lookup before init"     [ "$RC" = 2 ] && ok "lookup init hint" has "run greenfield-tiers init"

# Review Focus 1: spaces between fields and CRLF line ends
awk '{gsub(/\t/,"    "); printf "%s\r\n", $0}' "$ws/provenance/model-tiers.tsv" > "$ws/t" && mv "$ws/t" "$ws/provenance/model-tiers.tsv"
run lookup "$ws" chunk-analyzer;         ok "lookup spaces crlf" [ "$RC" = 0 -a "$OUT" = "opus high" ]

ws=$(mkws)
printf 'role\tghost-role\tno-such-tier\n' >> "$ws/provenance/model-tiers.tsv"
run lookup "$ws" chunk-analyzer;         ok "lookup invalid file" [ "$RC" = 2 ] && ok "invalid text" has "invalid tier file"

# Earlier workspace: records without model lines go to the baseline file
old=$(mktemp -d)/"old ws"; mkdir -p "$old/provenance/dispatch"
printf '**Dispatched:** 2026-01-01T12:00:00Z\n**Scope:** full\n' > "$old/provenance/dispatch/L1-doc-researcher.md"
run init "$old"
ok "init baseline"          grep -qx "L1-doc-researcher.md" "$old/provenance/model-tiers-baseline.txt"
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `scripts/test-tiers.sh`
Expected: every label prints `FAIL:`, because `bin/greenfield-tiers` does not exist.

- [ ] **Step 4: Implement `init` and `lookup` in `bin/greenfield-tiers`**

Start the file with `#!/usr/bin/env bash` and `set -u`. Write the six shared functions from the Interfaces block.

`load_tiers` rules:
- Split fields on any whitespace. Remove `\r`. Skip blank lines and lines that start with `#`.
- Require the three tiers `deep`, `standard`, and `light`, each one time.
- Require a known model alias and a known effort level in each `tier` row.
- Require that each `role` row names one of the three tiers, and that no role appears twice.

`lookup` ladder: position 0 is the light tier, 1 is standard, 2 is deep. Position 3 is the deep model with the higher of the deep effort and `xhigh`. The result is the position of the role tier plus `steps`, with a maximum of 3.

`init` rules:
- If the workspace copy exists, print `INIT kept` and change nothing.
- If no copy exists, run `load_tiers` on the plugin file, then copy the plugin file byte for byte.
- On that first copy, list each `provenance/dispatch/*.md` file that has no `**Model:**` header line. Write the base names to `provenance/model-tiers-baseline.txt`, one per line. Do not create the file for an empty list.

- [ ] **Step 5: Run the tests and see them pass**

Run: `scripts/test-tiers.sh`
Expected: `test-tiers: 24 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add model-tiers.tsv bin/greenfield-tiers scripts/test-tiers.sh
git commit -m "feat(tiers): add tier file with init and lookup"
```

---

### Task 2: `floor`, first pass over dispatch records

**Files:**
- Modify: `bin/greenfield-tiers`
- Modify: `scripts/test-tiers.sh`
- Create: `tests/fixtures/records/*.md` (9 files)

**Interfaces:**
- Consumes: `ws_tiers`, `load_tiers`, `model_rank`, `effort_rank`, `role_floor`, `die`, and the test helpers, all from Task 1.
- Produces: `greenfield-tiers floor <workspace> <layer>`, with `<layer>` from 1 to 7.
  - One line per record: `PASS <file> <role> <model>/<effort>`, `FAIL <file>: <reason>`, or `SKIP <file>: <reason>`.
  - Last line: `FLOOR L<layer>: PASS` or `FLOOR L<layer>: FAIL`.
  - Exit 0 with no FAIL line, 1 with a FAIL line, 2 for a usage error.
  - `<file>` is the base name of the record.
- Produces: shell function `header_value <record> <key>`. It prints the value of the first `**<key>:**` line above the first line that starts with three backticks.

- [ ] **Step 1: Write the fixture records**

Every fixture uses this template. The table gives the lines that differ.

~~~markdown
**Dispatched:** 2026-01-01T12:00:00Z
**Subagent:** greenfield:analyzer
**Round:** 1
**Scope:** full
**Role:** chunk-analyzer
**Model:** opus
**Effort:** high
**Raised:** no

```text
Role: chunk-analyzer. Fixture prompt.
```
~~~

| Fixture file | Difference from the template |
|--------------|------------------------------|
| `at-floor.md` | None. |
| `below-model.md` | `**Model:** sonnet` |
| `below-effort.md` | `**Effort:** medium` |
| `no-model-line.md` | The `**Model:**` line is absent. |
| `above-raised-no.md` | `**Model:** fable` |
| `above-raised-yes.md` | `**Model:** fable` and `**Raised:** yes: Layer 1 gate failed, round 2` |
| `unknown-model.md` | `**Model:** claude-opus-5-5` |
| `prompt-quotes-model.md` | The fenced prompt gains the line `**Model:** haiku`. |
| `supersedes-below.md` | The template plus the header line `**Supersedes:** L1-chunk-analyzer.md` |

- [ ] **Step 2: Write the failing tests**

```bash
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
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `scripts/test-tiers.sh floor`
Expected: each `floor` label prints `FAIL:`.

- [ ] **Step 4: Implement `floor`, first pass**

Read `<workspace>/provenance/dispatch/L<layer>-*.md`. For each record, apply the first matching rule.

| Order | Condition | Line |
|-------|-----------|------|
| 1 | The baseline file lists the base name. | `SKIP <file>: predates model tiers` |
| 2 | Another record in the directory names it in `**Supersedes:**`. | `SKIP <file>: superseded by <other file>` |
| 3 | A `**Role:**`, `**Model:**`, `**Effort:**`, or `**Raised:**` header line is absent. | `FAIL <file>: missing **<Key>:** line` |
| 4 | The tier file does not list the role. | `FAIL <file>: unknown role '<role>'` |
| 5 | The model or effort is not in the orders above. | `FAIL <file>: unknown model '<x>'` or `unknown effort '<x>'` |
| 6 | The model rank is below the floor model rank. | `FAIL <file>: model <m> is below the floor <fm> for <role>` |
| 7 | The effort rank is below the floor effort rank. | `FAIL <file>: effort <e> is below the floor <fe> for <role>` |
| 8 | `**Raised:**` is not `no` and does not start with `yes: ` plus a reason. | `FAIL <file>: **Raised:** must be 'no' or 'yes: <reason>'` |
| 9 | The model or effort rank is above the floor, and `**Raised:**` is `no`. | `FAIL <file>: above the floor but **Raised:** is no` |
| 10 | No rule above matched. | `PASS <file> <role> <model>/<effort>` |

If the layer has no record file, print `FAIL L<layer>: no dispatch records`.

- [ ] **Step 5: Run the tests and see them pass**

Run: `scripts/test-tiers.sh`
Expected: `test-tiers: 49 passed, 0 failed`

- [ ] **Step 6: Commit**

```bash
git add bin/greenfield-tiers scripts/test-tiers.sh tests/fixtures/records
git commit -m "feat(tiers): apply the floor rule to dispatch records"
```

---

### Task 3: `floor`, second pass over session logs

**Files:**
- Modify: `bin/greenfield-tiers`
- Modify: `scripts/test-tiers.sh`
- Create: `tests/fixtures/logs/opus.jsonl`, `tests/fixtures/logs/sonnet.jsonl`, `tests/fixtures/logs/synthetic.jsonl`

**Interfaces:**
- Consumes: `floor` and `header_value` from Task 2, and the shared functions from Task 1.
- Consumes: `workspace.json` in the workspace root. Each `agent_runs` entry holds `role`, `dispatch_record`, and `session_log`. Both paths are relative to the workspace root. `session_log` can be `null`.
- Produces: extra `floor` lines.
  - `FAIL <log>: ran on <model id>, below the floor <fm> for <role>`
  - `WARN <record>: no session log`
  - `WARN <record>: no agent_runs entry`
  - `WARN <log>: model ID '<id>' names no known alias`
  - `WARN <record>: agent_runs role '<r>' is not in the tier file`
  - `WARN L<layer>: jq is not installed, session logs not compared`
- Produces: with `GREENFIELD_NO_JQ=1` in the environment, the tool acts as it does without `jq`.

- [ ] **Step 1: Write the log fixtures**

Each file holds three JSON lines. The `user` line proves that the tool reads only assistant entries.

```json
{"type":"user","message":{"role":"user","content":"\"model\":\"claude-haiku-5-5\""}}
{"type":"assistant","message":{"model":"claude-opus-5-5","role":"assistant"}}
{"type":"assistant","message":{"model":"claude-opus-5-5","role":"assistant"}}
```

`sonnet.jsonl` uses `claude-sonnet-5-5` in both assistant lines. `synthetic.jsonl` uses `claude-opus-5-5` in one assistant line and `<synthetic>` in the other.

- [ ] **Step 2: Write the failing tests**

```bash
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
  ws=$(mkws); put "$ws" at-floor.md L1-chunk-analyzer.md; run floor "$ws" 1
  ok "log no entry"         [ "$RC" = 0 ] && ok "no entry text" has "WARN L1-chunk-analyzer.md: no agent_runs entry"
  ws=$(mkws); put "$ws" below-model.md L1-chunk-analyzer.md; put "$ws" supersedes-below.md L1-chunk-analyzer-2.md
  mkdir -p "$ws/provenance/sessions"; cp tests/fixtures/logs/sonnet.jsonl "$ws/provenance/sessions/"
  printf '{"agent_runs":[{"role":"chunk-analyzer","dispatch_record":"provenance/dispatch/L1-chunk-analyzer.md","session_log":"provenance/sessions/sonnet.jsonl"}]}\n' > "$ws/workspace.json"
  run floor "$ws" 1;        ok "log superseded entry" [ "$RC" = 0 ]
else
  echo "SKIP: jq is not installed, session log tests not run"
fi
floor_log sonnet.jsonl; GREENFIELD_NO_JQ=1 run floor "$ws" 1
ok "log without jq"         [ "$RC" = 0 ] && ok "without jq text" has "WARN L1: jq is not installed, session logs not compared"
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `scripts/test-tiers.sh log`
Expected: each `log` label prints `FAIL:`.

- [ ] **Step 4: Implement the second pass**

Run the second pass after the first pass, for each record that the first pass did not skip.

- Find the `agent_runs` entries whose `dispatch_record` base name equals the record base name.
- Read the model IDs with `jq -r 'select(.type=="assistant") | .message.model // empty'`, then remove duplicates.
- Map an ID to an alias by the alias name inside the ID: `fable`, `opus`, `sonnet`, `haiku`.
- Compare the alias rank with the floor model rank of the `role` field of the entry.
- A `session_log` that is `null`, absent, or names a missing file gives the `no session log` line.
- A missing `workspace.json` gives the `no agent_runs entry` line for each record.

- [ ] **Step 5: Run the tests and see them pass**

Run: `scripts/test-tiers.sh`
Expected: `test-tiers: 64 passed, 0 failed` on a machine with `jq`.

- [ ] **Step 6: Commit**

```bash
git add bin/greenfield-tiers scripts/test-tiers.sh tests/fixtures/logs
git commit -m "feat(tiers): compare session log models with the floor"
```

---

### Task 4: `preflight` and `substitute`

**Files:**
- Modify: `bin/greenfield-tiers`
- Modify: `scripts/test-tiers.sh`

**Interfaces:**
- Consumes: the shared functions from Task 1 and `floor` from Task 2.
- Produces: `greenfield-tiers preflight`.
  - With no condition: prints `PREFLIGHT OK`, exit 0.
  - With a condition: one `OVERRIDE <text>` line per condition, exit 3.
  - Environment variable `GREENFIELD_CLAUDE_VERSION` replaces the output of `claude --version`.
- Produces: `greenfield-tiers substitute <workspace> <tier> <model> <effort> <reason>`.
  - Prints `SUBSTITUTED <tier>: <old model>/<old effort> -> <model>/<effort>`, exit 0.
  - Exit 2 for an unknown tier, model, or effort, or for an empty reason.

- [ ] **Step 1: Write the failing tests**

```bash
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
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test-tiers.sh preflight` and `scripts/test-tiers.sh substitute`
Expected: each label prints `FAIL:`.

- [ ] **Step 3: Implement `preflight` and `substitute`**

`preflight` conditions and their lines:
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is not empty: `OVERRIDE CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set: Claude Code ignores the model of every dispatch`.
- `CLAUDE_CODE_EFFORT_LEVEL` is not empty: `OVERRIDE CLAUDE_CODE_EFFORT_LEVEL is set: Claude Code ignores the effort of every dispatch`.
- The version is below 2.1.292: `OVERRIDE Claude Code <version> is older than 2.1.292: the per-call effort parameter is not available`.
- No `major.minor.patch` number is in the version text: `OVERRIDE Claude Code version is unknown`.

Take the first `major.minor.patch` number from the version text. Compare the three parts as integers.

`substitute` rewrites the one `tier` row in the workspace copy with tab characters. It then appends the line below. The time is UTC in ISO 8601 form. Remove line ends from the reason.

```text
# substituted <tier>: <old model>/<old effort> -> <model>/<effort> at <time>: <reason>
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test-tiers.sh`
Expected: `test-tiers: 85 passed, 0 failed` on a machine with `jq`.

- [ ] **Step 5: Commit**

```bash
git add bin/greenfield-tiers scripts/test-tiers.sh
git commit -m "feat(tiers): add preflight and substitute"
```

---

### Task 5: Drift lint and agent defaults

**Files:**
- Create: `scripts/lint-tiers.sh` (mode 755)
- Modify: `agents/analyzer.md` (frontmatter)
- Modify: `agents/sanitizer.md` (frontmatter)

**Interfaces:**
- Consumes: `model-tiers.tsv` from Task 1.
- Produces: `scripts/lint-tiers.sh`, run from the repository root with no arguments.
  - One `LINT FAIL <code>: <subject>` line per problem.
  - Last line `LINT OK` with exit 0, or `LINT FAIL: <n> problems` with exit 1.
  - Tasks 6, 8, and 10 use the codes below to prove their edits.

| Code | Rule |
|------|------|
| `role-without-row` | A name that matches `Role: [a-z][a-z0-9-]*` in `commands/analyze.md` or `commands/sanitize.md` has no `role` row. |
| `row-without-prompt` | A `role` row has no such `Role:` name in the two commands. |
| `duplicate-row` | A role has two `role` rows. |
| `unknown-tier` | A `role` row names a tier that has no `tier` row. |
| `agent-default` | An agent file frontmatter lacks `model:` or `effort:` equal to the `deep` row. |
| `readme-tier` | `README.md` has no line that starts `\| <tier> \| <model> \| <effort> \|` for a `tier` row. |
| `readme-role` | `README.md` has no line that starts `\| <tier> \|` and holds the role as a whole word. |

- [ ] **Step 1: Write `scripts/lint-tiers.sh`**

Implement the seven rules. Treat a role name as a whole word: the characters next to it are not in `[a-z0-9-]`.

- [ ] **Step 2: Run the lint and see the expected failures**

Run: `scripts/lint-tiers.sh`
Expected: exit 1, with these lines among the output.

```text
LINT FAIL role-without-row: deep-read
LINT FAIL row-without-prompt: deep-read-auditor
LINT FAIL row-without-prompt: sanitizer
LINT FAIL row-without-prompt: spec-remediator
LINT FAIL agent-default: agents/analyzer.md
LINT FAIL agent-default: agents/sanitizer.md
```

The output also holds 3 `readme-tier` lines and 46 `readme-role` lines. It holds no `duplicate-row` and no `unknown-tier` line.

- [ ] **Step 3: Add the default tier to both agent files**

Add these two lines to the frontmatter of `agents/analyzer.md` and `agents/sanitizer.md`, after the `tools:` line.

```yaml
model: fable
effort: high
```

- [ ] **Step 4: Run the lint again**

Run: `scripts/lint-tiers.sh | grep -c agent-default`
Expected: `0`

- [ ] **Step 5: Commit**

```bash
git add scripts/lint-tiers.sh agents/analyzer.md agents/sanitizer.md
git commit -m "feat(tiers): default both agents to the deep tier and add drift lint"
```

---

### Task 6: `/analyze` dispatch protocol

**Files:**
- Modify: `commands/analyze.md`, sections "THE PIPELINE", "Step 0: Argument Validation", "Step 1: Workspace Initialization", "2c: Pre-flight Dispatch Count", "Agent Dispatch Protocol", "Layer 1" (Step 3), "Layer 5: Sanitization", "Layer 6" (Phase 2), "Failure Handling"

**Interfaces:**
- Consumes: `greenfield-tiers preflight`, `init`, `lookup`, and `substitute` from Tasks 1 and 4.
- Produces: the dispatch record header that Task 7 and Task 9 rely on. The eight lines, in order: `**Dispatched:**`, `**Subagent:**`, `**Round:**`, `**Scope:**`, `**Role:**`, `**Model:**`, `**Effort:**`, `**Raised:**`. An optional ninth line is `**Supersedes:**`.
- Produces: the section names "Model and effort", "Raise rule", and "Model not available" under "Agent Dispatch Protocol". Tasks 7 and 8 refer to them.

- [ ] **Step 1: Add the preflight to "Step 0: Argument Validation"**

Add this text at the end of the section.

~~~markdown
### Model override preflight

```bash
greenfield-tiers preflight
```

If the command exits with status 3, stop and show its output to the user. Ask whether to end the run or to continue. If the user continues, append the output and the answer to `provenance/audit-log.md` after Step 1 creates the workspace.

If the shell cannot find `greenfield-tiers`, stop with exit code 1. The plugin `bin/` directory is not on the PATH.
~~~

- [ ] **Step 2: Add `init` to "Step 1: Workspace Initialization"**

In the incremental branch, add the `init` command after the comment lines that read `workspace.json`. In the fresh branch, add it before the initial commit. Add one comment line above each: `# Copy the model tier file (a workspace copy that exists is kept)`.

The command is `greenfield-tiers init "$WORKSPACE"`. If the block already runs inside the workspace directory, use `greenfield-tiers init .` in that block.

- [ ] **Step 3: Rewrite the "Dispatch pattern" list**

In item 1, replace the `model` bullet with this bullet.

```markdown
   - `model` and `effort`: the two values that `greenfield-tiers lookup` prints for the role (see **Model and effort** below). Pass both on every dispatch.
```

In item 3, replace `hit the Opus rate limit mid-pipeline` with `hit a per-model rate limit mid-pipeline`.

- [ ] **Step 4: Add three subsections after "Dispatch pattern" and before "Dispatch record"**

~~~markdown
### Model and effort

Each role has a floor: the weakest model and effort that the role can run on. The floors are in `workspace/provenance/model-tiers.tsv`. Do not select a model from memory. Do not let a dispatch inherit the session model.

Before every Agent call, run:

```bash
greenfield-tiers lookup workspace <role>
```

The command prints two words, for example `opus high`. Pass the first word as `model` and the second word as `effort`. If the command fails, do not dispatch the role. A role that the tier file does not list has no floor.

### Raise rule

If you dispatch a role again for the same work because its output was deficient, raise the dispatch. Deficient output is a gate failure, missing output, or partial output. Pass the count of earlier deficient rounds as the last argument:

```bash
greenfield-tiers lookup workspace <role> 1    # round 2
greenfield-tiers lookup workspace <role> 2    # round 3
```

The command stops at the ceiling. Never dispatch below the floor.

Do not raise in these two cases. Use the values of the earlier round.

- The cause is the environment: the wallpaper failure (Tier 3.7), a lost VM, or a TCC denial.
- A gate judge runs again after a remediation. Its earlier output was correct. Raise the role that wrote the deficient output.

### Model not available

If an Agent call fails because the account cannot use the model, stop and ask the user for a substitute. Never select a weaker model yourself. If the user approves a substitute, record it, then run `lookup` again:

```bash
greenfield-tiers substitute workspace <tier> <model> <effort> "<reason>"
```

Print each substitute in the final summary.
~~~

- [ ] **Step 5: Extend the "Dispatch record" section**

Change `four header lines` to `eight header lines`. Add these four lines to the format block, after the `**Scope:**` line.

```markdown
**Role:** chunk-analyzer
**Model:** opus
**Effort:** high
**Raised:** no
```

Add these bullets to the list under the format block.

```markdown
- `**Role:**` is the role name as the tier file spells it.
- `**Model:**` and `**Effort:**` are the two values that you pass on the Agent call.
- `**Raised:**` is `no` at the floor, and `yes: <reason>` above the floor.
- `**Supersedes:** <record filename>` is an optional ninth line. Add it only if this dispatch repeats the full work of an earlier dispatch and replaces its output.
- Fixed prefixes: `discovery-agent` uses `L1-`. Gate 1, Gate 1b, and their remediation use `L3-`. Gate 2 and its remediation use `L4-`.
```

- [ ] **Step 6: Correct the dispatch prompts and the remaining Haiku text**

- In Layer 1, Step 3: change ``Dispatch `greenfield:analyzer` with `model: "haiku"`:`` to ``Dispatch `greenfield:analyzer`:``.
- In Layer 6, Phase 2: change `Role: deep-read auditor (Layer 6, Phase 2)` to `Role: deep-read-auditor (Layer 6, Phase 2)`.
- In Layer 5: start the sanitizer prompt with `Role: sanitizer. ` before `Workspace:`. Add this sentence after the prompt bullet: ``Every sanitizer prompt in Layers 5, 6, and 7 starts with `Role: sanitizer.` ``
- In "2c: Pre-flight Dispatch Count": remove `(Haiku)`. Add the tier in brackets at the end of each role line, for example `1 doc-researcher [standard]` and `Layer 2 (Synthesis):       5 agents [deep]`. Take each tier from `model-tiers.tsv`.
- In "THE PIPELINE": add one sentence after the first paragraph: `Each dispatch takes its model and effort from the tier file (see **Model and effort**), never from the session model.`
- In "Failure Handling": add this row after the `Gate fails` row.

```markdown
| Model not available for a dispatch | Stop and ask the user for a substitute. Record it with `greenfield-tiers substitute`. Never select a weaker model without the user. |
```

- [ ] **Step 7: Prove the edits**

Run:

```bash
grep -c 'haiku\|Haiku\|Opus rate limit' commands/analyze.md
grep -c 'greenfield-tiers preflight' commands/analyze.md
grep -c 'greenfield-tiers init' commands/analyze.md
grep -c 'Role: sanitizer\.' commands/analyze.md
scripts/lint-tiers.sh | grep -E 'deep-read|sanitizer'
```

Expected: `0`, `1`, `2`, `2`, and no output from the last command.

- [ ] **Step 8: Commit**

```bash
git add commands/analyze.md
git commit -m "feat(analyze): take each dispatch model and effort from the tier file"
```

---

### Task 7: `/analyze` gates and session capture

**Files:**
- Modify: `commands/analyze.md`, in "Agent Dispatch Protocol" and in every gate from Layer 1 to Layer 7.
- Modify: `commands/analyze.md`, in "Session JSONL Capture Protocol" and in "Print Summary".

**Interfaces:**
- Consumes: `greenfield-tiers floor` from Tasks 2 and 3, and the record header from Task 6.
- Produces: `agent_runs` entries with the fields `role`, `model`, `effort`, `dispatch_record`, and `session_log`. Task 3 reads `role`, `dispatch_record`, and `session_log`.

- [ ] **Step 1: Add the "Floor failures" subsection after "Model not available"**

```markdown
### Floor failures

Every gate runs `greenfield-tiers floor workspace <layer>`. A FAIL line fails the gate. A WARN line does not.

- If a dispatch record fails, dispatch the role again for the same full scope at the `lookup` values. Add `**Supersedes:** <failed record filename>` to the new record. Discard the output of the earlier dispatch.
- If a session log fails, Claude Code ran a weaker model than the dispatch named. Stop and ask the user, as in **Model not available**.
- Never edit or delete a dispatch record to clear a FAIL line.
- Print each WARN line in the final summary.
```

- [ ] **Step 2: Add the floor rule to the gates of Layers 1, 2, 3, and 4**

In each of the four gate scripts, add this block immediately before the line `if [ "$GATE_FAIL" -eq 1 ]; then`. Replace `N` with the layer number in all three places.

```bash
# --- Model floor: every Layer N dispatch ran at or above its floor ---
if ! greenfield-tiers floor workspace N; then
  echo "LAYER N GATE FAILED: model floor (see the FAIL lines above and 'Floor failures' in the Agent Dispatch Protocol)"
  GATE_FAIL=1
fi
```

- [ ] **Step 3: Add the floor rule to the remaining gates**

Add one bash block at each location in the table. The block is one line.

```bash
greenfield-tiers floor workspace N || { echo "BLOCKED: <gate name> model floor failed (see 'Floor failures')"; exit 1; }
```

| Gate name | `N` | Location |
|-----------|-----|----------|
| Gate 1 | 3 | After the "Remediation Loop" block, before `**DO NOT proceed to Gate 1b until Gate 1 passes.**` |
| Gate 1b | 3 | Before the block that holds `git tag -a source-completeness-pass` |
| Gate 2 | 4 | After the "Remediation Loop" block, before `**DO NOT proceed past Gate 2 until it passes.**` |
| Layer 5 | 5 | After the judge verdict block, before `Tag sanitization complete:` |
| Layer 6 | 6 | After the "Remediation Loop" block, before `**DO NOT proceed to Layer 7 until Layer 6 passes.**` |
| Layer 7 | 7 | Under "Fidelity Pass", before the block that holds `git tag -a fidelity-check-complete` |

- [ ] **Step 4: Correct the session log path in both capture sections**

The path `~/.claude/projects/<encoded-cwd>/<agentId>.jsonl` is wrong. The two sections are "Session capture" and "Session JSONL Capture Protocol". In both, replace the bash that builds `ENCODED_CWD` and the log path with this block. Keep the `cp` target and the `agent_runs` comment lines of each section.

```bash
# A subagent log is at <claude-dir>/projects/<project>/<session-id>/subagents/agent-<agentId>.jsonl
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESSION_JSONL=$(find "$CLAUDE_DIR/projects" -path "*/subagents/agent-${AGENT_ID}.jsonl" 2>/dev/null | head -1)

if [ -n "$SESSION_JSONL" ]; then
  cp "$SESSION_JSONL" "workspace/provenance/sessions/<agent-name>-${AGENT_ID:0:8}.jsonl"
fi
```

Remove the comment lines and the prose that describe `<encoded-cwd>`.

- [ ] **Step 5: Extend the `agent_runs` entry**

In "Session JSONL Capture Protocol", replace the entry comment with this line.

```bash
#   { agent, agentId, role, model, effort, dispatch_record, session_log, started_at, completed_at, status, output_files }
```

Add this paragraph after the bash block.

```markdown
`dispatch_record` and `session_log` are paths relative to the workspace root, for example `provenance/dispatch/L1-chunk-analyzer.md`. If no log was captured, `session_log` is `null`. The floor rule reads these fields at every gate.
```

- [ ] **Step 6: Add two lines to both summary templates in "Print Summary"**

Add them after the `Agents dispatched:` line. Align the values with the column of each template.

```text
Model tiers:       deep fable/high, standard opus/high, light sonnet/medium (substitutes: none)
Floor warnings:    N
```

- [ ] **Step 7: Prove the edits**

Run:

```bash
grep -c 'Floor warnings:' commands/analyze.md
grep -c 'greenfield-tiers floor workspace' commands/analyze.md
grep -c 'ENCODED_CWD\|encoded-cwd' commands/analyze.md
grep -c 'subagents/agent-\${AGENT_ID}.jsonl' commands/analyze.md
```

Expected: `2`, then `11` (ten gate calls and one mention in "Floor failures"), `0`, `2`.

- [ ] **Step 8: Commit**

```bash
git add commands/analyze.md
git commit -m "feat(analyze): enforce the model floor at every gate"
```

---

### Task 8: `/analyze` spec-remediator

**Files:**
- Modify: `commands/analyze.md`, sections "THE PIPELINE", "2c: Pre-flight Dispatch Count", "Gate 1" (Remediation Loop), "Gate 2" (Remediation Loop)

**Interfaces:**
- Consumes: "Model and effort" and "Raise rule" from Task 6.
- Produces: the role name `spec-remediator` in two dispatch prompts. The lint from Task 5 needs it.

- [ ] **Step 1: Replace the inline remediation in the Gate 1 loop**

In the Gate 1 "Remediation Loop" block, replace the three numbered comment lines with these lines.

```bash
  # 1. Dispatch spec-remediator (see "Remediation dispatch" below). Do NOT edit specs yourself.
  # 2. Commit its output
  # 3. Re-run spec-verifier at its floor (a judge is not raised)
```

Add this subsection after the loop block, before the floor block from Task 7.

```markdown
### Remediation dispatch

The orchestrator writes no spec text. For remediation attempt `N`, dispatch `greenfield:analyzer`:
- Prompt: "Role: spec-remediator (Gate 1). Follow the **behavioral-spec-writing skill** and the **provenance-methodology skill**. Workspace: `<workspace-path>`. Read the verification report at `workspace/raw/specs/verification-report.md`. For each finding, read the spec file and the section that the finding names, and the evidence in `workspace/raw/` that the finding cites. Correct only the sections that the report names. Do not rewrite other sections. Do not renumber SPEC IDs. Keep a provenance citation on every changed claim. Write the list of changes to `workspace/raw/specs/remediation-gate-1-round-<N>.md`."
- Model and effort: `greenfield-tiers lookup workspace spec-remediator <N-1>`
- Dispatch record: `L3-spec-remediator.md` for attempt 1, then `L3-spec-remediator-2.md` and `L3-spec-remediator-3.md`
- Commit: `[gate:spec-remediator] Gate 1 remediation round N`
```

- [ ] **Step 2: Replace the inline remediation in the Gate 2 loop**

Make the same two edits in "Gate 2", with these differences.

- Comment line 3 names `spec-reviewer`.
- The prompt starts `Role: spec-remediator (Gate 2). Follow the **behavioral-spec-writing skill**, the **validation-methodology skill**, and the **provenance-methodology skill**.`
- The prompt reads `workspace/raw/specs/review-notes.md` and corrects `only the files and the sections that the notes name`.
- The change list is `workspace/raw/specs/remediation-gate-2-round-<N>.md`.
- The dispatch records use the prefix `L4-`.
- The commit message is `[gate:spec-remediator] Gate 2 remediation round N`.

- [ ] **Step 3: Update the two overviews**

- In "THE PIPELINE", change both `(remediation loop, up to 3 attempts)` notes for Gate 1 and Gate 2 to `(remediation by spec-remediator, up to 3 attempts)`.
- In "2c: Pre-flight Dispatch Count", change the Gate 1 and Gate 2 lines so that each names `1 spec-remediator per remediation round [deep]`.

- [ ] **Step 4: Prove the edits**

Run:

```bash
grep -c 'Role: spec-remediator' commands/analyze.md
grep -c 'Fix each affected spec\|Fix each flagged issue' commands/analyze.md
scripts/lint-tiers.sh | grep -v readme-
```

Expected: `2`, `0`, and one line from the last command, `LINT FAIL: 49 problems`.

- [ ] **Step 5: Commit**

```bash
git add commands/analyze.md
git commit -m "feat(analyze): move gate remediation edits to a deep-tier subagent"
```

---

### Task 9: `/sanitize`

**Files:**
- Modify: `commands/sanitize.md`, frontmatter and Phases 1, 3, 4, and 5

**Interfaces:**
- Consumes: `greenfield-tiers preflight`, `init`, `lookup`, and `floor`. Consumes the record header from Task 6 and the judge prompt in `commands/analyze.md`, section "Contamination Check (ENFORCED)".
- Produces: dispatch records `L5-sanitizer-<n>.md` and `L5-contamination-judge-<n>.md` under `$ARGUMENTS/provenance/dispatch/`.

- [ ] **Step 1: Correct the frontmatter**

In `allowed-tools`, replace `Task` with `Agent`.

- [ ] **Step 2: Add the tier setup to Phase 1**

Add this block and paragraph at the end of "PHASE 1: Initial Assessment".

~~~markdown
```bash
greenfield-tiers preflight
greenfield-tiers init "$ARGUMENTS"
```

If `preflight` exits with status 3, stop and show its output to the user. Ask whether to end the run or to continue.
~~~

- [ ] **Step 3: Add the dispatch rules to Phase 3**

Start the sanitizer prompt with `Role: sanitizer. ` before `Follow the`. Add this subsection after the prompt.

~~~markdown
### Model, effort, and dispatch record

Before every Agent call in this command, run:

```bash
greenfield-tiers lookup "$ARGUMENTS" <role>
```

Pass the first word as `model` and the second word as `effort`. Do not let a dispatch inherit the session model. If a role runs again because its output failed, pass the count of earlier failed rounds as the last argument.

Before every Agent call, write the prompt to `$ARGUMENTS/provenance/dispatch/L5-<role>-<n>.md` with these header lines above the fenced prompt:

```markdown
**Dispatched:** 2026-01-01T12:00:00Z
**Subagent:** greenfield:sanitizer
**Round:** 1
**Scope:** full
**Role:** sanitizer
**Model:** fable
**Effort:** high
**Raised:** no
```

`**Raised:**` is `no` at the floor, and `yes: <reason>` above the floor.

After each agent returns, copy its session log and add an entry to `agent_runs` in `$ARGUMENTS/workspace.json`:

```bash
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESSION_JSONL=$(find "$CLAUDE_DIR/projects" -path "*/subagents/agent-${AGENT_ID}.jsonl" 2>/dev/null | head -1)
[ -n "$SESSION_JSONL" ] && cp "$SESSION_JSONL" "$ARGUMENTS/provenance/sessions/<role>-${AGENT_ID:0:8}.jsonl"
# agent_runs entry: { agent, agentId, role, model, effort, dispatch_record, session_log, status }
# dispatch_record and session_log are paths relative to the workspace root. session_log is null with no log.
```
~~~

Phase 4 dispatches the sanitizer too. Add one sentence at its start: `Each dispatch in this phase follows "Model, effort, and dispatch record" in Phase 3.`

- [ ] **Step 4: Move the Phase 5 verdicts to a subagent**

Replace the sentence that starts `**For EACH file in` with this text. Keep the "Verification Criteria", "The Reimplementor Test", and "Verification Report" subsections.

```markdown
Do not judge the files yourself. Batch the files in `$ARGUMENTS/output/specs/` into groups of 4 or 5. For each batch, dispatch `greenfield:analyzer` as `contamination-judge`. Dispatch at most 4 agents in parallel.

- Prompt: the `contamination-judge` prompt from `/analyze` Layer 5, with `$ARGUMENTS` as the workspace path. Add the five criteria below and the reimplementor test to the prompt. The agent writes its verdicts to `$ARGUMENTS/raw/audit/contamination-judge-batch-<n>.md`.
- Model, effort, and dispatch record: as in Phase 3, with the role `contamination-judge` and `**Subagent:** greenfield:analyzer`.

Build the verification report from the verdict files.
```

Copy the judge prompt text from `commands/analyze.md` into `commands/sanitize.md` in full. The `/sanitize` orchestrator does not read the other command file.

Add this block at the end of Phase 5, after the `**Any FAIL is a hard stop**` paragraph.

~~~markdown
```bash
greenfield-tiers floor "$ARGUMENTS" 5 || { echo "BLOCKED: model floor failed"; exit 1; }
```

If a dispatch record fails, dispatch the role again at the `lookup` values. Add `**Supersedes:** <failed record filename>` to the new record. If a session log fails, stop and ask the user. Never edit a record to clear a FAIL line.
~~~

- [ ] **Step 5: Prove the edits**

Run:

```bash
grep -c '^  - Task$' commands/sanitize.md
grep -c '^  - Agent$' commands/sanitize.md
grep -c 'Role: sanitizer\.' commands/sanitize.md
grep -c 'Role: contamination-judge' commands/sanitize.md
grep -c 'greenfield-tiers floor "\$ARGUMENTS" 5' commands/sanitize.md
scripts/lint-tiers.sh | grep -v readme-
```

Expected: `0`, `1`, `1`, `1`, `1`, and one line from the last command, `LINT FAIL: 49 problems`.

- [ ] **Step 6: Commit**

```bash
git add commands/sanitize.md
git commit -m "feat(sanitize): apply model tiers and move verdicts to a subagent"
```

---

### Task 10: README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: `model-tiers.tsv` and the lint codes `readme-tier` and `readme-role` from Task 5.

- [ ] **Step 1: Add the "Model tiers" section before "## License"**

The section holds these parts, in this order.

1. Two sentences: each role runs on a fixed model and effort, and the session model does not change them.
2. The tier table with the columns Tier, Model, Effort, and "One raise step". Use the three rows from the spec section "Tiers". Each row starts `| <tier> | <model> | <effort> |`.
3. The role table with the columns Tier, Stage, and Roles. Use the rows from the spec section "Role assignment".
4. One paragraph on the raise rule: one step per repeat dispatch after deficient output, with the ceiling fable/xhigh.
5. One paragraph for a user with no Fable access: change the `tier deep` row in `model-tiers.tsv`, and keep the two agent files equal to that row.
6. One paragraph on the two environment variables that override the table. They are `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` and `CLAUDE_CODE_EFFORT_LEVEL`.
7. One sentence on the minimum Claude Code version, 2.1.292.
8. One line on the tests: `scripts/test-tiers.sh` and `scripts/lint-tiers.sh`.

- [ ] **Step 2: Add `spec-remediator` to the role lists**

Add `spec-remediator` after `spec-verifier` in the analyzer role list under "How it works". Add it to the Gate 1 and Gate 2 rows of the Pipeline table.

- [ ] **Step 3: Run the lint and the tests**

Run: `scripts/lint-tiers.sh && scripts/test-tiers.sh`
Expected: `LINT OK`, then `test-tiers: 85 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: describe model tiers in the README"
```

---

### Task 11: Manual run from a Sonnet session

This task needs a person. It starts a real `/analyze` run and spends model usage. Do not start it without a go-ahead from the user.

**Files:**
- None in the repository. The run writes to a temporary directory.

**Interfaces:**
- Consumes: the whole change.

- [ ] **Step 1: Make a small target**

```bash
mkdir -p /tmp/gf-smoke/target && cd /tmp/gf-smoke
printf '#!/bin/sh\n# greet: print a greeting\nname="${1:-world}"\n[ "$GREET_SHOUT" = 1 ] && name=$(echo "$name" | tr a-z A-Z)\necho "hello, $name"\n' > target/greet.sh
```

- [ ] **Step 2: Start the run on Sonnet**

```bash
claude --plugin-dir /Users/jacob/Code/jacobthemyth/greenfield --model sonnet
```

In the session, enter:

```text
/greenfield:analyze target --workspace ./ws --exclude docs,sdk,community,runtime,binary,git-history,tests,visual,contracts,macos-bundle,macos-runtime,app-data
```

Stop the run after the line `LAYER 2 GATE PASSED` appears.

- [ ] **Step 3: Read the records**

```bash
cd /tmp/gf-smoke
grep -h '^\*\*\(Role\|Model\|Effort\|Raised\):' ws/provenance/dispatch/*.md | paste - - - -
PATH="/Users/jacob/Code/jacobthemyth/greenfield/bin:$PATH" greenfield-tiers floor ws 1
PATH="/Users/jacob/Code/jacobthemyth/greenfield/bin:$PATH" greenfield-tiers floor ws 2
```

Expected:
- `discovery-agent`, `bundle-splitter`, and `chunk-analyzer` show `opus` and `high`.
- `function-analyzer` shows `sonnet` and `medium`.
- The five Layer 2 roles show `fable` and `high`.
- No record shows `Raised: yes`.
- Both `floor` commands end with `FLOOR L1: PASS` and `FLOOR L2: PASS`.
- No `WARN` line holds `no session log` or `no agent_runs entry`.

- [ ] **Step 4: Act on a failed expectation**

| Result | Meaning | Action |
|--------|---------|--------|
| The session reports that `greenfield-tiers` is not found. | The plugin `bin/` directory is not on the PATH. | Stop. Report it to the user. The design depends on this fact. |
| A record shows the session model. | The orchestrator did not follow "Model and effort". | Tighten the wording of that section, then repeat this task. |
| `WARN ... no session log` | The capture path in Task 7 is wrong. | Find one log with `find ~/.claude/projects -name 'agent-*.jsonl' -newer ws/workspace.json`, correct the `find` pattern, then repeat. |
| `FAIL ... ran on` | Claude Code replaced a model. | Report the line to the user. Do not change the floor. |

- [ ] **Step 5: Report**

Give the user the output of Step 3. If no file changed, no commit is necessary.
