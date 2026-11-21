---
name: analyze
description: Reverse engineer a codebase into the output behavioral specs with provenance
arguments:
  - name: path
    description: Path to the target (source code, bundle, binary, or installed software) or an https:// product URL
    required: true
  - name: --exclude
    description: >
      Comma-separated list of source types to exclude from analysis.
      Valid types: source, docs, sdk, community, runtime, binary, git-history, tests, visual, contracts, macos-bundle, macos-runtime, app-data.
      By default, all available sources are analyzed.
    required: false
    default: (none)
  - name: --container-runtime
    description: Container runtime to use for runtime observation mode
    required: false
    default: auto-detect (docker, then podman)
    values: [docker, podman]
  - name: --macos-env
    description: >
      Pre-select the macOS runtime environment, skipping the Runtime Environment Gate's
      environment question (host-direct still asks its disposable-account confirmation).
      A vm-* value on an x86_64 host is rejected at the gate, not at parse time.
    required: false
    default: (ask at the Runtime Environment Gate)
    values: [vm-tart, vm-lume, host-direct, none]
  - name: --keep-vm
    description: Skip deletion of the working VM at cleanup (for debugging); prints the reclaim command in the summary.
    required: false
    default: (delete the working VM)
  - name: --workspace
    description: Path to the workspace directory. Created if it does not exist.
    required: false
    default: ./analysis-workspace
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Task
  - Bash
  - Agent
  - TodoWrite
  - LSP
---

# /analyze - Reverse Engineering

Target: $ARGUMENTS

## THE APPROACH

**Analyze deeply. Output behaviorally.**

- **Analysis:** Tear apart the target through every available intelligence source. Trace every code path. Observe every runtime behavior. Read every public document.
- **Output:** Write specs using behavioral language. No source identifiers. Every claim carries provenance.

You READ `Ab2()` and trace what it does.
You WRITE "entry point parses arguments and routes to mode handler."

## EXHAUSTIVE READING (NON-NEGOTIABLE)

**Every line of code must be read. Every routine must be identified.**

- Do NOT skim code. Do NOT skip "boring" sections.
- Grep patterns are for INDEXING - they are NOT a substitute for reading.
- If you haven't read a line, you don't know what it does.
- If you haven't traced a code path, you can't document its behavior.

Agents MUST use the Read tool on every source file. Head/tail samples are not enough.

## CLI INTERFACE

```
/analyze path                              # Discover and consume everything available
/analyze path --exclude source             # Black-box analysis (skip source code)
/analyze path --exclude git-history,tests  # Skip git mining and test suite analysis
/analyze /Applications/Foo.app             # Native macOS app (static host analysis + chosen runtime environment)
/analyze https://example.com/product       # URL target (discovery resolves to installed app, if any)
/analyze /Applications/Foo.app --macos-env vm-tart  # Pre-select a Tart VM runtime environment (skips the gate's environment question)
/analyze path --exclude macos-runtime,app-data  # Static-only macOS analysis (skips the runtime environment gate entirely)
```

## EXIT CODES

| Code | Meaning |
|------|---------|
| 0 | Success. Analysis completed, all gates passed. |
| 1 | Failure. Gate failure, workspace conflict, container unavailable, runtime environment unavailable, etc. |
| 2 | Invalid arguments. Bad mode name, missing path, etc. |

## OUTPUT STRUCTURE

```
workspace/
├── .git/                    # Git repository (initialized by /analyze)
├── .gitignore               # Exclusions
├── workspace.json           # Workspace metadata
├── inventory.md             # Intelligence source inventory (from discovery)
│
├── public/                  # PUBLIC: From public sources only
│   ├── docs/                # Official documentation findings
│   ├── standards/           # RFC/standard mappings
│   ├── ecosystem/           # SDK analysis, test mining
│   ├── community/           # Tutorials, reviews, forums, issues
│   └── contracts/           # Machine-readable contract definitions
│
├── raw/                 # RAW: Source-derived analysis artifacts
│   ├── source/              # Source code analysis artifacts
│   │   ├── chunks/          # Bundle decomposition output
│   │   ├── analysis/        # Per-chunk analysis files
│   │   ├── functions/       # Extracted function analyses
│   │   ├── manifests/       # Bundle manifests
│   │   ├── exploration/     # Targeted-extractor output per focus area
│   │   └── decompiled/      # Decompiled binary/bytecode output
│   │
│   ├── runtime/             # Runtime observation artifacts
│   │   ├── cli/             # CLI interaction transcripts
│   │   ├── web/             # Web UI screenshots, state maps
│   │   ├── behaviors/       # Observed behaviors
│   │   ├── ux/              # UX capture (output formats, errors, prompts)
│   │   └── visual/          # Visual exploration output
│   │       ├── screenshots/ # Key screen captures
│   │       └── flows/       # UI flow sequences
│   │
│   ├── binary/              # Binary analysis artifacts
│   │   ├── survey/          # Initial triage output
│   │   └── analysis/        # Deep analysis output
│   │
│   ├── macos/               # Native macOS app analysis artifacts
│   │   ├── bundle/          # Static bundle analysis: Info.plist, entitlements, sdef, strings catalogs
│   │   ├── runtime/         # Runtime environment observation: OBS records, scripting dumps, screenshots + AX sidecars
│   │   │   ├── observations/
│   │   │   ├── scripting/
│   │   │   ├── screenshots/
│   │   │   ├── flows/       # Interaction flow captures: step-NN screenshots + AX sidecars + flow.md
│   │   │   └── mutations/   # Write/mutation probe captures
│   │   └── app-data/        # Runtime environment data stores: schema, baseline, defaults, DBQ records
│   │       ├── baseline/    # Pre-mutation data-store baseline
│   │       └── mutation-diffs/  # Data-store diffs after mutation probes
│   │
│   ├── project-history/     # Git archaeology findings
│   │
│   ├── test-evidence/       # Test suite analysis output
│   │
│   ├── synthesis/           # Layer 2 synthesized findings
│   │   ├── features/        # Aggregated feature inventory
│   │   ├── architecture/    # Synthesized architecture
│   │   ├── api/             # Synthesized API surface
│   │   └── module-map.md    # All modules identified
│   │
│   ├── specs/               # Layer 3+4 raw specs (pre-sanitization)
│   │   ├── modules/         # Per-module behavioral specs (analysis organization)
│   │   ├── journeys/        # End-to-end user flows
│   │   ├── contracts/       # External interfaces
│   │   ├── protocols/       # Wire protocols
│   │   ├── ui/              # User-visible text
│   │   ├── tests/           # Test specifications
│   │   ├── test-vectors/    # Concrete input/output pairs
│   │   └── validation/      # Acceptance criteria
│   │
│   └── audit/               # Detailed per-finding audit reports from Layers 6 and 7
│
├── environment/             # Runtime environment artifact
│
├── output/                   # Sanitized specs for the implementer
│   ├── specs/
│   │   ├── domains/         # Behavioral specs merged by domain (NOT original modules)
│   │   ├── journeys/        # Sanitized user journey specs
│   │   └── contracts/       # External contracts + behavioral integration requirements
│   ├── test-vectors/        # Output test vectors
│   ├── validation/          # Output acceptance criteria
│   ├── audit/               # Top-level PASS/FAIL summaries of Layers 6 and 7
│   └── implementation/      # Implementation output
│
└── provenance/              # AUDIT: Trail and citations
    ├── sessions/            # Subagent JSONL copies
    ├── dispatch/            # Verbatim dispatch prompts, one per agent call (L<layer>-<role>.md)
    └── audit-log.md         # Human-readable audit log
```

## THE PIPELINE

All agents are dispatched as `greenfield:analyzer` (or `greenfield:sanitizer` for Layer 5) with role-specific prompts. Each prompt specifies the role, which skill to follow, inputs, outputs, and DOD.

Each dispatch takes its model and effort from the tier file (see **Model and effort**), never from the session model.

```
Workspace Init              → workspace/ (git init, directory structure, workspace.json)
         ↓
Layer 1: Intelligence       → discovery-agent, then analyzer per approved source type
         ↓
Layer 2: Synthesis          → analyzer × 3 roles (parallel), then synthesizer, then mapper
         ↓
Layer 3: Deep Documentation → analyzer × 4 roles (deep-dive per module, behavior docs,
                              journeys, contracts)
         ↓
Gate 1:  Verification       → analyzer as spec-verifier (remediation by spec-remediator, up to 3 attempts)
         ↓
Gate 1b: Source Completeness → analyzer × N (grep source for tools, env vars, flags, commands;
                               diff against specs; remediate gaps before proceeding)
         ↓
Layer 4: Test & Validation  → analyzer × 3 roles (test vectors, test specs, acceptance criteria)
         ↓
Gate 2:  Review             → analyzer as spec-reviewer (remediation by spec-remediator, up to 3 attempts)
         ↓
Decision Point:             → Ask user: stop here with raw specs, or sanitize?
         ↓ (only if user opts in)
Layer 5: Sanitization       → sanitizer × N (one per domain group, REWRITE not copy)
         ↓
Layer 6: Second-Pass Review →  Phase 1: analyzer × 3 (semantic structural, content, completeness)
                              Phase 2: analyzer × N (deep-read auditors, 4-5 files each)
                              (remediation: sanitizer rewrites, up to 3 rounds)
         ↓
Layer 7: Fidelity Check     → analyzer × N (cross-validate raw vs output for info loss)
                              (remediation: sanitizer restores lost detail, up to 3 rounds)
```

---

## Step 0: Argument Validation

Validate all arguments before any work begins.

```bash
# Validate target: a filesystem path (a .app bundle is a directory — it passes the -d check)
# or an http(s):// product URL
case "$ARGUMENTS" in
  http://*|https://*)
    TARGET_KIND=url   # discovery resolves URL → product → installed app (if any)
    ;;
  *)
    [ -d "$ARGUMENTS" ] || [ -f "$ARGUMENTS" ] || { echo "ERROR: Target path does not exist: $ARGUMENTS"; exit 2; }
    TARGET_KIND=path
    ;;
esac

# Validate --exclude (if provided)
# Valid values: source, docs, sdk, community, runtime, binary, git-history, tests, visual, contracts,
#               macos-bundle, macos-runtime, app-data
# Reject unknown type names immediately with exit code 2

# Validate --container-runtime (if provided)
# Valid values: docker, podman
# Only relevant when runtime observation is active

# Validate --macos-env (if provided)
# Valid values: vm-tart, vm-lume, host-direct, none
# Reject any other value immediately with exit code 2.
# NOTE: a vm-* value on an x86_64 host is NOT rejected here — the arch probe lives at the
# Runtime Environment Gate, which rejects vm-* on x86_64 there, not at parse time.

# Validate --workspace
# If workspace exists and contains .git, proceed with incremental analysis
# If workspace does not exist, create fresh
```

### Model override preflight

```bash
greenfield-tiers preflight
```

If the command exits with status 3, stop and show its output to the user. Ask whether to end the run or to continue. If the user continues, append the output and the answer to `provenance/audit-log.md` after Step 1 creates the workspace.

If the shell cannot find `greenfield-tiers`, stop with exit code 1. The plugin `bin/` directory is not on the PATH.

---

## Step 1: Workspace Initialization

```bash
WORKSPACE="${WORKSPACE_ARG:-./analysis-workspace}"
```

### If `$WORKSPACE/.git` exists (incremental):

Existing workspace detected. Running incremental analysis per **incremental-analysis skill**.

```bash
cd "$WORKSPACE"

# Read workspace.json for original configuration (target path, excluded types, etc.)
# Read agent_runs to find last completed agent
# Read current_layer to know where we are in the pipeline

# Copy the model tier file (a workspace copy that exists is kept)
greenfield-tiers init .

# Skip all completed steps
# Resume from the first incomplete step

# Runtime-environment resume: before dispatching any macos-runtime or app-data agent,
# read workspace.json.runtime_environment. If its environment is vm-tart or vm-lume,
# verify the working VM still exists and runs (`tart list`). If the VM is gone,
# re-provision it from the recorded base_image per the macos-vm-execution skill;
# otherwise (no recorded environment, or a stale/none record) re-run the Runtime
# Environment Gate before dispatching any macos-runtime/app-data agent.

# Log: "Resuming from Layer {N}, after {last-agent-name}"
```

### If `$WORKSPACE/.git` does NOT exist (fresh start):

Initialize the git-versioned workspace.

```bash
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"
git init

# Create full directory structure with .gitkeep files
mkdir -p public/docs public/standards public/ecosystem public/community
mkdir -p public/contracts
mkdir -p raw/source/chunks raw/source/analysis raw/source/functions raw/source/manifests raw/source/exploration
mkdir -p raw/source/decompiled
mkdir -p raw/runtime/cli raw/runtime/web raw/runtime/behaviors raw/runtime/ux-flows
mkdir -p raw/runtime/visual/screenshots raw/runtime/visual/flows
mkdir -p raw/binary/survey raw/binary/analysis
mkdir -p raw/project-history
mkdir -p raw/macos/bundle raw/macos/runtime/observations raw/macos/runtime/scripting raw/macos/runtime/screenshots raw/macos/runtime/flows raw/macos/runtime/mutations raw/macos/app-data raw/macos/app-data/baseline raw/macos/app-data/mutation-diffs environment
mkdir -p raw/test-evidence
mkdir -p raw/synthesis/features raw/synthesis/architecture raw/synthesis/api
mkdir -p raw/specs/modules raw/specs/journeys raw/specs/contracts raw/specs/protocols raw/specs/ui raw/specs/tests raw/specs/test-vectors raw/specs/validation
mkdir -p output/specs/domains output/specs/journeys output/specs/contracts output/test-vectors output/validation/acceptance-criteria output/public
mkdir -p provenance/sessions provenance/dispatch

# Place .gitkeep in every leaf directory
find . -type d -empty -not -path './.git/*' -exec touch {}/.gitkeep \;

# Write workspace.json with initial values
# (version, target, target_kind: path|url, resolved_app_path: <path>|null,
#  runtime_environment: { environment, vm_name, base_image, ssh_target, host_account,
#    signature_verdict, affirmed_disposable_account, acquisition, decided_at }|null,
#  excluded_types, created_at, updated_at, current_layer: 1, gates_passed: [], agent_runs: [])

# Write .gitignore (container build artifacts, large binaries, temp files, OS/editor artifacts, node_modules)

# Copy the model tier file (a workspace copy that exists is kept)
greenfield-tiers init .

# Initial commit
git add -A
git commit -m "[init] Create analysis workspace for <target-name>"
```

---

## Step 2: Autonomous Discovery

Instead of relying on user-specified modes, Layer 1 begins with autonomous discovery of all available intelligence sources.

### 2a: Dispatch discovery agent

Dispatch `greenfield:analyzer`:
- Prompt: "Role: discovery-agent. Follow the **autonomous-discovery skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Excluded types: `<--exclude value or 'none'>`. Probe the target for all available intelligence sources: source code, documentation, SDK/package presence, community content, runtime executability, binary artifacts, git history, test suites, visual UI, machine-readable contracts, macOS app bundles (static bundle facts), host-observable macOS runtime, and application data stores. If the target is a macOS `.app` bundle (or a URL that resolves to an installed app via Spotlight), additionally probe per the autonomous-discovery skill Phase 1.8: bundle facts, code signature, scripting dictionary presence, and conventional data locations — passive checks only, never launch the app or read its data containers. Write an inventory to `workspace/inventory.md` listing each source type, its availability (available/unavailable/excluded), and a brief rationale."
- Commit: `[L1:discovery] Intelligence source inventory`

This dispatch follows the Agent Dispatch Protocol below: run `greenfield-tiers lookup` for `discovery-agent`, and write the record `L1-discovery-agent.md` before the call.

### 2b: Present inventory for negotiation

After the discovery agent returns, read `workspace/inventory.md` and present the inventory to the user. The user may approve the plan, exclude additional sources, or override unavailability judgments. Update `workspace/inventory.md` with the negotiated plan and commit:

```bash
git add workspace/inventory.md
git commit -m "[L1:discovery] Negotiated intelligence source plan"
```

### 2c: Pre-flight Dispatch Count

Before the fan-out begins, print a count of the agent dispatches this run will attempt, based on the approved source types in `workspace/inventory.md`. This is NOT a budget or a dollar estimate — we can't predict token usage, dollar cost, or precise wall-clock from the orchestrator side. It is a structural count so the user knows whether the run is 10 agents or 100.

Compute the count from the negotiated inventory. The bundle-splitter's chunk count is known only after it runs, so Layer 1's `source` line is the only number with a wide range; everything else is deterministic from the inventory.

```
========================================================================
Pre-flight dispatch count (Layers 1–4, before sanitization decision point):

  Layer 1 (Intelligence)
    - 1 discovery agent (already ran) [standard]
    - Per approved source type:
        source       1 bundle-splitter + 1 per chunk (count known after
                     splitting) + 1 function-analyzer [standard + light]
        docs         1 doc-researcher [standard]
        community    1 community-analyst [light]
        sdk          1–2 agents [light]
        runtime      4 agents (cli-explorer, web-ui-explorer,
                     behavior-observer, ux-documenter) [standard]
        binary       2 agents (surveyor + deep-analyzer) [standard + light]
        git-history  1 agent [light]
        tests        1–2 agents [standard + light]
        visual       1 agent [standard]
        contracts    1 agent [light]
        macos-bundle 1 agent (bundle-inspector) [standard]
        macos-runtime 2 agents (applescript-explorer, ui-observer) —
                     pending the Runtime Environment Gate [standard]
        app-data     1 agent (data-inspector) — pending
                     the Runtime Environment Gate [standard]
                     NOTE: a VM environment (vm-tart/vm-lume) adds a one-time
                     provisioning step — a first-use image pull of tens of
                     minutes and tens of GB — that is NOT an agent dispatch and
                     is not counted here.
  Layer 2 (Synthesis):       5 agents [deep]
  Layer 3 (Deep docs):       1 deep-dive per module (module count known
                             after Layer 2) + 3 cross-cutting roles [deep]
  Gate 1 + Gate 1b:          2 agents + up to 3 remediation rounds each.
                             Gate 1 uses 1 spec-remediator per remediation round [deep]
  Layer 4 (Validation):      3 agents [standard]
  Gate 2:                    1 agent + up to 3 remediation rounds,
                             1 spec-remediator per remediation round [deep]

  If you opt in to Layers 5–7 at the decision point after Gate 2:
    Layer 5 (Sanitization):   1 sanitizer per domain group + contamination
                              judges (batched 4–5 files each) [deep]
    Layer 6 (Second-Pass):    3 semantic reviewers + deep-read auditors
                              (batched 4–5 files each) [deep]
    Layer 7 (Fidelity):       fidelity validators (batched 4–5 modules each) [deep]

  Token usage, dollar cost, and wall-clock depend on target size,
  language, source quality, and how many remediation rounds the gates
  need — the orchestrator can't predict them. If your session budget is
  tight, narrow the inventory via --exclude and/or decline Layers 5–7 at
  the decision point.
========================================================================
```

Ask the user to confirm. On `y`, proceed. On `n`, stop with exit 0 and leave the workspace in place (discovery output is preserved; user can resume with `/analyze` later).

---

## Agent Dispatch Protocol

Every agent dispatch in this pipeline uses the **Agent tool** with `subagent_type: "greenfield:analyzer"`.

### Dispatch pattern

For each role listed below:

1. **Call the Agent tool** with:
   - `subagent_type`: `"greenfield:analyzer"`
   - `prompt`: Include the **role**, which **skill** to follow, the workspace absolute path, what to read, what to produce, and where to write.
   - `description`: Short label for the task (shown in UI)
   - `model` and `effort`: the two values that `greenfield-tiers lookup` prints for the role (see **Model and effort** below). Pass both on every dispatch.

2. **After the agent returns**, commit its output:
   ```bash
   cd <workspace>
   git add -A
   git commit -m "<commit-message>"
   ```

3. **Parallel dispatch with batching**: When multiple agents in the same phase have no dependencies on each other, dispatch them in a single message with multiple Agent tool calls — BUT cap the batch size at **4 parallel agents**. Firing 20+ agents in a single parallel burst is a reliable way to hit a per-model rate limit mid-pipeline. Wait for each batch of 4 to complete, commit its output, then dispatch the next batch of 4. This applies to chunk-analyzers (Layer 1), deep-dive analyzers (Layer 3), contamination judges (Layer 5 verification), deep-read auditors (Layer 6 Phase 2), and fidelity batches (Layer 7). If the runtime exposes remaining-quota info, prefer a dynamic batch size; otherwise stick to 4.

### Model and effort

Each role has a floor: the weakest model and effort that the role can run on. The floors are in `workspace/provenance/model-tiers.tsv`. Do not select a model from memory. Do not let a dispatch inherit the session model.

Before every Agent call, run:

```bash
greenfield-tiers lookup workspace <role>
```

The command prints two words, for example `opus high`. Pass the first word as `model` and the second word as `effort`. If the command fails, do not dispatch the role. A role that the tier file does not list has no floor. `lookup` fails for it, so do not dispatch it.

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

### Floor failures

Every gate runs `greenfield-tiers floor workspace <layer>`. A FAIL line fails the gate. A WARN line does not.

- If a dispatch record fails, dispatch the role again for the same full scope at the `lookup` values. Add `**Supersedes:** <failed record filename>` to the new record. Discard the output of the earlier dispatch.
- A superseding dispatch runs at the floor values: run `lookup` with no steps. A floor failure is not deficient output, so the raise rule does not apply.
- If a substitute lowered a tier after some dispatches of the layer ran, the earlier records of that layer can FAIL as above the floor with **Raised:** no. In that case, stop and ask the user. Do not repeat the work.
- If a session log fails, Claude Code ran a weaker model than the dispatch named. Stop and ask the user, as in **Model not available**.
- Never edit or delete a dispatch record to clear a FAIL line.
- Print each WARN line in the final summary.

### Dispatch record

**Before** every Agent call — not after, not in a batch at the end — write the prompt you are about to send, verbatim, to `workspace/provenance/dispatch/L<layer>-<role>.md`.

Why this exists: in a real run, an agent's output referred to a narrowed "Part 1" scope that appears nowhere in the workspace. Nothing on disk could say whether the orchestrator had handed that agent a trimmed assignment or whether the agent had simply done a fraction of the work it was given. "The instructions were narrowed" and "the agent underperformed" are the same evidence after the fact, and they call for opposite fixes. The prompt as sent is the only artifact that separates them, and it costs one file write.

Format — eight header lines, then the prompt in a fence:

````markdown
**Dispatched:** 2026-01-01T12:00:00Z
**Subagent:** greenfield:analyzer
**Round:** 1
**Scope:** full
**Role:** chunk-analyzer
**Model:** opus
**Effort:** high
**Raised:** no

```text
<the prompt string passed to the Agent tool, byte-for-byte>
```
````

- `**Scope:**` is `full` when the prompt is the one this command specifies, or `narrowed — <what was excluded>` when anything was trimmed (a phase dropped, a source subset, a shortened deliverable list). Narrowing is allowed; narrowing silently is not.
- `**Round:**` is `1` for the initial dispatch and increments for each remediation dispatch of the same role.
- **Remediation rounds append, never overwrite.** Round 2 of `ui-observer` is written to `L1-ui-observer-2.md`, round 3 to `L1-ui-observer-3.md`. The round-1 file stays exactly as it was sent — overwriting it destroys the comparison the record exists to make.
- Filenames use the role name as spelled in this command: `L1-ui-observer.md`, `L1-applescript-explorer.md`, `L1-data-inspector.md`, `L2-module-mapper.md`, `L3-deep-dive-<module>.md`, and so on. Parallel batches get one file per agent, not one per batch.
- The record is committed with the agent's output in the same commit.
- `**Role:**` is the role name as the tier file spells it.
- `**Model:**` and `**Effort:**` are the two values that you pass on the Agent call.
- `**Raised:**` is `no` at the floor, and `yes: <reason>` above the floor.
- `**Supersedes:** <record filename>` is an optional ninth line. Add it only if this dispatch repeats the full work of an earlier dispatch and replaces its output.
- Fixed prefixes: `discovery-agent` uses `L1-`. Gate 1, Gate 1b, and their remediation use `L3-`. Gate 2 and its remediation use `L4-`.
- The prefix is the layer whose gate runs next after the dispatch, not the layer where the role first ran. Examples: a sanitizer remediation in Layer 6 uses `L6-`, and one in Layer 7 uses `L7-`. A Layer 6 deep-read audit that Layer 7 runs again uses `L7-`. A Gate 1b observer re-dispatch uses `L3-`.

### Session capture

The Agent tool returns an `agentId` for each dispatch. After the agent completes, this ID maps to a session JSONL file. To capture provenance:

```bash
# A subagent log is at <claude-dir>/projects/<project>/<session-id>/subagents/agent-<agentId>.jsonl
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESSION_JSONL=$(find "$CLAUDE_DIR/projects" -path "*/subagents/agent-${AGENT_ID}.jsonl" 2>/dev/null | head -1)

if [ -n "$SESSION_JSONL" ]; then
  cp "$SESSION_JSONL" "workspace/provenance/sessions/<role>-${AGENT_ID:0:8}.jsonl"
fi
```

Session capture is best-effort. If the JSONL file cannot be found, log a warning and continue.

---

## Layer 1: Intelligence Gathering

Dispatch agents for each approved source type from the negotiated inventory. Sources are independent — dispatch all approved sources in parallel where possible. Exceptions: `macos-bundle` must complete before the Runtime Environment Gate (the gate reads its signature verdict); `macos-runtime` and `app-data` run only after that gate records an environment other than `none`, and the two `macos-runtime` agents run sequentially (a single Aqua session per environment, not the user's host), never in a parallel batch with any other agent that drives the UI.

Read `workspace/inventory.md` to determine which source types are approved. For each approved source type, dispatch the corresponding agent(s) below. Skip any source type marked as excluded or unavailable (types the gate marked excluded are marked excluded in the inventory and are skipped identically).

### Source: source (Source Code Analysis)

**Step 1: bundle-splitter**

Dispatch `greenfield:analyzer`:
- Prompt: "Role: bundle-splitter. Follow the **source-analysis skill** Phases B1-B5. Target source path: `<target-path>`. Workspace: `<workspace-path>`. Read every source file. Decompose the target into logical chunks. Write chunk manifest to `workspace/raw/source/manifests/` and individual chunk files to `workspace/raw/source/chunks/`."
- Commit: `[L1:bundle-splitter] Decompose main bundle into N chunks`

**Beautification (if minified):**
```bash
cd workspace/raw/source/chunks
find . -name "*.js" -exec npx js-beautify -r {} \; 2>/dev/null || true
```

**Step 2: chunk-analyzer (parallel, one per chunk)**

For each chunk from the manifest, dispatch `greenfield:analyzer`:
- Prompt: "Role: chunk-analyzer. Follow the **source-analysis skill** Phase 6. Workspace: `<workspace-path>`. Read chunk file at `workspace/raw/source/chunks/<chunk-file>` and its corresponding source files. Write analysis to `workspace/raw/source/analysis/<chunk-name>.md`."
- Dispatch all chunk-analyzer workers in parallel (multiple Agent tool calls in one message)
- Commit: `[L1:chunk-analyzer] Analyze N chunks`

**Step 3: function-analyzer**

Dispatch `greenfield:analyzer`:
- Prompt: "Role: function-analyzer. Follow the **source-analysis skill** Phase 7. Workspace: `<workspace-path>`. Read all chunk analyses in `workspace/raw/source/analysis/` and the source files they reference. Extract function-level analysis. Write to `workspace/raw/source/functions/`."
- Commit: `[L1:function-analyzer] Extract function-level analysis`

### Source: docs (Official Documentation)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: doc-researcher. Follow the **doc-research skill** for the full methodology. Target: `<target-path>`. Workspace: `<workspace-path>`. Research official documentation for this project. Search the web for official docs, README, guides. Extract behavioral claims. Write findings to `workspace/public/docs/`."
- Commit: `[L1:doc-researcher] Extract behavioral claims from official docs`

### Source: community (Community Intelligence)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: community-analyst. Follow the **community-intelligence skill** for the full methodology. Target: `<target-path>`. Workspace: `<workspace-path>`. Search for tutorials, blog posts, reviews, forum threads, GitHub issues, and video content about this product. Extract behavioral observations from community sources. Write findings to `workspace/public/community/`."
- Commit: `[L1:community-analyst] Extract behavioral observations from community sources`

### Source: sdk (SDK & Ecosystem Analysis)

Dispatch these two in parallel:

**sdk-analyzer** → `greenfield:analyzer`:
- Prompt: "Role: sdk-analyzer. Follow the **ecosystem-analysis skill** for the full methodology. Target: `<target-path>`. Workspace: `<workspace-path>`. Analyze the SDK surface, package registry presence, and integration patterns. Write findings to `workspace/public/ecosystem/`."
- Commit: `[L1:sdk-analyzer] Analyze SDK surface and integration patterns`

**integration-test-miner** → `greenfield:analyzer`:
- Prompt: "Role: integration-test-miner. Follow the **ecosystem-analysis skill** for the full methodology. Target: `<target-path>`. Workspace: `<workspace-path>`. Find and analyze public test suites for behavioral claims. Write findings to `workspace/public/ecosystem/`."
- Commit: `[L1:integration-test-miner] Extract behavioral claims from public test suites`

### Source: runtime (Runtime Observation)

Requires container runtime. Uses `--container-runtime` flag or auto-detects (docker, then podman).

First, build/start the container for the target (per container-execution skill).

Then dispatch all four runtime agents in parallel:

**cli-explorer** → `greenfield:analyzer`:
- Prompt: "Role: cli-explorer. Follow the **runtime-observation skill** for the five-phase methodology, and the **container-execution skill** for container interaction. Explore the CLI interface by running commands. Exploration phases: help text discovery, subcommand enumeration, flag discovery per subcommand, flag combination testing, error message collection. Workspace: `<workspace-path>`. Container: `<container-name>`. Write transcripts to `workspace/raw/runtime/cli/`."
- Commit: `[L1:cli-explorer] CLI exploration session`

**web-ui-explorer** → `greenfield:analyzer`:
- Prompt: "Role: web-ui-explorer. Follow the **runtime-observation skill** for the five-phase methodology, and the **container-execution skill** for container interaction. Explore any web UI exposed by the target. Exploration phases: port discovery, landing page capture, navigation mapping, form/API endpoint discovery, authentication flow probing. Workspace: `<workspace-path>`. Container: `<container-name>`. Write findings to `workspace/raw/runtime/web/`."
- Commit: `[L1:web-ui-explorer] Web UI exploration session`

**behavior-observer** → `greenfield:analyzer`:
- Prompt: "Role: behavior-observer. Follow the **runtime-observation skill** for the five-phase methodology, and the **container-execution skill** for container interaction. Observe runtime behaviors through interaction and system monitoring. Exploration phases: state machine discovery, persistence probing, concurrency behavior, resource limit testing, signal handling. Workspace: `<workspace-path>`. Container: `<container-name>`. Write to `workspace/raw/runtime/behaviors/`."
- Commit: `[L1:behavior-observer] Observe runtime behaviors`

**ux-documenter** → `greenfield:analyzer`:
- Prompt: "Role: ux-documenter. Follow the **runtime-observation skill** for observation format and confidence rules, and the **container-execution skill** for container interaction. Document the actual user experience: onboarding, primary workflow journeys, error recovery paths, error message catalog, interactive flows, output formatting, timing. Write IMMEDIATELY as you go — do not accumulate. Workspace: `<workspace-path>`. Container: `<container-name>`. Write to `workspace/raw/runtime/ux-flows/`."
- Commit: `[L1:ux-documenter] Document UX patterns`

### Source: binary (Binary Analysis)

Dispatch sequentially (deep-analyzer depends on surveyor output):

**Step 1: binary-surveyor** → `greenfield:analyzer`:
- Prompt: "Role: binary-surveyor. Follow the **binary-analysis skill** Phase 1 (Survey). Target: `<target-path>`. Workspace: `<workspace-path>`. Triage the binary: identify format, sections, symbols, strings. Write survey to `workspace/raw/binary/survey/`."
- Commit: `[L1:binary-surveyor] Binary triage: format, sections, symbols, strings`

**Step 2: binary-deep-analyzer** → `greenfield:analyzer`:
- Prompt: "Role: binary-deep-analyzer. Follow the **binary-analysis skill** Phase 2 (Deep Analysis). Workspace: `<workspace-path>`. Read survey results from `workspace/raw/binary/survey/`. Perform deep analysis: control flow, data structures, behavioral patterns. Write to `workspace/raw/binary/analysis/`."
- Commit: `[L1:binary-deep-analyzer] Deep binary analysis`

### Source: git-history (Git Archaeology)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: git-archaeologist. Follow the **git-archaeology skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Mine the git history for behavioral evolution: major refactors, feature introductions, removed features, configuration changes, migration patterns, and commit message conventions. Write findings to `workspace/raw/project-history/`."
- Commit: `[L1:git-archaeologist] Mine git history for behavioral evolution`

### Source: tests (Test Suite Analysis)

Always dispatch the test-reader. Optionally dispatch the test-runner if the target has a runnable test suite.

**test-reader** → `greenfield:analyzer`:
- Prompt: "Role: test-reader. Follow the **test-suite-analysis skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Read the target's test suite exhaustively. Extract behavioral claims: what each test asserts, edge cases covered, expected error conditions, integration boundaries. Write findings to `workspace/raw/test-evidence/`."
- Commit: `[L1:test-reader] Extract behavioral claims from test suite`

**test-runner** (optional, if test suite is runnable) → `greenfield:analyzer`:
- Prompt: "Role: test-runner. Follow the **test-suite-analysis skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Run the target's test suite and capture results: passing tests confirm expected behaviors, failing tests reveal gaps or regressions, skipped tests indicate known limitations. Write results to `workspace/raw/test-evidence/`."
- Commit: `[L1:test-runner] Execute test suite and capture results`

### Source: visual (Visual Exploration)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: visual-explorer. Follow the **visual-exploration skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Capture visual state of the running application: screenshots of key screens, UI flow sequences, visual state transitions. Write screenshots to `workspace/raw/runtime/visual/screenshots/` and flow documentation to `workspace/raw/runtime/visual/flows/`."
- Commit: `[L1:visual-explorer] Capture visual UI state and flows`

### Source: contracts (Machine-Readable Contracts)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: contract-parser. Follow the **contract-detection skill**. Target: `<target-path>`. Workspace: `<workspace-path>`. Parse machine-readable contract definitions: OpenAPI/Swagger specs, JSON Schema files, Protocol Buffer definitions, GraphQL schemas, WSDL files, AsyncAPI specs. Extract behavioral constraints and interface contracts. Write findings to `workspace/public/contracts/`."
- Commit: `[L1:contract-parser] Parse machine-readable contract definitions`

### Source: macos-bundle (Static Bundle Analysis)

No runtime environment required — static, read-only, the app is never launched. **This source always runs on the host** and reads only vendor-shipped bundle contents. When the runtime environment later runs a DIFFERENT binary than the host build (vendor-download acquisition, or a detected version/signing mismatch), the `macos-vm-execution` skill triggers an in-environment re-run of macos-bundle + binary-analysis against the executed artifact and records the host-vs-environment diff at `workspace/raw/macos/bundle/environment-diff.md`.

Dispatch `greenfield:analyzer`:
- Prompt: "Role: bundle-inspector. Follow the **macos-bundle-analysis skill**. Target bundle: `<app-path>`. Workspace: `<workspace-path>`. Statically analyze the application bundle without launching it: Info.plist contracts (bundle identifier, version, URL schemes, document types, UTIs, services), code signature and entitlements, the AppleScript dictionary (sdef) with every command classified READ or MUTATING, localized strings catalogs, embedded frameworks/extensions/XPC services. Read-only — never launch or modify the app. Write raw findings to `workspace/raw/macos/bundle/` and contract summaries to `workspace/public/contracts/macos-plist-contracts.md`, `macos-sdef.md`, `macos-entitlements.md`. Every claim carries a provenance citation (source=machine-readable-contract for plist/sdef/entitlement declarations; source=bundle-analysis for strings/resource inventories)."
- Commit: `[L1:bundle-inspector] Static bundle analysis: Info.plist, entitlements, sdef, strings`

Note: the bundle's main executable (`Contents/MacOS/<exe>`) is covered by the existing `binary` source type via `workspace/raw/macos/bundle/binary-handoff.md`.

### Runtime Environment Gate (macos-runtime, app-data)

This gate runs in the ORCHESTRATOR — subagents cannot AskUserQuestion. It fires only if the negotiated inventory approved `macos-runtime` and/or `app-data`. If both were excluded (e.g. `--exclude macos-runtime,app-data`, or the user excluded them during inventory negotiation), skip this gate entirely — no environment question, no preflight.

**Step 1: Environment availability.** Read discovery's `## macOS Runtime Environments` table from `workspace/inventory.md`, then re-probe cheaply per the **macos-vm-execution skill** Host Requirements & Availability Detection: architecture (`uname -m`), `tart`/`lume` presence (and the Lume API daemon), disk headroom, and the running-guest count against the 2-guest ceiling. Build the option list from what is actually available. A backend that is unavailable (x86_64 host — which is where a `--macos-env vm-*` pre-selection is rejected — an absent binary, the 2-guest ceiling hit, or low disk) is shown in the option list WITH its reason, never silently dropped.

**Step 2: Signature verdict.** Read the verdict from `workspace/raw/macos/bundle/signing.md`, or treat it as `none` if the file does not exist (e.g. `--exclude macos-bundle` was passed, or the bundle-inspector produced no output). Carry the verdict (or `none`) into the environment artifact. FAIL/missing handling differs by environment — see Steps 3 and 4.

**Step 3: Ask.** Use the **AskUserQuestion** tool. Options: **Tart VM** / **Lume VM** / **Host (this Mac, read+write)** / **None (static only)** — unavailable backends carry the reason from Step 1. Disclose:
- The app at `<app-path>` is installed and driven with full READ+WRITE in the chosen environment.
- VM options are disposable (~25–50 GB plus a first-run image pull) and destroyed after the run.
- The app may need a trial sign-in performed by the user inside the VM (over VNC); credentials never enter the workspace.
- Workspace artifacts will contain whatever data the analysis creates in that environment; these stay in the analysis workspace and are subject to Layer 5 sanitization before any output specs.
- `none` = static-only: the pipeline continues with host-side static analysis alone.

If `--macos-env` was passed and that environment is available, skip this question and record the flag as the decision source — EXCEPT `host-direct`, which ALWAYS asks Step 4.

**Signature policy.** For `vm-tart`/`vm-lume`, a FAIL or missing signature verdict is recorded and the run PROCEEDS — a bad signature in a disposable VM costs a VM, nothing more. For `host-direct`, a FAIL or missing verdict is a HARD REFUSAL: mark `macos-runtime` and `app-data` as `excluded (unsigned target under host-direct)` in `workspace/inventory.md` and skip to the Layer 1 Gate Check.

**Step 4: Host-direct confirmation (host-direct only).** A SECOND AskUserQuestion, carrying VERBATIM the loud warning from the macos-vm-execution skill's host-direct section, the manual `sudo sysadminctl -addUser … / -deleteUser … -secure` advice, and the explicit statement that **the plugin performs no account automation and no detection heuristics** — the user's affirmation is the only signal this mode is safe. Options: **I affirm this is a disposable account — proceed** / **Choose a different environment** / **Cancel (static only)**. Only the affirmative writes the `**Disposable-account affirmation:**` line into the environment artifact; **Choose a different environment** returns to Step 3; **Cancel** proceeds with `none`.

**Step 5: Provision.** For `vm-tart`/`vm-lume`, provision per the macos-vm-execution skill: pull the base image if absent, clone (APFS CoW), boot headless + VNC on loopback, wait for the guest IP and SSH, provision TCC grants, and acquire the target (copy the host bundle, or vendor-download inside the guest). When the executed binary differs from the host build (Path B, or a version/signing mismatch), trigger the in-environment `macos-bundle` + `binary-analysis` re-run and record `workspace/raw/macos/bundle/environment-diff.md`. For `host-direct`, there is nothing to provision. Provisioning failure → retry once; if it still fails, re-ask Step 3 with that backend marked unavailable. If narrowing ends at `none`, fall through to Step 7 with `none`.

**Step 6: Record.** Write `workspace/environment/runtime-environment.md` in the macos-vm-execution skill's exact format (the bold labels are a contract — do not rename them). Export the runtime variables `GF_ENV`, `GF_VM`, `GF_SSH`, `GF_GUEST_WORKSPACE` for every subsequent runtime dispatch. Update `workspace.json.runtime_environment`. Annotate the inventory: types the gate excluded are marked `excluded (environment: none)` — mechanically identical to `--exclude`.

Commit: `[L1:env] Runtime environment: <environment>`

**Step 7: Preflight doctor.** Runs AFTER the environment is recorded and provisioned — the probes themselves trigger/verify TCC in the chosen environment. Run EACH probe THROUGH `gf_exec`/`gf_gui` in the chosen environment (never on the host), per the macos-vm-execution skill's execution convention:

- **app-present** (`gf_exec`): the target is installed in the environment.
- **GUI-session attachment**: compare `gf_exec 'osascript -e "tell app \"System Events\" to count processes"'` against `gf_gui` of the same command. A `gf_exec` result that is empty or wrong while `gf_gui` answers confirms the Aqua session is reachable only through `gf_gui` (a bare SSH `osascript` returns an empty tree and exits 0 — the skill's dominant failure mode).
- **Automation** (`gf_gui` osascript): `tell application id "<bundle-id>" to get name` — error `-1743` = denied, `-1728` = app in another session.
- **Accessibility** (`gf_gui`): `tell application "System Events" to return UI elements enabled`.
- **Screen Recording** (`gf_gui`, two-shot silent-failure): `screencapture` with the app frontmost, then hidden; near-identical file sizes = wallpaper-only silent failure. DROP the "restore previously frontmost app" dance for VMs (the guest has no user session to disturb); KEEP it for `host-direct`. Keep BOTH capture sizes — the Layer 1 gate re-reads this pair.
- **Window enumeration** (`gf_gui`): build the `gf_windows` helper per the **macos-vm-execution skill** if it is not already present, confirm `gf-windowlist --version` prints its stamp, and confirm the list has rows with populated geometry. Compile with `gf_exec`, RUN with `gf_gui` — run through `gf_exec` on a guest whose SSH session is not attached to the Aqua session and the list comes back header-only with exit 0, which is the convention's signature failure wearing a new hat. Blank titles with populated geometry is a Screen Recording attribution failure, not a broken enumerator.
- **Window-id capture probe** (`gf_gui`): take the first layer-0 row owned by the target and run `screencapture -x -o -l <id>`. This proves the run's DEFAULT capture mode works before any evidence depends on it. A failure here degrades capture scope to `rect-fallback`, where occlusion is no longer excluded from any frame.
- **Data-store readability** (`gf_exec`): `ls` the group container and open the store read-only with `sqlite3 "file:$DB?mode=ro" ".tables"`. This is a one-shot readability check; it stays `mode=ro` (like every store read in `app-data-inspection`) so it cannot perturb the live WAL that the `data-inspector` agent is about to measure. State changes still go through the app's surfaces, never a direct store write.

Produce a capability matrix (granted | missing per capability) and append it as `## Runtime Environment Preflight` to `workspace/inventory.md`.

For each missing capability, AskUserQuestion with options: `[Re-run TCC provisioning]` / `[I granted it over VNC — re-check]` / `[Skip this capability]` / `[Cancel and fall back to static-only]`. Maximum 3 re-check rounds, then auto-degrade. Degradation matrix:
- No Automation → drop applescript-explorer
- No Accessibility → ui-observer degrades to screenshots-only (no menu traversal or AX sidecars, per macos-visual-exploration's degradation modes); drop ui-observer entirely only when BOTH Accessibility and Screen Recording are missing
- No Screen Recording → ui-observer runs AX-only (no screenshots)
- No window enumeration (or the window-id capture probe fails) → ui-observer keeps capturing but drops to `rect-fallback` capture scope; every frame and every claim citing one is stamped `rect (occlusion not excluded)`. This is a SECOND, independent axis from the degradation mode — record it as `**Capture scope:** rect-fallback` beside the mode, not instead of it
- No data access → data-inspector proceeds defaults-only if the preference domain is readable, else exclude app-data
- VM unreachable mid-run → exclude BOTH `macos-runtime` and `app-data`

Commit: `[L1:preflight] Runtime environment preflight doctor`

### Source: macos-runtime (Runtime Environment Observation)

Requires a recorded environment other than `none` and the doctor's capability rows.

**ENVIRONMENT EXECUTION:** every target-facing command runs through the exec convention in the **macos-vm-execution skill** — `gf_exec` for non-GUI work, `gf_gui` for anything touching the window server, `gf_get`/`gf_put` for artifact transfer. The two macos-runtime agents dispatch SEQUENTIALLY (a single Aqua session per environment — two agents cannot share it), never in the same parallel batch, and never in a batch with any other agent that drives the UI.

**Step 1: applescript-explorer** → `greenfield:analyzer`:
- Prompt: "Role: applescript-explorer. Follow the **macos-runtime-observation skill**. Target app: `<app-name>` (bundle id `<bundle-id>`, path `<app-path>`). Environment: `<vm-tart|vm-lume|host-direct>`. VM: `<name>`. SSH target: `<user@ip>`. Guest workspace: `<path>`. Workspace: `<workspace-path>`. Preflight capability matrix: `<matrix>`. Follow the macos-vm-execution skill for the exec convention — run every target-facing command through gf_exec/gf_gui; verify `workspace/environment/runtime-environment.md` before starting. Using the capability inventory and sdef classification in `workspace/raw/macos/bundle/`, query and exercise live application state via osascript/JXA with full read+write: enumerate scriptable classes, read live object graphs, drive create/set/delete verbs to reveal behavior, and map the object model to user-visible concepts. Record OBS-NNN records with provenance citations (source=runtime-observation). Additionally write `workspace/raw/macos/runtime/scripting/navigation-surfaces.md`: every scripting-reachable way to arrive at a UI state without clicking — sdef `select`/`reveal`/`show`/`open`/`activate` verbs, settable window and view properties, and any registered URL scheme command — each with its exact invocation and the state it lands on. ui-observer runs after you and reads this file as the alternate-surface rung of its interaction ladder: a custom-drawn view that no synthetic click can reach is often reachable by one line of script, and arriving that way is a FULL capture of the state, not a degraded one. Retrieve every artifact with gf_get before returning (the Layer 1 gate counts files on the host). Write to `workspace/raw/macos/runtime/observations/` and `scripting/`."
- Commit: `[L1:applescript-explorer] Query live object model via scripting interface`

**Step 2: ui-observer** (after Step 1 completes) → `greenfield:analyzer`:
- Prompt: "Role: ui-observer. Follow the **macos-visual-exploration skill**. Target app: `<app-name>` (`<app-path>`). Environment: `<vm-tart|vm-lume|host-direct>`. VM: `<name>`. SSH target: `<user@ip>`. Guest workspace: `<path>`. Workspace: `<workspace-path>`. Preflight capability matrix: `<matrix>`. Follow the macos-vm-execution skill for the exec convention — run every target-facing command through gf_exec/gf_gui; verify `workspace/environment/runtime-environment.md` before starting. Explore via System Events accessibility scripting with full read+write: enumerate windows, the full menu bar (every item with keyboard shortcut, enabled state, and mutation class), navigate the primary screens, and exercise UI flows including mutating actions. If Screen Recording is granted, capture each distinct UI state with screencapture to `workspace/raw/macos/runtime/screenshots/` with an .ax.md accessibility sidecar per capture; otherwise document from the accessibility tree alone. Record write/mutation probes under `workspace/raw/macos/runtime/mutations/`. Also: (1) CAPTURE SCOPE — captures are window-scoped by default, `screencapture -x -o -l <window id>` with the id resolved from a FRESH `gf_windows` list immediately before every shutter; full-screen is a declared exception for screen-level subjects only (menu bar, Dock, multi-window arrangement, desktop-level behavior, notification presentation itself) and each one carries a written justification in the manifest; `-R` rect capture is last resort only when enumeration is unavailable, and every rect frame and every claim citing one is stamped `rect (occlusion not excluded)`. (2) INTENT DECLARATION — every capture declares its stem, subject, and 1-3 expected predicates BEFORE the shutter, and the predicates are re-queried against the AX sidecar after; on mismatch retry once, then reject the file to `screenshots/rejected/` with a NUL-NNN manifest row and write the mismatch up as a behavioral observation. NEVER rename a capture to match what it turned out to show. (3) NOTIFICATIONS — capture them as evidence with sequential NTF-NNN records in `notifications.md`, then dismiss them by the skill's verified ladder. Suppression is FORBIDDEN: Do Not Disturb, Focus, and unloading the notification agent all delete behavior that is under analysis. (4) COVERAGE FREEZE — write `state-coverage.md` at the end of Phase 3 with every row NOT-ATTEMPTED and gf_get it to the host BEFORE any Phase 4 interaction, then resolve every row to CAPTURED (with an evidence path), UNREACHABLE (with the mechanism that prevents it), or BLOCKED (naming the ladder rungs tried). The denominator only grows — statuses change, rows never disappear, and zero NOT-ATTEMPTED rows may remain at the end. (5) INTERACTION LADDER — drive the UI by the skill's fixed five-rung ladder (R1 menu command, R2 keyboard, R3 AX action, R4 AX selection on the container, R5 AX-derived coordinate click), two attempts per rung, descend exactly once, never revisit; read `scripting/navigation-surfaces.md` from the applescript-explorer for alternate surfaces before declaring a state unreachable; log every attempt beyond the first working rung to `interaction-log.md` with before/after AX fingerprints. Retrieve every artifact with gf_get before returning (the Layer 1 gate counts files on the host). REQUIRED DELIVERABLES under `workspace/raw/macos/runtime/` (source=visual-observation), all of them, none optional: `preflight-visual.md` (declaring `**Degradation mode:**` and `**Capture scope:**`), `command-surface.md` with sequential CMD-NNN records, `window-inventory.md`, `state-coverage.md` with sequential ST-NNN rows, `ax-affordance-map.md` with AXA-NNN rows, `interaction-log.md`, `notifications.md`, `visual-behaviors.md`, `screenshot-manifest.md`, `flows/view-navigation/flow.md` plus a flow directory for every Required flow in the skill's Phase 4.1 table, and one `menu-NNN-<menu>.png` per top-level menu AND per submenu-bearing item. The skill's Definition of Done is the contract — it has no "at least one" floors and neither does this prompt."
- Commit: `[L1:ui-observer] Observe UI structure, menus, and screens in the runtime environment`

### Source: app-data (App Data Inspection)

Requires a recorded environment other than `none` and the doctor's data-access capability.

Dispatch `greenfield:analyzer`:
- Prompt: "Role: data-inspector. Follow the **app-data-inspection skill**. Target bundle id: `<bundle-id>`. Data locations (from inventory/entitlements): `<paths>`. Environment: `<vm-tart|vm-lume|host-direct>`. VM: `<name>`. SSH target: `<user@ip>`. Guest workspace: `<path>`. Workspace: `<workspace-path>`. Follow the macos-vm-execution skill for the exec convention — run every target-facing command through gf_exec/gf_gui; verify `workspace/environment/runtime-environment.md` before starting. Locate the app's data stores (group containers, Application Support, defaults domain). Read+write: capture a baseline under `workspace/raw/macos/app-data/baseline/`, open SQLite and extract the full schema, infer entities/lifecycles/relationships, drive mutations through the app and diff the stores into `workspace/raw/macos/app-data/mutation-diffs/`, and sample structural values (type codes, status flags). Read preferences via `defaults read`. Record DBQ-NNN records with provenance citations (source=app-data-observation). Retrieve every artifact with gf_get before returning (the Layer 1 gate counts files on the host). Write to `workspace/raw/macos/app-data/`."
- Commit: `[L1:data-inspector] Data store schema, lifecycle inference, and mutation diffs`

**Artifact retrieval.** For `vm-tart`/`vm-lume`, each agent MUST `gf_get` its output into `workspace/raw/macos/...` on the host before returning — evidence left in the guest does not exist as far as the Layer 1 gate is concerned.

### Layer 1 Gate Check (ENFORCED)

Verify each approved source type from the inventory produced output.

**Why this gate is more than a file count.** A non-empty file count is necessary and not sufficient. `find | wc -l` fails only at zero, and zero is not the failure that actually happens. A directory full of wallpaper PNGs passes it. A lone `preflight-visual.md` sitting where eleven deliverables belong passes it. Both of those are runs that never looked at the app, and both of them sail into Layer 2 where nothing downstream can collect evidence any more. So the gate runs in tiers: every approved source type gets the zero-file check; the types with a known deliverable list get their named artifacts checked for existence and non-emptiness; and `macos-runtime` — the one source type no later layer can re-collect — additionally gets evidence-shaped checks that ask whether the files say anything.

```bash
GATE_FAIL=0

# The orchestrator sets APPROVED_SOURCES from the inventory before running this gate,
# e.g. APPROVED_SOURCES="macos-bundle macos-runtime app-data docs". Every tier below is
# guarded by it: a target with no macOS bundle must never fail a check for artifacts
# nobody was asked to produce.
is_approved() { case " $APPROVED_SOURCES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# An unset variable would make every check below vacuous and still print PASSED, which is
# the exact failure mode this gate exists to eliminate. Refuse to run instead.
if [ -z "${APPROVED_SOURCES:-}" ]; then
  echo "LAYER 1 GATE FAILED: APPROVED_SOURCES is unset -- the gate cannot tell what was approved"
  exit 1
fi
if [ -z "${DISPATCHED_L1_ROLES:-}" ]; then
  echo "LAYER 1 GATE FAILED: DISPATCHED_L1_ROLES is unset -- dispatch records cannot be verified"
  exit 1
fi

# Read inventory.md to get list of approved source types
# For each approved source type, verify its output directory contains files

# --- Tier 1: zero-file check (every approved source type) ---------------

check_output() {
  local source_type="$1"
  local output_dir="$2"
  local file_count
  # tools/ holds binaries the agent compiled for itself, not evidence about the target --
  # a run that produced only its own tooling has produced nothing.
  file_count=$(find "$output_dir" -type f ! -name '.gitkeep' -not -path '*/tools/*' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$file_count" -eq 0 ]; then
    echo "LAYER 1 GATE FAILED: $source_type produced 0 files in $output_dir"
    GATE_FAIL=1
  else
    echo "$source_type: $file_count files"
  fi
}

# Check each approved source against its expected output location:
# source    → workspace/raw/source/analysis/
# docs      → workspace/public/docs/
# community → workspace/public/community/
# sdk       → workspace/public/ecosystem/
# runtime   → workspace/raw/runtime/
# binary    → workspace/raw/binary/survey/
# git-history → workspace/raw/project-history/
# tests     → workspace/raw/test-evidence/
# visual    → workspace/raw/runtime/visual/
# contracts → workspace/public/contracts/
# macos-bundle  → workspace/raw/macos/bundle/
# macos-runtime → workspace/raw/macos/runtime/
# app-data      → workspace/raw/macos/app-data/

# Types the Runtime Environment Gate marked excluded (environment: none/unavailable,
# or unsigned under host-direct) are excluded types; the "for each approved source type"
# loop already skips them.

# --- Tier 2: named artifacts (the source types that have a fixed list) --

require_files() {
  # require_files <source_type> <dir> <file> [<file> ...]
  # Named artifact must exist AND be non-empty. An empty file is a stub, not a deliverable.
  # Silently skips a source type this run did not approve -- a target with no macOS
  # bundle must not fail a check for artifacts nobody was asked to produce.
  local source_type="$1" dir="$2" f
  shift 2
  is_approved "$source_type" || return 0
  for f in "$@"; do
    if [ ! -s "$dir/$f" ]; then
      echo "LAYER 1 GATE FAILED: $source_type missing or empty: $dir/$f"
      GATE_FAIL=1
    fi
  done
}

require_glob() {
  # require_glob <source_type> <description> <dir> <name-pattern>
  # At least one non-empty file matching <name-pattern> anywhere under <dir>.
  local source_type="$1" desc="$2" dir="$3" pattern="$4" hits
  is_approved "$source_type" || return 0
  hits=$(find "$dir" -type f -size +0c -name "$pattern" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$hits" -eq 0 ]; then
    echo "LAYER 1 GATE FAILED: $source_type has no $desc ($pattern under $dir)"
    GATE_FAIL=1
  fi
}

# Run only the lists whose source type is approved. Types not listed here have no
# fixed deliverable set -- their shape is Gate 1b's problem, not this gate's.

# macos-bundle: eight phase outputs, one per phase of macos-bundle-analysis.
require_files macos-bundle workspace/raw/macos/bundle \
  survey.md info-plist.md signing.md scripting-dictionary.md \
  text-catalog.md components.md capability-inventory.md binary-handoff.md

# docs: the claims file is the deliverable; gaps.md is the honest half of it.
require_files docs workspace/public/docs claims/claims-by-topic.md gaps.md

# contracts: cross-contract notes plus at least one parsed contract summary.
require_files contracts workspace/public/contracts cross-contract-notes.md
require_glob contracts "contract summary" workspace/public/contracts '*-summary.md'

# app-data: the three artifacts every degradation path still produces.
# schema.md / entities.md are excused under the defaults-only degradation, so they
# are checked by the M-checks at Gate 1b rather than here.
require_files app-data workspace/raw/macos/app-data preflight-data.md defaults.md dbq-log.md

# --- Tier 2b: dispatch records ------------------------------------------
# Every Layer 1 role actually dispatched this run must have left its prompt on disk,
# with a **Scope:** line. Without it, "the instructions were narrowed" and "the agent
# underperformed" are indistinguishable after the fact. See the Dispatch record protocol.

for role in $DISPATCHED_L1_ROLES; do   # roles the orchestrator dispatched, e.g. "bundle-inspector ui-observer"
  rec="workspace/provenance/dispatch/L1-$role.md"
  if [ ! -s "$rec" ]; then
    echo "LAYER 1 GATE FAILED: no dispatch record for Layer 1 role '$role' ($rec)"
    GATE_FAIL=1
  elif ! grep -q '^\*\*Scope:\*\*' "$rec"; then
    echo "LAYER 1 GATE FAILED: dispatch record $rec has no **Scope:** line"
    GATE_FAIL=1
  fi
done

# --- Tier 3: macos-runtime evidence shape -------------------------------
# This block runs ONLY when macos-runtime was approved. macos-runtime is only ever
# approved after the Runtime Environment Gate recorded an environment, which means the
# orchestrator is on macOS -- so BSD `stat -f%z` is the correct size call here and needs
# no GNU fallback. On any other platform this block never executes.

if ! is_approved macos-runtime; then
  echo "macos-runtime: not approved this run — Tier 3 skipped"
else
  RT=workspace/raw/macos/runtime
  PF="$RT/preflight-visual.md"
  MODE=missing-preflight

  if [ ! -s "$PF" ]; then
    echo "LAYER 1 GATE FAILED: macos-runtime has no preflight-visual.md -- the degradation mode is unknown, so no other check can be judged"
    GATE_FAIL=1
  else
    MODE=$(grep -m1 '\*\*Degradation mode:\*\*' "$PF" | sed 's/.*\*\*Degradation mode:\*\*//' | tr -d ' \r')

    # The capture-scope axis is independent of the mode and decides whether every capture in
    # this run carries the occlusion caveat. M7 reads it too; an unset value means the run
    # never established which capture path it was on.
    SCOPE=$(grep -m1 '\*\*Capture scope:\*\*' "$PF" | sed 's/.*\*\*Capture scope:\*\*//' | tr -d ' \r')
    case "$SCOPE" in
      window-id) ;;
      rect-fallback)
        echo "macos-runtime: capture scope 'rect-fallback' -- every capture is a display crop; occlusion caveat required on claims citing them"
        ;;
      *)
        echo "LAYER 1 GATE FAILED: preflight-visual.md declares no recognized **Capture scope:** (got '$SCOPE'; expected window-id or rect-fallback)"
        GATE_FAIL=1
        ;;
    esac
  fi

  case "$MODE" in

    missing-preflight)
      # Already reported above; nothing else in this block can be judged without the mode.
      ;;

    abort)
      # Both capabilities failed, or an environment gate fired. preflight-visual.md IS the
      # deliverable and the gates are the finding. Do not fail a run for correctly refusing
      # to fabricate evidence it could not collect.
      echo "macos-runtime: degradation mode 'abort' -- preflight-visual.md is the deliverable; evidence checks skipped"
      ;;

    screenshots-only)
      # Accessibility failed, so there is no AX layer to enumerate from: no menu walk, no
      # CMD-NNN, no window inventory, no affordance map, no ladder fingerprints, and no
      # coverage denominator built out of any of them. Screenshots and the manifest are the
      # deliverables. Checks 3.2-3.6 are unsatisfiable by construction and are skipped --
      # failing them would punish a correctly degraded run.
      require_files macos-runtime "$RT" \
        preflight.md preflight-visual.md visual-behaviors.md screenshot-manifest.md notifications.md
      echo "macos-runtime: degradation mode 'screenshots-only' -- AX-derived checks skipped; screenshot checks below still apply"
      ;;

    both|AX-only)

      # 3.1 Mandated deliverables.
      require_files macos-runtime "$RT" \
        preflight.md preflight-visual.md command-surface.md window-inventory.md \
        state-coverage.md ax-affordance-map.md interaction-log.md \
        visual-behaviors.md screenshot-manifest.md notifications.md
      require_glob macos-runtime "flow document" "$RT/flows" 'flow.md'
      require_glob macos-runtime "scripting observation" "$RT/observations" '*.md'

      # 3.2 The command surface has records, not just prose.
      cmd_ids=$(grep -oE 'CMD-[0-9]{3}' "$RT/command-surface.md" 2>/dev/null | sort -u | wc -l | tr -d ' ')
      if [ "$cmd_ids" -eq 0 ]; then
        echo "LAYER 1 GATE FAILED: command-surface.md has 0 CMD-NNN records -- CMD-NNN is the join key for M1/M2/M7"
        GATE_FAIL=1
      else
        echo "macos-runtime: $cmd_ids CMD-NNN records"
      fi

      # 3.3 The frozen denominator adds up. Declared header count vs recomputed rows.
      st_rows=$(grep -E '^[|[:space:]]*ST-[0-9]{3}' "$RT/state-coverage.md" 2>/dev/null || true)
      row_count=$(printf '%s\n' "$st_rows" | grep -cE 'ST-[0-9]{3}' || true)
      declared=$(grep -m1 -oE '\*\*Enumerated:\*\*[[:space:]]*[0-9]+' "$RT/state-coverage.md" 2>/dev/null | grep -oE '[0-9]+' || true)
      if [ -z "$declared" ]; then
        echo "LAYER 1 GATE FAILED: state-coverage.md declares no **Enumerated:** count"
        GATE_FAIL=1
      elif [ "$declared" -ne "$row_count" ]; then
        echo "LAYER 1 GATE FAILED: state-coverage.md declares **Enumerated:** $declared but carries $row_count ST-NNN rows"
        GATE_FAIL=1
      fi

      # 3.4 Every ENABLED command has a coverage row. A disabled command is not a gap
      # (M7 scores it P2). Parse the Enabled COLUMN -- the table holds yes/no, so a
      # substring test for "disabled" matches nothing and would treat every disabled
      # command as enabled, failing a healthy run on Undo/Redo/Paste-at-rest.
      enabled_cmds=$(awk -F'|' '$0 ~ /CMD-[0-9]{3}/ && $5 ~ /(^|[[:space:]])yes([[:space:]]|$)/ {print $2}' \
                     "$RT/command-surface.md" 2>/dev/null | grep -oE 'CMD-[0-9]{3}' | sort -u)
      uncovered=0
      for c in $enabled_cmds; do
        if ! grep -q "$c" "$RT/state-coverage.md" 2>/dev/null; then
          echo "  uncovered enabled command: $c"
          uncovered=$((uncovered + 1))
        fi
      done
      if [ "$uncovered" -gt 0 ]; then
        echo "LAYER 1 GATE FAILED: $uncovered enabled CMD-NNN records have no state-coverage row"
        GATE_FAIL=1
      fi

      # 3.5 Nothing left NOT-ATTEMPTED. The denominator was frozen before Phase 4 precisely
      # so that every row would have to be answered one way or another.
      not_attempted=$(printf '%s\n' "$st_rows" | grep -c 'NOT-ATTEMPTED' || true)
      if [ "$not_attempted" -gt 0 ]; then
        echo "LAYER 1 GATE FAILED: $not_attempted state-coverage rows are still NOT-ATTEMPTED"
        GATE_FAIL=1
      fi

      # 3.6 Every BLOCKED row names the rungs it tried. An unfalsifiable "blocked" looks
      # exactly like diligence. 'remediation-exhausted' is the one accepted alternative,
      # written by the remediation loop below.
      bad_blocked=$(printf '%s\n' "$st_rows" | grep 'BLOCKED' | grep -cvE 'R[1-5]|remediation-exhausted' || true)
      if [ "$bad_blocked" -gt 0 ]; then
        echo "LAYER 1 GATE FAILED: $bad_blocked BLOCKED rows name no ladder rung (expected R1-R5 in the reason)"
        GATE_FAIL=1
      fi

      ;;

    *)
      echo "LAYER 1 GATE FAILED: preflight-visual.md declares no recognized **Degradation mode:** (got '$MODE'; expected both, AX-only, screenshots-only, or abort)"
      GATE_FAIL=1
      ;;
  esac

    # 3.7 Screenshot-shaped checks. Applies to `both` and `screenshots-only`; skipped under AX-only,
    # which has no PNGs by design -- failing it for having none would punish correct degradation.
    if [ "$MODE" = "AX-only" ] || [ "$MODE" = "abort" ] || [ "$MODE" = "missing-preflight" ]; then
      echo "macos-runtime: $MODE -- screenshot checks skipped by design"
    else
    [ "$MODE" = "screenshots-only" ] || require_glob macos-runtime "menu screenshot" "$RT/screenshots" 'menu-*.png'   # no AX menu walk under screenshots-only

      # Wallpaper detector 1: denied Screen Recording writes the same desktop picture
      # every time, so N captures collapse to a handful of identical byte sizes.
      shots=$(find "$RT/screenshots" -type f -name '*.png' -not -path '*/rejected/*' 2>/dev/null)
      shot_count=$(printf '%s\n' "$shots" | grep -c '\.png$' || true)
      if [ "$shot_count" -ge 3 ]; then
        distinct=$(printf '%s\n' "$shots" | xargs stat -f%z 2>/dev/null | sort -u | wc -l | tr -d ' ')
        if [ "$distinct" -le 2 ]; then
          echo "LAYER 1 GATE FAILED: $shot_count screenshots collapse to $distinct distinct file sizes -- these are wallpaper, not the app"
          GATE_FAIL=1
        fi
      fi

      # Wallpaper detector 2: the preflight two-shot pair. Frontmost and hidden must differ;
      # within 1% means the shutter never saw the app either time.
      f1="$RT/screenshots/000-preflight-frontmost.png"
      f2="$RT/screenshots/000-preflight-hidden.png"
      if [ -s "$f1" ] && [ -s "$f2" ]; then
        a=$(stat -f%z "$f1"); b=$(stat -f%z "$f2")
        delta=$((a - b)); [ "$delta" -lt 0 ] && delta=$((0 - delta))
        larger=$a; [ "$b" -gt "$a" ] && larger=$b
        if [ $((delta * 100)) -lt "$larger" ]; then
          echo "LAYER 1 GATE FAILED: preflight frontmost/hidden captures are within 1% ($a vs $b) -- Screen Recording is silently denied"
          GATE_FAIL=1
        fi
      else
        echo "NOTE: preflight frontmost/hidden pair absent on the host -- this detector is skipped; the two-shot verdict in preflight-visual.md is the only remaining wallpaper evidence"
      fi
    fi
fi

# --- Model floor: every Layer 1 dispatch ran at or above its floor ---
if ! greenfield-tiers floor workspace 1; then
  echo "LAYER 1 GATE FAILED: model floor (see the FAIL lines above and 'Floor failures' in the Agent Dispatch Protocol)"
  GATE_FAIL=1
fi

if [ "$GATE_FAIL" -eq 1 ]; then
  echo "STOP: Layer 1 gate failed. Re-dispatch failed source agents before proceeding."
  exit 1
fi
echo "LAYER 1 GATE PASSED: All approved sources produced output."
```

### Layer 1 Gate Remediation

**Read this before acting on a Tier 3 failure.** This gate is the only one in the pipeline that runs while the runtime environment is still provisioned AND the orchestrator still holds the Agent tool. Every later gate has one or the other, never both: subagents have no Agent tool, so no layer below this one can dispatch a collector; Layers 6-7 are forbidden from reading `raw/` at all; and by the time check M7 notices the same coverage hole at Gate 1b, the guest may already be gone. A coverage failure here is recoverable by re-collection. The identical failure at Gate 1b is, in practice, only downgradeable to a documented ceiling. So spend the effort here.

**Coverage failure (3.3 through 3.6) — re-dispatch the observer.**

Do NOT exit. Re-dispatch `ui-observer` against the same live environment with a narrowed prompt:

- Hand it the explicit list of unresolved `ST-NNN` ids — the actual ids, not "the gaps". A gap list the agent has to rediscover is a second exploration.
- Add this addendum verbatim in spirit: *"`state-coverage.md` is FROZEN. Do not rewrite it, do not renumber it, do not add or remove rows — the existing rows and their ids are authoritative. Resolve exactly the listed rows, and only those, to CAPTURED (with an evidence path), UNREACHABLE (naming the mechanism that prevents reaching it), or BLOCKED (naming the ladder rungs tried). Append every attempt to `interaction-log.md`. Do NOT begin new exploration, do NOT walk menus you have already walked, and do NOT open new flows."*
- Write the round-2 dispatch record to `workspace/provenance/dispatch/L1-ui-observer-2.md` with `**Round:** 2` and `**Scope:** narrowed — coverage remediation, ST-NNN gap list only`, per the Dispatch record protocol.
- Re-run the gate after the agent returns.

**Maximum 2 remediation rounds.** After the second round, any row still unresolved is written as `BLOCKED` with the reason `remediation-exhausted`, the exhaustion is recorded in `visual-behaviors.md` as a behavioral claim about the target, and the gate PASSES. This is deliberate. A documented ceiling on what this environment could be driven to do is a finding — it says the app resists automation on these surfaces, which is a real property of the app and exactly the kind of thing an implementer needs to know. An endless remediation loop is not more rigorous than that; it is the unbounded search for a working click that wasted a quarter of a previous run.

**Wallpaper failure (3.7) — never remediated by re-dispatch.**

Re-dispatching the observer here is pure waste: the agent did nothing wrong and cannot fix it. Identical file sizes mean the Screen Recording grant is missing or broken in the environment, which is a PROVISIONING defect that lives one layer below the agent. Two paths, both of them environmental:

1. **Re-provision** the base image with a working Screen Recording grant per the **macos-vm-execution skill**, then re-dispatch once against the repaired environment.
2. **Degrade to AX-only** — update `**Degradation mode:**` in `preflight-visual.md` to `AX-only` with the reason recorded, and re-dispatch once with that mode in the prompt. The run then produces AX evidence honestly instead of PNGs of a desktop picture.

Either way the mode change is recorded, not silent. Never delete the offending PNGs to clear the detector: that removes the evidence that the environment was broken while leaving every claim those frames supported still standing.

---

## Layer 2: Synthesis & Mapping

Combine raw intelligence from all Layer 1 modes into a unified structural understanding. If only one mode ran, synthesis operates in pass-through mode (still runs, but draws from a single source).

### Phase 2a: Parallel extraction

Dispatch all three in parallel:

**feature-discoverer** → `greenfield:analyzer`:
- Prompt: "Role: feature-discoverer. Follow the **multi-source-synthesis skill** Section 1 (Feature Discovery). Workspace: `<workspace-path>`. Read all Layer 1 output from `workspace/raw/source/`, `workspace/public/` (including `public/community/` if it exists), `workspace/raw/runtime/`, `workspace/raw/binary/`, `workspace/raw/macos/` (whichever exist). Aggregate a feature inventory. Write to `workspace/raw/synthesis/features/`."
- Commit: `[L2:feature-discoverer] Aggregate feature inventory from N intelligence sources`

**architecture-analyst** → `greenfield:analyzer`:
- Prompt: "Role: architecture-analyst. Follow the **multi-source-synthesis skill** Section 2 (Architecture Reverse Engineering). Workspace: `<workspace-path>`. Read all Layer 1 output. Synthesize the architecture model. Write to `workspace/raw/synthesis/architecture/`."
- Commit: `[L2:architecture-analyst] Synthesize architecture model`

**api-extractor** → `greenfield:analyzer`:
- Prompt: "Role: api-extractor. Follow the **multi-source-synthesis skill** Section 3 (API Surface Extraction). Workspace: `<workspace-path>`. Read all Layer 1 output. Extract and synthesize the API surface. Write to `workspace/raw/synthesis/api/`."
- Commit: `[L2:api-extractor] Synthesize API surface`

### Phase 2b: Cross-mode synthesis (after 2a completes)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: analysis-synthesizer. Follow the **multi-source-synthesis skill** Section 4 (Cross-Source Synthesis). Workspace: `<workspace-path>`. Read the parallel synthesis outputs in `workspace/raw/synthesis/features/`, `workspace/raw/synthesis/architecture/`, `workspace/raw/synthesis/api/`. Merge them, resolve contradictions, produce unified findings. Update files in `workspace/raw/synthesis/`."
- Commit: `[L2:analysis-synthesizer] Cross-mode synthesis complete`

### Phase 2c: Module mapping (after 2b completes)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: module-mapper. Follow the **multi-source-synthesis skill** Section 5 (Module Mapping). Workspace: `<workspace-path>`. Read the unified synthesis in `workspace/raw/synthesis/`. Identify all modules and their boundaries. Write `workspace/raw/synthesis/module-map.md`. NOTE: The module map is an analysis organizational artifact for ensuring exhaustive analysis coverage. It belongs to the analysis workspace and does not appear in the output."
- Commit: `[L2:module-mapper] Identify N modules for deep documentation`

### Layer 2 Gate Check (ENFORCED)

```bash
GATE_FAIL=0

# Feature inventory exists
feat_count=$(ls workspace/raw/synthesis/features/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$feat_count" -eq 0 ]; then
  echo "LAYER 2 GATE FAILED: No feature inventory files produced."
  GATE_FAIL=1
fi

# Architecture model exists
arch_count=$(ls workspace/raw/synthesis/architecture/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$arch_count" -eq 0 ]; then
  echo "LAYER 2 GATE FAILED: No architecture model files produced."
  GATE_FAIL=1
fi

# Module map exists with modules identified
if [ ! -f "workspace/raw/synthesis/module-map.md" ]; then
  echo "LAYER 2 GATE FAILED: module-map.md does not exist."
  GATE_FAIL=1
else
  module_count=$(grep -c "^### " workspace/raw/synthesis/module-map.md 2>/dev/null || echo 0)
  if [ "$module_count" -eq 0 ]; then
    echo "LAYER 2 GATE FAILED: module-map.md contains no module definitions."
    GATE_FAIL=1
  fi
  echo "Module map: $module_count modules identified"
fi

# --- Model floor: every Layer 2 dispatch ran at or above its floor ---
if ! greenfield-tiers floor workspace 2; then
  echo "LAYER 2 GATE FAILED: model floor (see the FAIL lines above and 'Floor failures' in the Agent Dispatch Protocol)"
  GATE_FAIL=1
fi

if [ "$GATE_FAIL" -eq 1 ]; then
  echo "STOP: Layer 2 gate failed. Re-dispatch synthesis agents before proceeding."
  exit 1
fi
echo "LAYER 2 GATE PASSED: Feature inventory, architecture model, and module map verified."
```

---

## Layer 3: Deep Documentation (THE CORE WORK)

### Phase 3a: Deep dive per module

**For EVERY module (P0, P1, P2, P3 — ALL of them), spawn deep-dive-analyzer:**

ANALYZE ALL MODULES - not just P0! Priority determines implementation order, NOT what to analyze.

Read the module map at `workspace/raw/synthesis/module-map.md` to get the list of modules.

For each module, dispatch `greenfield:analyzer`:
- Prompt: "Role: deep-dive-analyzer. Follow the **behavioral-spec-writing skill** "Per-Module Behavioral Specification" section for the spec template, SPEC ID format, requirement levels, State Box, and uncertainty categories. Workspace: `<workspace-path>`. Module: `<module-name>`. Read all relevant Layer 1 and Layer 2 analysis from `workspace/raw/`. Write a complete behavioral specification to `workspace/raw/specs/modules/<module-slug>.md`. Read every relevant source file exhaustively — do NOT skim."
- Dispatch P0 modules in parallel, then P1, then P2/P3
- Commit after each batch: `[L3:deep-dive-analyzer] <module-name> module spec`

Each agent:
1. READS the code in excruciating detail
2. Traces every decision tree
3. Documents every state machine
4. Covers every error condition
5. WRITES using behavioral language (no source identifiers)
6. Annotates every claim with provenance citations

**Output translation:**
- `Ab2()` -> "application entry point"
- `r0.jobId` -> "session identifier (UUID v4)"
- `Fx3 class` -> "record parsing module"

### Phase 3b: Behavioral documentation

Dispatch `greenfield:analyzer`:
- Prompt: "Role: behavior-documenter. Follow the **behavioral-spec-writing skill** "Behavior Documentation" section. Workspace: `<workspace-path>`. Read all module specs in `workspace/raw/specs/modules/` and Layer 1 output. Synthesize user-visible behaviors organized by behavioral domain. Write to `workspace/raw/specs/behavioral-docs/`."
- Commit: `[L3:behavior-documenter] Document user-visible behaviors`

### Phase 3c: User journeys

Dispatch `greenfield:analyzer`:
- Prompt: "Role: user-journey-analyzer. Follow the **behavioral-spec-writing skill** "User Journey Analysis" section. Workspace: `<workspace-path>`. Read module specs in `workspace/raw/specs/modules/` and all Layer 1 output. Document end-to-end user flows. Write to `workspace/raw/specs/journeys/`."
- Commit: `[L3:user-journey-analyzer] Document N end-to-end user flows`

Documents end-to-end flows relevant to the target. Typical categories include:
- First-run / setup experience
- Primary happy-path workflow
- Error recovery from common failure modes
- Configuration changes and their effects
- Batch or non-interactive invocation paths
- Resume or retry of an interrupted operation

Pick the journey categories that actually apply to the target; not every target has every category.

### Phase 3d: External interfaces

Dispatch `greenfield:analyzer`:
- Prompt: "Role: contract-extractor. Follow the **behavioral-spec-writing skill** "Contract Extraction" section for external contract format, BIR table format, external system contract templates, and analysis/implementation boundary rules. Workspace: `<workspace-path>`. Read module specs in `workspace/raw/specs/modules/` and all Layer 1 output. Extract all external interfaces (CLI, env vars, config) and wire protocols (API, gRPC, LSP). **Also identify external systems the target depends on but does not own** — shared databases, third-party APIs, external CLI tools, imposed file formats. For each, produce a dedicated external system contract using the templates in the skill (database.md, api-{service}.md, cli-{tool}.md, format-{name}.md, platform-{os}.md). The test: can the reimplementor redesign this interface? If NO, it needs an external system contract. Extract inter-module integration contracts (analysis internal only — stays in raw/). Extract behavioral integration requirements (BIR table — flows through to output/). Write contracts to `workspace/raw/specs/contracts/` and protocols to `workspace/raw/specs/protocols/`."
- Commit: `[L3:contract-extractor] Extract external interfaces, wire protocols, external system contracts, and behavioral integration requirements`

Documents:
- CLI commands, flags, arguments -> `workspace/raw/specs/contracts/cli.md`
- Environment variables -> `workspace/raw/specs/contracts/environment.md`
- Config file formats -> `workspace/raw/specs/contracts/configuration.md`
- Wire protocols (API, gRPC, LSP) -> `workspace/raw/specs/protocols/`
- External database schemas -> `workspace/raw/specs/contracts/database.md`
- External API contracts -> `workspace/raw/specs/contracts/api-{service}.md`
- External CLI tool contracts -> `workspace/raw/specs/contracts/cli-{tool}.md`
- External file format contracts -> `workspace/raw/specs/contracts/format-{name}.md`
- Platform contracts (URL scheme commands and parameters, document types & UTIs, scripting dictionary, Services entries, externally-consumed preference keys — per the Platform Contract template in the behavioral-spec-writing skill) -> `workspace/raw/specs/contracts/platform-{os}.md`

### Layer 3 Gate Check (ENFORCED)

```bash
GATE_FAIL=0

# ALL modules must have specs - not just P0!
total_modules=$(grep -cP "^### " workspace/raw/synthesis/module-map.md)
spec_count=$(ls workspace/raw/specs/modules/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Modules in map: $total_modules"
echo "Specs written: $spec_count"
if [ "$spec_count" -lt "$total_modules" ]; then
  echo "LAYER 3 GATE FAILED: Missing specs for $(($total_modules - $spec_count)) modules."
  GATE_FAIL=1
fi

# Journeys must exist
journey_count=$(ls workspace/raw/specs/journeys/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$journey_count" -eq 0 ]; then
  echo "LAYER 3 GATE FAILED: No user journey specs produced."
  GATE_FAIL=1
fi
echo "Journeys: $journey_count files"

# Contracts must exist
contract_count=$(ls workspace/raw/specs/contracts/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$contract_count" -eq 0 ]; then
  echo "LAYER 3 GATE FAILED: No contract specs produced."
  GATE_FAIL=1
fi
echo "Contracts: $contract_count files"

# --- Model floor: every Layer 3 dispatch ran at or above its floor ---
if ! greenfield-tiers floor workspace 3; then
  echo "LAYER 3 GATE FAILED: model floor (see the FAIL lines above and 'Floor failures' in the Agent Dispatch Protocol)"
  GATE_FAIL=1
fi

if [ "$GATE_FAIL" -eq 1 ]; then
  echo "STOP: Layer 3 gate failed. Re-dispatch failed agents before proceeding to Gate 1."
  exit 1
fi
echo "LAYER 3 GATE PASSED: All module specs, journeys, and contracts verified."
```

**DO NOT proceed to Gate 1 until ALL modules have specs, journeys exist, and contracts exist.**

---

## Gate 1: Verification (QUALITY GATE)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: spec-verifier (Gate 1). Follow the **validation-methodology skill** for gate criteria and confidence thresholds. Process: (1) Extract all verifiable claims from every spec, grouped by topic. (2) Detect contradictions between specs. (3) Spot-check crypto, constants, field names against source code. (4) Gap analysis — could someone reimplement from these specs alone? (5) Research-derived checks #8-14. (6) Provenance verification — citation coverage per module. (7) Confidence distribution — thresholds per module. Workspace: `<workspace-path>`. Read all specs in `workspace/raw/specs/` and cross-check against source artifacts in `workspace/raw/source/`. Write verification report to `workspace/raw/specs/verification-report.md`. All 14 pass criteria must be evaluated."
- Commit: `[gate:spec-verifier] Verification report - PASS|FAIL`

The verifier:
1. Extracts all factual claims from every module spec
2. Cross-checks claims between specs for contradictions (e.g., one spec says "MD5", another says "SHA-256")
3. Spot-checks key claims against the actual source code (crypto operations, constants, field names)
4. Identifies gaps that would block reimplementation (missing test vectors, undocumented schemas, etc.)
5. **Provenance verification:** checks that every behavioral claim has a provenance citation, validates citation coverage percentage

### Gate Check

```bash
[ -f "workspace/raw/specs/verification-report.md" ] || { echo "BLOCKED: No verification report"; exit 1; }
grep -q "Status: PASS" workspace/raw/specs/verification-report.md || { echo "BLOCKED: Verification failed"; }
```

### Remediation Loop (up to 3 attempts)

```
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
  # Run spec-verifier
  # If PASS: leave the loop. The gate-1-pass tag waits for the Floor check below.
  if grep -q "Status: PASS" workspace/raw/specs/verification-report.md; then
    break
  fi

  # If FAIL: remediate
  attempt=$((attempt + 1))
  echo "Gate 1 failed (attempt $attempt/$max_attempts). Remediating..."

  # 1. Dispatch spec-remediator (see "Remediation dispatch" below). Do NOT edit specs yourself.
  # 2. Commit its output
  # 3. Re-run spec-verifier at its floor (a judge is not raised)

  if [ $attempt -ge $max_attempts ]; then
    echo "FATAL: Gate 1 failed after $max_attempts remediation attempts"
    exit 1
  fi
done
```

### Remediation dispatch

The orchestrator writes no spec text. For remediation attempt `N`, dispatch `greenfield:analyzer`:
- Prompt: "Role: spec-remediator (Gate 1). Follow the **behavioral-spec-writing skill** and the **provenance-methodology skill**. Workspace: `<workspace-path>`. Read the verification report at `workspace/raw/specs/verification-report.md`. For each finding, read the spec file and the section that the finding names, and the evidence in `workspace/raw/` that the finding cites. Correct only the sections that the report names. Do not rewrite other sections. Do not renumber SPEC IDs. Keep a provenance citation on every changed claim. Write the list of changes to `workspace/raw/specs/remediation-gate-1-round-<N>.md`."
- Model and effort: `greenfield-tiers lookup workspace spec-remediator <N-1>`
- Dispatch record: `L3-spec-remediator.md` for attempt 1, then `L3-spec-remediator-2.md` and `L3-spec-remediator-3.md`
- Commit: `[gate:spec-remediator] Gate 1 remediation round N`

### Floor check

Run this after the remediation loop ends, whether or not remediation ran. Run it before you create the pass tag.

```bash
greenfield-tiers floor workspace 3 || { echo "BLOCKED: Gate 1 model floor failed (see 'Floor failures')"; exit 1; }
```

```bash
git tag -a gate-1-pass -m "Gate 1 passed: spec-verifier"
```

**DO NOT proceed to Gate 1b until Gate 1 passes.**

---

## Gate 1b: Source-to-Spec Completeness

After Gate 1 confirms the specs are internally consistent, Gate 1b checks that the specs actually captured everything from the source. This catches tools, env vars, CLI flags, subcommands, dispatched events, and config keys that exist in the source but were never written into any spec.

Follow the **source-completeness skill** for the full methodology.

### Dispatch

Dispatch `greenfield:analyzer`:
- Prompt: "Role: source-completeness-checker. Follow the **source-completeness skill**. Workspace: `<workspace-path>`. Run all APPLICABLE checks per the skill: code-grep Checks 1-7 (tools, env vars, CLI flags, subcommands, dispatched events, config keys, error categories) by grepping the source at `<target-path>` when a source tree exists, and evidence-diff Checks M1-M7 when `workspace/raw/macos/bundle/` exists (M7 — UI state coverage — reads `workspace/raw/macos/runtime/state-coverage.md` and needs its P0s reported separately, because their remediation dispatches an observer, not a spec writer) — in both cases diffing against the specs in `workspace/raw/specs/`. Report each check PASS | FAIL | NOT-APPLICABLE; a check whose extraction surface doesn't exist reports NOT-APPLICABLE, and the gate fails if all checks are NOT-APPLICABLE. Write report to `workspace/raw/audit/source-to-spec-completeness.md`."
- Commit: `[gate-1b:source-completeness] Source-to-spec completeness check - PASS|FAIL`

### Gate Check

```bash
[ -f "workspace/raw/audit/source-to-spec-completeness.md" ] || { echo "BLOCKED: No completeness report"; exit 1; }
grep -q "Verdict: PASS" workspace/raw/audit/source-to-spec-completeness.md || { echo "BLOCKED: Source completeness FAIL"; }
```

### Remediation

If P0 gaps are found (missing user-facing tools, env vars, or CLI flags):
1. Dispatch deep-dive agents to write specs for the missing surfaces
2. Re-run the completeness check
3. Maximum 3 remediation rounds

**Coverage gaps come first, and they need an observer, not a writer.** If Check M7 reports P0 UI-state coverage gaps — unresolved `ST-NNN` rows, an enabled `CMD-NNN` with no coverage row, a missing constant row — and `workspace/environment/runtime-environment.md` plus `workspace.json.runtime_environment` still record a LIVE environment (for `vm-tart`/`vm-lume`, confirm the working VM is still up before believing the record), then re-dispatch an OBSERVER with the unresolved `ST-NNN` list BEFORE dispatching any spec writer for this round. The ordering is not a preference. A spec writer cannot conjure a screenshot; only an observer running against a running environment can close a coverage gap, and a spec round that runs first will produce prose that reads as if the gap were closed while the evidence directory is unchanged. Use the same frozen-rows addendum as the Layer 1 Gate Remediation above, and write its dispatch record under `workspace/provenance/dispatch/` with `**Scope:** narrowed — M7 coverage remediation`.

If the environment is GONE (cleanup already ran, the VM was deleted, `host-direct` session ended), do not pretend a spec round closed the gap. Downgrade each unresolved row to a documented ceiling: `BLOCKED` with the reason `environment-unavailable-at-gate-1b`, carried into `visual-behaviors.md` as a limitation of the run rather than a property of the app. A stated ceiling is auditable; a spec paragraph written over an empty evidence directory is not.

```bash
greenfield-tiers floor workspace 3 || { echo "BLOCKED: Gate 1b model floor failed (see 'Floor failures')"; exit 1; }
```

```bash
git tag -a source-completeness-pass -m "Gate 1b: Source-to-spec completeness validated"
```

**DO NOT proceed to Layer 4 until Gate 1b passes.**

---

## Layer 4: Test & Validation

### Test vectors (MANDATORY)

**This phase is NOT optional.** Without test vectors, an implementor cannot verify compatibility.

Dispatch `greenfield:analyzer`:
- Prompt: "Role: test-vector-generator. Follow the **validation-methodology skill** for quality criteria and DOD. Workspace: `<workspace-path>`. Read all specs in `workspace/raw/specs/modules/`, `workspace/raw/specs/contracts/`, `workspace/raw/specs/protocols/`. Generate concrete test vectors: CLI invocations with expected outputs, protocol request/response pairs, error conditions, state transition sequences, cryptographic known-answer-tests (if crypto involved). Write to `workspace/raw/specs/test-vectors/`. All vectors must have concrete input/output pairs and provenance citations."
- Commit: `[L4:test-vector-generator] Generate N test vectors`

### Test specifications

Dispatch `greenfield:analyzer`:
- Prompt: "Role: test-generator. Follow the **validation-methodology skill** for quality criteria and DOD. Workspace: `<workspace-path>`. Read all specs in `workspace/raw/specs/` and test vectors in `workspace/raw/specs/test-vectors/`. Generate black-box test specifications in Given/When/Then format with reference test implementations. Write to `workspace/raw/specs/tests/`. Test inputs and outputs only — no internal state testing."
- Commit: `[L4:test-generator] Generate test specifications`

### Acceptance criteria

Dispatch `greenfield:analyzer`:
- Prompt: "Role: acceptance-criteria-writer. Follow the **validation-methodology skill** for AC format (Given/When/Then), ID format (AC-{MODULE}-{NNN}), priority levels (P0-P2), and verification methods. Workspace: `<workspace-path>`. Read all specs in `workspace/raw/specs/modules/` and test vectors in `workspace/raw/specs/test-vectors/`. Write formal acceptance criteria. Write to `workspace/raw/specs/validation/acceptance-criteria/`."
- Commit: `[L4:acceptance-criteria-writer] Write acceptance criteria for N modules`

### Layer 4 Gate Check (ENFORCED)

```bash
GATE_FAIL=0

# Must have test vector files
tv_count=$(ls workspace/raw/specs/test-vectors/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$tv_count" -eq 0 ]; then
  echo "LAYER 4 GATE FAILED: No test vector files produced."
  GATE_FAIL=1
fi
echo "Test vectors: $tv_count files"

# Must have test specs
test_count=$(ls workspace/raw/specs/tests/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$test_count" -eq 0 ]; then
  echo "LAYER 4 GATE FAILED: No test specification files produced."
  GATE_FAIL=1
fi
echo "Test specs: $test_count files"

# Must have acceptance criteria
ac_count=$(find workspace/raw/specs/validation/ -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$ac_count" -eq 0 ]; then
  echo "LAYER 4 GATE FAILED: No acceptance criteria files produced."
  GATE_FAIL=1
fi
echo "Acceptance criteria: $ac_count files"

# Test vectors must contain concrete input/output pairs
if [ "$tv_count" -gt 0 ]; then
  pair_count=$(grep -c "Input\|Expected" workspace/raw/specs/test-vectors/*.md 2>/dev/null || echo 0)
  if [ "$pair_count" -eq 0 ]; then
    echo "LAYER 4 GATE FAILED: Test vectors contain no concrete input/output pairs."
    GATE_FAIL=1
  fi
  echo "Input/output pairs: $pair_count"
fi

# --- Model floor: every Layer 4 dispatch ran at or above its floor ---
if ! greenfield-tiers floor workspace 4; then
  echo "LAYER 4 GATE FAILED: model floor (see the FAIL lines above and 'Floor failures' in the Agent Dispatch Protocol)"
  GATE_FAIL=1
fi

if [ "$GATE_FAIL" -eq 1 ]; then
  echo "STOP: Layer 4 gate failed. Re-dispatch test/validation agents before proceeding to Gate 2."
  exit 1
fi
echo "LAYER 4 GATE PASSED: Test vectors, test specs, and acceptance criteria verified."
```

**DO NOT proceed to Gate 2 until test vectors and acceptance criteria exist.**

---

## Gate 2: Spec Review (QUALITY GATE)

Dispatch `greenfield:analyzer`:
- Prompt: "Role: spec-reviewer (Gate 2). Follow the **validation-methodology skill** for Gate 2 criteria and DOD. Process: (1) Check for implementation leakage — flag specific algorithms, data structures, design patterns by name, code structure descriptions. (2) Check inter-spec contradictions. (3) Check completeness — every component has docs, every behavior has tests. (4) Check clarity — flag 'usually', 'typically', 'generally'. (5) Check acceptance criteria — every module has ACs, valid format, P0 ACs have test vectors. (6) Check provenance in validation artifacts. (7) Check contamination in validation artifacts. Workspace: `<workspace-path>`. Read all specs in `workspace/raw/specs/`. Write review report to `workspace/raw/specs/review-notes.md`. Review specs ONLY — do NOT read source code. NEVER use WebSearch or WebFetch."
- Commit: `[gate:spec-reviewer] Review report - PASS|FAIL`

The reviewer checks:
1. Implementation leakage (no source code references)
2. **Contradictions between specs** (different claims about the same topic)
3. Completeness (every component has docs, every behavior has tests)
4. Clarity (no ambiguous language)
5. Acceptance criteria coverage (every module has acceptance criteria)

### Remediation Loop (up to 3 attempts)

```
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
  # Run spec-reviewer
  # If PASS: leave the loop. The gate-2-pass tag waits for the Floor check below.
  if grep -q "Status: PASS" workspace/raw/specs/review-notes.md; then
    break
  fi

  # If FAIL: remediate
  attempt=$((attempt + 1))
  echo "Gate 2 failed (attempt $attempt/$max_attempts). Remediating..."

  # 1. Dispatch spec-remediator (see "Remediation dispatch" below). Do NOT edit specs yourself.
  # 2. Commit its output
  # 3. Re-run spec-reviewer at its floor (a judge is not raised)

  if [ $attempt -ge $max_attempts ]; then
    echo "FATAL: Gate 2 failed after $max_attempts remediation attempts"
    exit 1
  fi
done
```

### Remediation dispatch

The orchestrator writes no spec text. For remediation attempt `N`, dispatch `greenfield:analyzer`:
- Prompt: "Role: spec-remediator (Gate 2). Follow the **behavioral-spec-writing skill**, the **validation-methodology skill**, and the **provenance-methodology skill**. Workspace: `<workspace-path>`. Read the review notes at `workspace/raw/specs/review-notes.md`. For each finding, read the spec file and the section that the finding names, and the evidence in `workspace/raw/` that the finding cites. Correct only the files and the sections that the notes name. Do not rewrite other sections. Do not renumber SPEC IDs. Keep a provenance citation on every changed claim. Write the list of changes to `workspace/raw/specs/remediation-gate-2-round-<N>.md`."
- Model and effort: `greenfield-tiers lookup workspace spec-remediator <N-1>`
- Dispatch record: `L4-spec-remediator.md` for attempt 1, then `L4-spec-remediator-2.md` and `L4-spec-remediator-3.md`
- Commit: `[gate:spec-remediator] Gate 2 remediation round N`

### Floor check

Run this after the remediation loop ends, whether or not remediation ran. Run it before you create the pass tag.

```bash
greenfield-tiers floor workspace 4 || { echo "BLOCKED: Gate 2 model floor failed (see 'Floor failures')"; exit 1; }
```

```bash
git tag -a gate-2-pass -m "Gate 2 passed: spec-reviewer"
```

**DO NOT proceed past Gate 2 until it passes.**

---

## Decision Point: Stop Here or Sanitize?

Layers 1–4 are complete. Gate 2 has signed off. The workspace now contains:

- Per-module behavioral specs with source provenance citations (`workspace/raw/specs/modules/`)
- User journey specs with cross-refs (`workspace/raw/specs/journeys/`)
- External and wire-protocol contracts (`workspace/raw/specs/contracts/`, `protocols/`)
- Test vectors and acceptance criteria (`workspace/raw/specs/test-vectors/`, `validation/`)
- Source-completeness verified (Gate 1b) and quality reviewed (Gate 2)

**This is already the most useful artifact for most users.** Every behavioral claim carries a `<!-- cite: source/file:L42-L58 -->` pointer back to the source. You can grep for any identifier and find where it lives.

**Layers 5–7 exist for a narrower purpose: producing specs an implementor can use without seeing the source.** They strip every source identifier, internal name, and provenance citation from the specs, rewriting them from understanding so an implementor with zero source access can rebuild the product. Typical reasons to run them:

1. The implementor cannot legally see the source (e.g., clean-room legal separation, external audit, compliance).
2. You want to rewrite from scratch with zero code-bias from the original.
3. You're handing the spec to a third party who must not learn your internals.

**Costs of running Layers 5–7:**

- Additional agent dispatches and wall-clock time.
- Output is smaller (provenance citations and internal examples are removed).
- Citation traceability is lost in `workspace/output/` — you lose the ability to grep-to-source.
- Every round of sanitization must be second-pass-reviewed (Layer 6) and fidelity-validated (Layer 7), so contamination disputes add more rounds.

### Ask the user

```
echo ""
echo "========================================================================"
echo "Layers 1–4 complete. Raw specs with full provenance are at:"
echo "  $WORKSPACE/raw/specs/"
echo ""
echo "You can stop here and use those directly, or continue to Layers 5–7 to"
echo "produce sanitized specs (implementation details stripped, provenance"
echo "removed)."
echo ""
echo "Run Layers 5–7 (sanitization + second-pass review + fidelity)?"
echo "  [y]   yes, produce sanitized specs in $WORKSPACE/output/"
echo "  [n]   no, stop here with raw specs (default)"
echo "  [?]   explain what sanitization does and when I need it"
echo "========================================================================"
```

Use the **AskUserQuestion** tool to present this choice. Include a third option for explanation if the user is unsure.

**If the user chooses `n` (default):**

```bash
git tag -a analysis-complete-raw -m "Analysis complete: raw specs with provenance (Layers 5-7 skipped by user)"
```

Skip directly to **Print Summary**. Exit 0.

**If the user chooses `y`:**

Proceed to Layer 5. Every subsequent layer runs.

**If the user chooses `?`:**

Print a longer explanation:

```
Sanitization (Layer 5) rewrites every raw spec from behavioral understanding,
producing specs that contain no source identifiers. Second-pass review (Layer 6)
then reviews the rewritten specs for residual contamination. Fidelity validation
(Layer 7) confirms no behavioral detail was lost in the rewrite.

You need this if your implementor cannot see the source (clean-room separation,
legal/compliance requirement, third-party handoff).

You do NOT need this if you have legitimate access to the source and want
comprehensive behavioral documentation — the raw specs are strictly more
informative, because they include provenance citations.

Re-ask the question.
```

Then re-invoke the AskUserQuestion with `[y]` / `[n]`.

---

## Layer 5: Sanitization

The sanitization is the most critical step in the pipeline. It MUST produce specs that contain zero source code identifiers. The sanitizer works by READING raw specs and REWRITING them from understanding — NOT by copying and cleaning.

Because specs are large, dispatch one `greenfield:sanitizer` per domain group (4-5 raw module specs → 1 output domain spec). This keeps each agent's context manageable.

For each domain group, dispatch `greenfield:sanitizer`:
- Prompt: "Role: sanitizer. Workspace: `<workspace-path>`. Follow the **spec-sanitization skill**, especially the Rewrite Rule and the External System Exception. Read these raw specs: [list of raw module spec paths]. Understand the behaviors they describe. Then WRITE a fresh output domain spec to `workspace/output/specs/domains/<domain-name>.md`. Do NOT copy text from raw specs — rewrite every sentence from your understanding. The output specs must contain ONLY: behavioral descriptions, user-facing identifiers (env vars, CLI flags, config keys, API fields, protocol constants), and numeric constants. No function names, no variable names, no minified identifiers, no internal feature flags, no telemetry event names, no source paths, no provenance citations. **Exception:** External system contracts (database schemas, third-party API fields, external CLI tool flags, imposed file formats) document systems the app does not own — preserve their details as behavioral constraints. The test: could someone read this spec with zero access to the source code and understand every word?"
- Commit: `[L5:spec-sanitizer] Rewrite <domain-name> domain spec to output/`

Start every sanitizer prompt in Layers 5, 6, and 7 with `Role: sanitizer.`

Similarly dispatch sanitizers for:
- External contracts (cli, environment, configuration, behavioral-integration) → `output/specs/contracts/`
- **External system contracts** (database, api-{service}, cli-{tool}, format-{name}, platform-{os}) → `output/specs/contracts/` — these document systems the app doesn't own. **Pass through with details intact** (table names, column names, API fields, etc. are behavioral constraints, not contamination). Apply the spec-sanitization skill's External System Exception.
- Protocol specs (rest-api, plugin-protocol, session-format, ipc-messaging) → `output/specs/contracts/`
- Journey specs → `output/specs/journeys/`
- Test vectors → `output/test-vectors/`
- Acceptance criteria → `output/validation/acceptance-criteria/`
- Public artifacts → `output/public/` (copy as-is, these are already clean of source content)

Do NOT copy `inter-module.md` or `module-map.md` to output/.

Write sanitization report to `workspace/output/sanitization-report.md` — this report lives in output/ so the implementer reads it. Include ONLY: file inventory, domain descriptions, and implementation guidance. No source module names, raw paths, or descriptions of what was sanitized.

### Contamination Check (ENFORCED)

After all sanitizers complete, run LLM judge verification. Batch the output specs files into groups of 4-5 and dispatch one `greenfield:analyzer` per batch as a contamination-judge.

For each batch, dispatch `greenfield:analyzer`:
- Prompt: "Role: contamination-judge (Layer 5 verification). Follow the **spec-sanitization skill**, specifically the reimplementor test. Workspace: `<workspace-path>`. Read these output specs end-to-end: [list of 4-5 files from `workspace/output/specs/`]. For every identifier, name, path, or reference in each file, apply the reimplementor test: would someone with zero access to the source code understand this term? External contract files (database.md, api-*.md, cli-*.md, format-*.md, platform-*.md) document systems the app doesn't own — their contents are behavioral constraints, not contamination. Produce a structured verdict for each file: PASS or FAIL with specific findings. Write verdicts to `workspace/raw/audit/contamination-judge-batch-N.md`."
- Dispatch all batches in parallel
- Commit: `[L5:contamination-judge] Contamination verification batch N`

```bash
# Check all judge verdicts
FAIL=0
for verdict in workspace/raw/audit/contamination-judge-batch-*.md; do
  if grep -qi "FAIL" "$verdict" 2>/dev/null; then
    echo "LAYER 5 CONTAMINATION CHECK: FAIL in $verdict"
    FAIL=1
  fi
done

if [ "$FAIL" -eq 1 ]; then
  echo "LAYER 5 CONTAMINATION CHECK FAILED."
  echo "Re-dispatching sanitizers for affected files..."
  # Re-sanitize files that received FAIL verdicts, then re-run judges
  exit 1
else
  echo "LAYER 5 PASSED: All contamination judges returned PASS."
fi
```

```bash
greenfield-tiers floor workspace 5 || { echo "BLOCKED: Layer 5 model floor failed (see 'Floor failures')"; exit 1; }
```

Tag sanitization complete:
```bash
git tag -a specs-ready -m "Layer 5: All raw specs sanitized to output/"
```

---

## Layer 6: Second-Pass Review

**DO NOT proceed to implementation until Layer 6 passes.**

Layer 6 is an independent review of `workspace/output/`. Three parallel agents audit the sanitized output for structural leakage, content contamination, and behavioral completeness. They read ONLY from `workspace/output/` — never from `workspace/raw/` or source code.

### Phase 1: Semantic Review (3 parallel specialist agents)

Dispatch all three in parallel:

**structural-leakage-reviewer** → `greenfield:analyzer`:
- Prompt: "Role: structural-leakage-reviewer (Layer 6 Audit). Follow the **second-pass-review skill** structural-leakage-reviewer section. Workspace: `<workspace-path>`. Read ONLY from `workspace/output/specs/`. Apply LLM-based semantic review for all 8 structural leakage categories (SL-1 through SL-8): module names in headers, Part N: headers, module counts, cross-module sections, module IDs, interface consumption tables, domain-to-module mappings, raw paths. For each finding, apply contextual judgment — would an implementor encounter this structure without seeing the source? Write detailed report to `workspace/raw/audit/structural-leakage.md`. Write summary (PASS/FAIL only, no remediation details, no file names, no examples of what was found) to `workspace/output/audit/structural-summary.md`. Do NOT read `workspace/raw/` for any reason."
- Commit: `[L6:structural-leakage-reviewer] Structural audit - PASS|FAIL`

**content-contamination-reviewer** → `greenfield:analyzer`:
- Prompt: "Role: content-contamination-reviewer (Layer 6 Audit). Follow the **second-pass-review skill** content-contamination-reviewer section. Workspace: `<workspace-path>`. Read ONLY from `workspace/output/specs/`. Apply LLM-based semantic review for all 12 content contamination categories (CC-1 through CC-12): minified IDs, line numbers, source paths, internal function/class names, code structure language, IPC channels, store properties, feature flags, CSS classes, DB schemas, internal filenames, state selectors. Apply false positive guidance from the skill — use contextual judgment rather than pattern matching alone. Write detailed report to `workspace/raw/audit/content-contamination.md`. Write summary (PASS/FAIL only, no remediation details, no file names, no examples of what was found) to `workspace/output/audit/content-summary.md`. Do NOT read `workspace/raw/` for any reason."
- Commit: `[L6:content-contamination-reviewer] Content audit - PASS|FAIL`

**behavioral-completeness-reviewer** → `greenfield:analyzer`:
- Prompt: "Role: behavioral-completeness-reviewer (Layer 6 Audit). Follow the **second-pass-review skill** behavioral-completeness-reviewer section. Workspace: `<workspace-path>`. Read ONLY from `workspace/output/specs/`, `workspace/output/test-vectors/`, `workspace/output/validation/`. Apply LLM-based semantic review for all 9 completeness categories (BC-1 through BC-9): SPEC ID coverage, state machines, error conditions, edge cases, decision trees, AC-to-SPEC linkage, test vector coverage, constant preservation, requirement levels. Write detailed report to `workspace/raw/audit/behavioral-completeness.md`. Write summary (PASS/FAIL only) to `workspace/output/audit/completeness-summary.md`. Do NOT read `workspace/raw/` for any reason."
- Commit: `[L6:behavioral-completeness-reviewer] Completeness audit - PASS|FAIL`

### Phase 2: Deep-Read Audit

After Phase 1 completes (regardless of PASS/FAIL), dispatch deep-read auditors. These agents READ every file end-to-end and apply contextual judgment using the principle from the **second-pass-review skill**: "Would an implementor encounter this exact string without seeing the source code?"

Batch the output specs files into groups of 4-5 and dispatch one `greenfield:analyzer` per batch:

**deep-read-auditor** (one per batch) → `greenfield:analyzer`:
- Prompt: "Role: deep-read-auditor (Layer 6, Phase 2). Follow the **second-pass-review skill** Deep Contextual Audit Protocol. Workspace: `<workspace-path>`. Read these files END TO END: `workspace/output/specs/domains/<file1>.md`, `workspace/output/specs/domains/<file2>.md`, ... For every identifier, name, or reference, apply the test: would an implementor encounter this exact string without seeing the source code? If not, it is contamination. Write findings to `workspace/raw/audit/deep-read-batch-N.md`. Do NOT read `workspace/raw/`."
- Dispatch all batches in parallel
- Commit: `[L6:deep-read-auditor] Deep-read audit batch N - PASS|FAIL`

Also dispatch deep-read auditors for journeys, contracts, test vectors, and acceptance criteria (batch similarly).

### Phase 2 Gate Check

If any deep-read auditor reports FAIL, the entire Layer 6 audit is FAIL — even if all Phase 1 semantic reviews passed.

### Audit Gate Check

```bash
# All three audit summaries must exist and show PASS
mkdir -p workspace/output/audit/

for report in structural-summary content-summary completeness-summary; do
  [ -f "workspace/output/audit/${report}.md" ] || { echo "BLOCKED: Missing audit report: ${report}"; exit 1; }
  grep -qi "FAIL" "workspace/output/audit/${report}.md" && { echo "BLOCKED: Audit FAIL in ${report}"; }
done
```

### Remediation Loop (up to 3 attempts)

```
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
  # Check if all three audits passed
  all_pass=true
  for report in structural-summary content-summary completeness-summary; do
    if grep -qi "FAIL" "workspace/output/audit/${report}.md" 2>/dev/null; then
      all_pass=false
      break
    fi
  done

  # If PASS: commit and leave the loop. The review-complete tag waits for the floor check below.
  if $all_pass; then
    git add -A
    git commit -m "[L6:audit] All second-pass reviews PASS"
    break
  fi

  # Remediate
  attempt=$((attempt + 1))
  echo "Audit failed (attempt $attempt/$max_attempts). Remediating..."

  # 1. Read detailed reports from workspace/raw/audit/
  # 2. Re-sanitize affected files using greenfield:sanitizer
  #    with targeted prompts referencing specific failed categories
  #    - The prompt starts with `Role: sanitizer.`
  #    - Model and effort: `greenfield-tiers lookup workspace sanitizer <round-1>`,
  #      where <round-1> is the **Round:** value of this dispatch record minus 1
  #    - Dispatch record: `L6-sanitizer-<domain>-<n>.md`, one per agent, where <domain>
  #      is the output domain file name without `.md` and <n> is the **Round:** value.
  #      Example: `L6-sanitizer-process-lifecycle-2.md`
  # 3. Re-run all three audit agents

  if [ $attempt -ge $max_attempts ]; then
    echo "FATAL: Independent audit failed after $max_attempts remediation attempts"
    exit 1
  fi
done
```

```bash
greenfield-tiers floor workspace 6 || { echo "BLOCKED: Layer 6 model floor failed (see 'Floor failures')"; exit 1; }
```

```bash
git tag -an review-complete -m "Layer 6: Independent audit passed (semantic review + deep-read)"
```

**DO NOT proceed to Layer 7 until Layer 6 passes.**

---

## Layer 7: Fidelity Validation

After Layer 6 confirms the output specs are free of contamination, Layer 7 checks the other direction: did sanitization lose any behavioral detail?

### Dispatch: Fidelity Cross-Validators

Batch the 22 raw module specs into groups of 4-5. For each batch, dispatch `greenfield:analyzer`:
- Prompt: "Role: fidelity-validator. Follow the **fidelity-validation skill**. Workspace: `<workspace-path>`. Read these raw specs: [list]. Read the corresponding output domain spec: [list]. For each behavioral claim in the raw specs (numeric constants, error conditions, decision branches, state transitions, features), verify it appears in the output spec with equal precision. Write findings to `workspace/raw/audit/fidelity-batch-N.md` using Status: MATCH | WEAKENED | MISSING | CHANGED."
- Dispatch all batches in parallel
- Commit: `[L7:fidelity-validator] Fidelity check batch N`

### Fidelity Gate Check

```bash
# Check for P0 issues (critical path behaviors that were lost or weakened)
for report in workspace/raw/audit/fidelity-batch-*.md; do
  p0_issues=$(grep -c 'P0-CRITICAL\|P0-WEAKENED' "$report" 2>/dev/null || echo 0)
  [ "$p0_issues" -gt 0 ] && echo "BLOCKED: P0 fidelity issues in $report"
done
```

### Remediation

If any P0 behaviors were lost or weakened:
1. Read the fidelity report to identify exactly what was lost
2. Dispatch `greenfield:sanitizer` to restore the missing detail — the sanitizer reads the fidelity report and the raw specs, then updates the output spec to include the missing behavioral claim WITHOUT reintroducing source identifiers
   - The prompt starts with `Role: sanitizer.`
   - Model and effort: `greenfield-tiers lookup workspace sanitizer <round-1>`, where `<round-1>` is the `**Round:**` value of this dispatch record minus 1
   - Dispatch record: `L7-sanitizer-<domain>-<n>.md`, one per agent, where `<domain>` is the output domain file name without `.md` and `<n>` is the `**Round:**` value. Example: `L7-sanitizer-process-lifecycle-2.md`
3. Re-run the fidelity validator on affected files
4. Also re-run the Layer 6 deep-read audit on any modified files to confirm no contamination was reintroduced
   - Dispatch record: `L7-deep-read-auditor-<batch>-<n>.md`, one per agent, where `<batch>` is the batch number of its findings file and `<n>` is the remediation round
   - Model and effort: `greenfield-tiers lookup workspace deep-read-auditor` with no steps. A judge is not raised.
5. Maximum 3 remediation rounds

### Fidelity Pass

```bash
greenfield-tiers floor workspace 7 || { echo "BLOCKED: Layer 7 model floor failed (see 'Floor failures')"; exit 1; }
```

```bash
git add -A
git commit -m "[L7:fidelity] Fidelity validation PASS"
git tag -a fidelity-check-complete -m "Layer 7: Fidelity validation passed — all P0 behaviors preserved"
```

**DO NOT proceed to implementation until Layer 7 passes.**

---

## Environment Cleanup

Runs at pipeline end AND on every abort path.

**NOT before Gate 1b completes.** The runtime environment stays up through Gate 1b, even though the last agent that touched it finished back in Layer 1. Check M7 can report coverage gaps that only an observer against a running environment can close, and Gate 1b's remediation depends on that environment still existing. Tearing it down after Layer 1 — or opportunistically at any point in Layers 2-3 to reclaim disk — converts every recoverable M7 finding into a documented ceiling. On an abort path the environment is torn down immediately, because there is no Gate 1b left to serve.

If runtime (container) mode was active, stop and remove the target container:

```bash
# Stop and remove container
docker rm -f <container-name> 2>/dev/null || podman rm -f <container-name> 2>/dev/null || true
```

If the runtime environment was a VM (`vm-tart`/`vm-lume`), stop then delete the working VM per the **macos-vm-execution skill**, keeping the provisioned base image (reclaim leftover space with `tart prune` / `lume prune`):

```bash
# vm-tart (vm-lume: substitute lume). Honors --keep-vm.
if [ -z "$KEEP_VM" ]; then
  tart stop "$GF_VM" 2>/dev/null || true
  tart delete "$GF_VM" 2>/dev/null || true
else
  echo "Kept VM per --keep-vm. Delete it with:  tart delete $GF_VM"
fi
```

`host-direct` has no cleanup beyond the user deleting their own disposable account — the plugin does nothing. When `--keep-vm` is set, the working VM is left in place and the exact `tart delete <name>` reclaim command is printed in the run summary.

---

## Session JSONL Capture Protocol

After EVERY agent dispatch completes, the Agent tool returns an `agentId`. Use this to capture the session log:

```bash
# A subagent log is at <claude-dir>/projects/<project>/<session-id>/subagents/agent-<agentId>.jsonl
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SESSION_JSONL=$(find "$CLAUDE_DIR/projects" -path "*/subagents/agent-${AGENT_ID}.jsonl" 2>/dev/null | head -1)

if [ -n "$SESSION_JSONL" ]; then
  cp "$SESSION_JSONL" "workspace/provenance/sessions/<role>-${AGENT_ID:0:8}.jsonl"
fi

# Update workspace.json agent_runs array with:
#   { agent, agentId, role, model, effort, dispatch_record, session_log, started_at, completed_at, status, output_files }

# Append entry to provenance/audit-log.md

# Stage and commit all changes together:
#   - Agent output files
#   - Session JSONL copy (if captured)
#   - Updated workspace.json
#   - Updated provenance/audit-log.md
```

`dispatch_record` and `session_log` are paths relative to the workspace root, for example `provenance/dispatch/L1-chunk-analyzer.md` and `provenance/sessions/chunk-analyzer-1a2b3c4d.jsonl`. Neither path starts with `workspace/`. If no log was captured, `session_log` is `null`. The floor rule reads these fields at every gate.

If the JSONL file cannot be found (agent ran in a different process), log a warning and continue. The provenance citations embedded in the output files are the primary audit trail; session JSONLs are supplementary.

---

## Git Commit Protocol

Every agent run produces a commit. The commit message format:

```
[L{N}:{agent-name}] Description of what was produced
```

Examples:
```
[init] Create analysis workspace for acme-cli
[L1:bundle-splitter] Decompose main bundle into 47 chunks
[L1:chunk-analyzer] Analyze chunk-023: record parsing module
[L1:doc-researcher] Extract behavioral claims from official docs
[L2:feature-discoverer] Aggregate feature inventory from 3 intelligence sources
[L2:module-mapper] Identify 12 modules for deep documentation
[L3:deep-dive-analyzer] Session management module spec
[L3:user-journey-analyzer] Login flow end-to-end journey
[gate:spec-verifier] Verification and provenance audit - PASS
[L4:test-vector-generator] 156 test vectors for session management
[L4:acceptance-criteria-writer] Acceptance criteria: 12 modules
[gate:spec-reviewer] Review report - PASS
[L5:spec-sanitizer] Sanitize record parsing module spec
```

Gate tags:
```bash
git tag -a gate-1-pass -m "Gate 1 passed: spec-verifier (N contradictions, M% provenance coverage)"
git tag -a source-completeness-pass -m "Gate 1b: Source-to-spec completeness validated"
git tag -a gate-2-pass -m "Gate 2 passed: spec-reviewer (0 implementation leaks)"
git tag -a specs-ready -m "Layer 5: All raw specs sanitized to output/"
git tag -an review-complete -m "Layer 6: Independent audit passed (semantic review + deep-read)"
git tag -a fidelity-check-complete -m "Layer 7: Fidelity validation passed (N claims, M% match rate)"
```

---

## Failure Handling

| Failure Type | Response |
|-------------|----------|
| Agent produces no output | Log warning, continue. Quality gates will catch the gap. |
| Agent produces partial output | Commit partial output. Flag for review. Continue. |
| Gate fails | Remediate up to 3 times. If still failing, abort with exit code 1. |
| Model not available for a dispatch | Stop and ask the user for a substitute. Record it with `greenfield-tiers substitute`. Never select a weaker model without the user. |
| Container build/crash | Log error. Mark runtime mode as unavailable/degraded. Continue with other modes. |
| macOS permission denied (TCC) in the runtime environment | Re-run TCC provisioning in the environment, then the VNC manual grant; if still denied, degrade per the preflight doctor matrix (drop screenshots / drop role / exclude source type). Continue with remaining sources. |
| Runtime environment unavailable or lost | Mark `macos-runtime` and `app-data` excluded. Continue with remaining sources. |
| User interruption | Workspace state preserved in git. Re-run `/analyze` to resume automatically. |

---

## Print Summary

After pipeline completion (or failure), print a summary. Shape depends on whether the user opted in to sanitization.

**Raw-only path (Layers 5–7 skipped):**

```
=== ANALYSIS SUMMARY ===
Target:            <target-name>
Workspace:         <workspace-path>
Sources analyzed:  source, docs, sdk, community, git-history, tests, macos-bundle
Sources skipped:   runtime (no container runtime), binary (no binaries found),
                   macos-runtime, app-data (environment: none)
Environment:       none
Agents dispatched: N
Model tiers:       deep fable/high, standard opus/high, light sonnet/medium (substitutes: none)
Floor warnings:    N
Gate 1:            PASS
Gate 1b:           PASS
Gate 2:            PASS
Sanitization:      SKIPPED (user opted out)
Output:            workspace/raw/specs/ (with provenance citations)
Next steps:        Read raw/specs/ directly, or rerun /analyze and opt in
                   to sanitization when you need a source-free spec.
```

**Full sanitization path (Layers 5–7 ran):**

```
=== ANALYSIS SUMMARY ===
Target:             <target-name>
Workspace:          <workspace-path>
Sources analyzed:   source, docs, sdk, community, git-history, tests,
                    macos-bundle, macos-runtime, app-data
Sources skipped:    runtime (no container runtime), binary (no binaries found)
Environment:        vm-tart (greenfield-<slug>-target, deleted)
Agents dispatched:  N
Model tiers:        deep fable/high, standard opus/high, light sonnet/medium (substitutes: none)
Floor warnings:     N
Gate 1:             PASS
Gate 1b:            PASS
Gate 2:             PASS
Sanitization:       COMPLETE (rewrite, not copy)
Second-Pass Review: PASS
Fidelity Check:     PASS
Contamination:      NONE DETECTED
Output:             workspace/output/ (sanitized) + workspace/raw/ (with provenance)
Next steps:         Hand off workspace/output/ to the implementation team
```

---

## ANALYSIS RULES

1. **Analyze exhaustively** - Every code path, every decision, every edge case
2. **Output behaviorally** - No source identifiers in specs
3. **Preserve interfaces** - Env vars, CLI flags, config keys ARE behavioral
4. **Remove internals** - Function names, variable names, line numbers are NOT
5. **Annotate provenance** - Every behavioral claim must have a `<!-- cite: -->` annotation

## WHAT TO PRESERVE vs REMOVE

**PRESERVE (behavioral interfaces):**
- `DATABASE_URL` (env var)
- `--format` (CLI flag)
- `upstreams` (config key)
- `request_id`, `batch_size` (API fields)

**REMOVE (implementation details):**
- `Ab2()`, `parseArgs()` (function names)
- `r0`, `jobId`, `sp` (variable names)
- `Fx3`, `JobScheduler` (class names)
- "Line 1234", "in src/cli.ts" (locations)
- `workspace/raw/source/analysis/chunk-12.md:45` (raw file paths in output)

---

## AFTER ANALYSIS

### If the user opted out of sanitization (raw-only path)

1. Verify `analysis-complete-raw` tag exists.
2. Verify `workspace/raw/specs/` contains module specs, journeys, contracts, test vectors, and acceptance criteria.
3. The raw specs are the deliverable. Provenance citations point back to source.
4. No Layer 5/6/7 artifacts exist — `workspace/output/` is empty or absent.

### If the user opted in to sanitization (full path)

1. Verify `review-complete` tag exists (Layer 6 second-pass review passed — semantic review + deep-read)
2. Verify `fidelity-check-complete` tag exists (Layer 7 fidelity validation — no P0 behaviors lost)
3. Verify `workspace/output/` contains sanitized specs, test vectors, acceptance criteria, and audit summaries
4. If contaminated: dispatch sanitizer rewrites → re-run Layer 6 deep-read audit
5. If fidelity gaps: dispatch sanitizer to restore detail → re-run Layer 6 + Layer 7
6. Implementation reads from `workspace/output/` — hand off the specs, test vectors, and acceptance criteria to the implementation team
