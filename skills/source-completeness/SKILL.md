---
name: source-completeness
description: Validates that all user-facing surfaces discovered in source code are captured in the behavioral specs. Catches coverage gaps where the analysis pipeline missed features, tools, env vars, CLI flags, or other behavioral interfaces. Run AFTER Layer 3 specs are written, BEFORE sanitization.
---

# Source-to-Spec Completeness Validation

## Why This Exists

The analysis pipeline (Layers 1-3) reads source code and produces behavioral specs. But it can miss things:
- Registered commands or tools defined in source but not in the tool catalog
- Environment variables read by the code but not documented
- CLI flags defined in the argument parser but not cataloged
- Subcommands registered dynamically or conditionally
- Config keys accessed in settings but not listed in the config spec
- Events dispatched but not inventoried
- Error categories defined but not documented

The fidelity validation (Layer 7) only checks raw→clean. This skill checks **source→raw** — it goes back to the actual source code and verifies that every discoverable user-facing surface was captured in the specs.

## When to Run

Run AFTER Layer 3 deep documentation is complete, ideally as part of Gate 1 or as a pre-Gate-1 completeness check. If gaps are found, dispatch deep-dive agents to cover the missing areas before proceeding.

Also run AFTER Layer 7 fidelity validation to catch anything the fidelity check couldn't find (because it was never in the raw specs).

## The Checks

Search patterns depend on target shape. For a single-file bundle, grep the bundle directly. For a source tree, grep recursively across the source root. Patterns also depend on the target language's idioms for registering each surface — the examples below give common patterns for several languages; adjust to the actual target.

**Check activation by target shape:** Checks 1-7 (code-grep) activate only when a source tree or extractable bundle exists. Checks M1-M6 activate when `workspace/raw/macos/bundle/` exists; Check M7 activates when `workspace/raw/macos/runtime/` exists. Both sets can be active simultaneously — e.g., an Electron app shipped in a `.app` wrapper, or a Mac app with source available.

### Check 1: Tool / Command Registration Completeness

Applies to targets that expose a registered command, tool, or handler surface (CLIs with subcommands, plugin hosts, RPC servers with method registration).

**Source extraction:** grep for the registration pattern used by the target. Examples:

```bash
# Named-object pattern (common in JS/TS/Go handler registration)
grep -roE 'name:\s*"[A-Z][a-zA-Z]+"' <source-root> | sort -u

# Decorator-based registration (Python)
grep -roE '@(command|tool|handler|register)\(' <source-root>

# Macro-based registration (Rust)
grep -roE '#\[(command|tool|handler)' <source-root>

# Assigned-constant pattern (JS/TS)
grep -roE 'var [a-zA-Z0-9_]+="[A-Z][a-zA-Z]+"' <source-root> | grep -v 'Exception\|Error\|Element'
```

**Spec extraction:** every registered name in the tool/command catalog section of the spec.

**Diff:** every registered name in source must appear in the spec. Missing names are P0-CRITICAL gaps.

### Check 2: Environment Variable Completeness

**Source extraction:** patterns by language:

```bash
# Node/TypeScript
grep -roE 'process\.env\.[A-Z_][A-Z0-9_]*' <source-root> | sed 's/.*process\.env\.//' | sort -u
# Python
grep -roE 'os\.environ(\.get)?\(?"[A-Z_][A-Z0-9_]*"' <source-root> | grep -oE '[A-Z_][A-Z0-9_]+' | sort -u
# Go
grep -roE 'os\.Getenv\("[A-Z_][A-Z0-9_]*"\)' <source-root> | grep -oE '[A-Z_][A-Z0-9_]+' | sort -u
# Rust
grep -roE 'env::var\("[A-Z_][A-Z0-9_]*"\)' <source-root> | grep -oE '[A-Z_][A-Z0-9_]+' | sort -u
```

**Spec extraction:** all env var names from the environment contract spec.

**Diff:** categorize missing env vars:
- User-facing (`DATABASE_*`, `AWS_*`, `GCP_*`, `LOG_*`, and similar) → P0: must document
- Internal-only (test vars, build vars) → P2: note but don't require
- Standard (`HOME`, `PATH`, `SHELL`, `TERM`) → ignore

### Check 3: CLI Flag Completeness

**Source extraction:**

```bash
# Quoted flag strings — works across most CLI frameworks
grep -roE '"--[a-z][a-z0-9-]+"' <source-root> | sort -u

# Framework-specific definitions:
#   Rust/clap:    .arg("--flag-name")
#   Python/argparse: add_argument("--flag-name")
#   Go/flag:      flag.StringVar(&v, "--flag-name", ...)
grep -roE '\.arg\("--[a-z-]+"|add_argument\("--[a-z-]+"|flag\.\w+Var\([^,]+,\s*"--[a-z-]+"' <source-root>
```

**Spec extraction:** every `--flag` name in the CLI contract spec.

**Diff:** every flag must appear. Hidden flags should be documented as hidden.

### Check 4: Subcommand Completeness

Applies to CLIs or REPLs with a subcommand surface.

**Source extraction:** target-dependent. For subcommand CLIs, grep for the subcommand registration or dispatch table (clap subcommands, Cobra, argparse subparsers). For REPL-style interfaces, grep for the command-prefix pattern (e.g., `/help`, `:quit`).

**Spec extraction:** every subcommand from the CLI interface spec.

**Diff:** every registered subcommand must appear.

### Check 5: Event Dispatch Completeness

Applies to targets that dispatch named events — common shapes include observer patterns, signals, message buses, and webhook emission.

**Source extraction:** grep for event dispatch calls and event-type string constants. Common shapes: `emit("event-name", ...)`, `dispatch(EventType.X)`, `pubsub.publish("...", ...)`, signal/slot registrations, `raise EventName(...)`.

**Spec extraction:** every event type documented in the extensibility or eventing spec.

**Diff:** every dispatched event type must be documented.

### Check 6: Config Key Completeness

**Source extraction:** Search for settings property accesses and config key strings.

**Spec extraction:** Extract all config keys from the configuration spec.

**Diff:** User-configurable keys must appear. Internal state keys are P2.

### Check 7: Error Category Completeness

**Source extraction:** Search for error class definitions, error type enums, and error message constants.

**Spec extraction:** Extract all documented error categories.

**Diff:** User-visible errors must be documented.

## Target Shape: macOS App Bundle (Checks M1-M7)

These checks activate when `workspace/raw/macos/bundle/` exists. Unlike Checks 1-7, the source side diffs the **evidence files** Layer 1 already produced against the specs — it does not re-run tools against the target. M7 is the exception and runs in the opposite direction; see below.

### Ground-truth independence

Every check declares the class of its ground truth, and reports that class beside its verdict:

- **`self`** — M1, M2, M5, M6. Ground truth is an evidence file this pipeline produced (`command-surface.md`, `defaults.md`, `text-catalog.md`). Whatever the extractor missed is missing from both sides of the diff, so these checks are real but structurally incapable of failing on thinness.
- **`independent`** — M3, M4. Ground truth is the bundle's own static bytes — the `Info.plist` contracts and the sdef — read host-side before any environment existed. Checks 1-7 are `independent` for the same reason: a source tree is not the artifact under test.
- **`frozen+independent`** — M7. Ground truth is a denominator frozen before exercising began AND cross-checked against anchors outside the observation.

The class is not decoration. It is what makes the PASS rule at the end of this skill mean anything.

### Check M1: Menu Command Coverage

**Source extraction:** every CMD-NNN record in `workspace/raw/macos/runtime/command-surface.md` — each records a menu item with its menu path, keyboard shortcut, enabled state, and mutation class.

**Spec extraction:** every menu command documented in the specs.

**Diff:** every enabled menu item must have spec coverage. Missing enabled items are P0-CRITICAL gaps — menu items are the GUI analog of registered subcommands. Contextual/dynamic items are P1.

### Check M2: Keyboard Shortcut Coverage

**Source extraction:** the shortcut column of `workspace/raw/macos/runtime/command-surface.md`, plus any shortcut list from official docs.

**Spec extraction:** every keyboard shortcut documented in the specs.

**Diff:** every shortcut must appear with its effect. Missing shortcuts are P0.

### Check M3: Info.plist Contract Coverage

**Source extraction:** `workspace/public/contracts/macos-plist-contracts.md` — every URL scheme, document type, exported/imported UTI, and NSServices entry.

**Spec extraction:** every declared contract surface in the specs/contracts.

**Diff:** every declared entry must appear. Missing entries are P0. Note: the plist declares only the scheme NAME; command paths/parameters come from docs + runtime — a declared scheme with no commands specified anywhere is itself a P0 gap ("declared URL scheme with unspecified command surface").

### Check M4: AppleScript Surface Coverage

**Source extraction:** `workspace/public/contracts/macos-sdef.md` — every class, command, property, and enumeration.

**Spec extraction:** every scripting term documented in the specs.

**Diff:** every term must have spec coverage. Missing terms are P0; terms marked `hidden="yes"` are P2 (documented as hidden, mirroring hidden CLI flags).

### Check M5: Preference Key Coverage

**Source extraction:** keys in `workspace/raw/macos/app-data/defaults.md` intersected with settings-UI observations.

**Spec extraction:** every preference key from the configuration spec.

**Diff:** categorize missing keys (same categorization pattern as the env-var check):
- User-configurable keys → P0: must document
- Internal state keys (window frames, one-shot flags) → P2: note but don't require
- Apple/framework keys (`NS*`/`Apple*`) → ignore

### Check M6: User-Visible String Category Coverage

**Source extraction:** categories in `workspace/raw/macos/bundle/text-catalog.md` (errors/alerts, confirmations, empty states, onboarding, notifications...).

**Spec extraction:** spec sections covering each user-visible text surface.

**Diff:** diff at CATEGORY level, not string-by-string — every category with user-visible text needs a spec section covering that surface. Missing categories are P1.

### Check M7: UI State Coverage

Checks M1-M6 ask *is everything in the evidence also in the spec?* M7 asks the question that has to be answered first: *is everything that should have been observed actually in the evidence?* It is the only M-check that runs evidence-first, and it exists because the others cannot see a thin observation.

M1 and M2 take their ground truth from `command-surface.md` — the observer's own output. A thin observation therefore supplies both sides of its own diff and can never fail. In a real run the observer enumerated 111 menu commands and captured visual evidence for roughly 21 of them; M1 and M2 both passed. M7 is the check that fails that run.

**Source extraction:** `workspace/raw/macos/runtime/state-coverage.md` — the coverage denominator, frozen at the end of Phase 3 before any exercising began. One `ST-NNN` row per UI state that should exist, each carrying a `Status` (`CAPTURED | UNREACHABLE | BLOCKED | NOT-ATTEMPTED`) and an `Anchor` (`menu | sidebar | window | sdef | plist | strings | constant | flow`), under the header line:

```
**Enumerated:** N   **Captured:** N   **Unreachable:** N   **Blocked:** N   **Not-attempted:** N
```

**Ground truth:** the coverage file *cross-checked against its anchors* — never the coverage file alone. **Evidence may never be its own denominator.**

| Anchor | Class | Cross-check against | Why it holds |
|--------|-------|---------------------|--------------|
| `strings`, `sdef`, `plist` | independent | `workspace/raw/macos/bundle/text-catalog.md`, `workspace/public/contracts/macos-sdef.md`, `workspace/public/contracts/macos-plist-contracts.md` | Different agent, host-side, static bytes, produced before any environment existed |
| `constant` | unshrinkable | the hardcoded row list in `macos-visual-exploration` | Literal text in the visual skill — no underperformance can shrink it |
| `menu`, `sidebar`, `window` | structurally independent | `command-surface.md` `CMD-NNN` IDs, the window inventory | Read-only enumerations whose cost does not scale with exercising. Honest only because of the denominator freeze plus the `CMD-NNN` cross-check — remove either and they collapse back into self-anchoring |
| `flow` | **never an anchor** | — | Flow-discovered states are advisory rows: they may count toward what was covered, never toward what was required. This is the M1/M2 lesson written down |

**Diff — P0-CRITICAL:**

- `state-coverage.md` missing while `command-surface.md` exists.
- Any row still `NOT-ATTEMPTED`.
- An enabled `CMD-NNN` in `command-surface.md` with no `ST-NNN` row.
- A `constant` row missing, or present with a status its cited evidence does not support.
- A row on an independent anchor (`strings`, `sdef`, `plist`) that is `NOT-ATTEMPTED`, or `UNREACHABLE` with no stated mechanism.
- Header counts disagreeing with the counts recomputed from the rows.
- A `BLOCKED` row that names neither the ladder rungs tried nor one of the two accepted ceiling reasons, `remediation-exhausted` (the Layer 1 gate's remediation loop ran out of rounds) or `environment-unavailable-at-gate-1b` (the environment was gone before this check ran). An unfalsifiable blocked claim looks exactly like diligence — that is why the unnamed case is P0. The two ceiling reasons are written by the pipeline itself; they are P1 findings about the run rather than gaps in it, and must never be re-dispatched against, because nobody can close a row the ceiling already declared unclosable.

**P1:**

- `BLOCKED` rows that DO name their rungs. The app resisted automation; that is a fact about the app, reported as one.
- MUTATING commands with no exercised-with-diff evidence.
- **Thin-inventory advisory.** Compare the `CMD-NNN` count in `command-surface.md` against the menu-label category of `text-catalog.md`. Report **both counts and an assessment in prose**. Never auto-fail on a ratio: the two counts legitimately diverge (localized strings, dead strings, dynamically built menus), and any threshold would be wrong for some app.

**P2:**

- Disabled or contextual commands with no coverage row.
- sdef terms marked `hidden="yes"`.
- `flow`-anchored rows, in any status.

**AX affordances are a finding, not a failure.** A `BLOCKED` row backed by an `AXA-NNN` record in `ax-affordance-map.md` documents that the app does not vend an affordance for that state. Report it P1 as a fact about the app — it is at once an accessibility-conformance defect and an automatability limit — and never as a run failure. The run did the work; the app did not vend the surface.

**Degradation awareness.** Read the `**Degradation mode:**` line before scoring anything, or M7 will false-fail a correctly degraded run:

- `AX-only` — a `CAPTURED` row cites an `.ax.md` sidecar instead of a `.png`. A missing screenshot is not a gap.
- `rect-fallback` (read `**Capture scope:**` beside the mode) — the run had no window enumeration, so every capture is a display crop. Confirm the `scope=rect (occlusion not excluded)` stamp is present on those captures and on any claim citing them; an unstamped rect capture is P1. A claim about what is ABSENT from a frame cannot be `confirmed` on a rect capture alone, because an occluder could have covered it.
- `abort` — M7 is NOT-APPLICABLE. There was no environment to observe.
- `UNREACHABLE` with a stated mechanism is a **passing** outcome, not a gap. The state does not exist to be captured, and the sentence says why.
- States excluded by `host-direct` policy — URL-scheme exercise, `shortcuts run` — are P2, not P0. They were not skipped; they were forbidden.

**NOT-APPLICABLE** only when there is nothing to check: no `workspace/raw/macos/runtime/` directory, `**Environment:** none`, or `abort` degradation mode. A present-but-thin `state-coverage.md` is a FAIL.

Report raw counts. Never publish a coverage percentage — a single number becomes a target.

## Report Format

```markdown
# Source-to-Spec Completeness Report

## Summary
| Check | Ground truth | Source Count | Spec Count | Missing | Extra | Verdict |
|-------|-------------|-------------|------------|---------|-------|---------|
| Registered commands/tools | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Env Vars | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| CLI Flags | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Subcommands | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Events dispatched | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Config Keys | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Error Categories | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Menu Commands (M1) | self | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Keyboard Shortcuts (M2) | self | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Info.plist Contracts (M3) | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| AppleScript Surface (M4) | independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| Preference Keys (M5) | self | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| String Categories (M6) | self | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |
| UI State Coverage (M7) | frozen+independent | N | N | N | N | PASS/FAIL/NOT-APPLICABLE |

(List only the checks applicable to the target shape.)

(For M7, `Source Count` is the frozen enumerated total, `Spec Count` is `CAPTURED` plus `UNREACHABLE`-with-mechanism, and `Missing` is everything else. Raw counts only — no percentage.)

## P0-CRITICAL Gaps (must fix)
[List all missing user-facing surfaces]

## P1 Gaps (should fix)
[List missing non-critical surfaces]

## P2 Gaps (advisory)
[List internal-only surfaces]

## Verdict: PASS | FAIL
PASS requires three things:
1. Zero P0 gaps.
2. At least one applicable check per user-facing surface the discovery inventory identified.
3. At least one PASSING check whose ground truth is `independent` or `frozen+independent`.
```

Requirement 3 exists because the first two can both be satisfied by a run that only ever compared its own output to itself. A run whose only passing checks are self-anchored has graded its own homework.

Each check reports `PASS | FAIL | NOT-APPLICABLE`, plus its ground-truth class. A check whose extraction surface does not exist for this target shape (e.g., `process.env` greps with no source tree) MUST report NOT-APPLICABLE — never PASS. Zero findings from a probe that could not have found anything is absence of evidence, not evidence of coverage.

**NOT-APPLICABLE is for an ABSENT surface, never a THIN one.** The surface does not exist, or the extraction could not have run: that is NOT-APPLICABLE. An evidence file that exists but is sparse is a different thing entirely — score it against its independent anchor and let it FAIL. Downgrading a thin surface to NOT-APPLICABLE is how an under-observed run becomes an unscored one.

If ALL checks are NOT-APPLICABLE, Gate 1b FAILS with "no completeness evidence exists for this target shape."

## Agent Dispatch Pattern

Dispatch as `greenfield:analyzer` since it needs to read both source code and specs. Can be parallelized:
- One agent per applicable check, or
- Batch checks 1-3 (commands/tools, env vars, CLI flags) and checks 4-7 (subcommands, events, config keys, errors) into 2 agents
- For the macOS checks, batch by shared evidence file: M1+M2 (both read command-surface.md), M3+M4 (both read the contract files), and M5+M6
- **M7 gets its own agent.** It reads `state-coverage.md` plus all three independent bundle anchors (`text-catalog.md`, `macos-sdef.md`, `macos-plist-contracts.md`) and the `**Degradation mode:**` line, and it runs in the opposite direction from every other check — do not fold it into a batch that is diffing evidence against specs

## Relationship to Other Validations

```
Source Code / Evidence → [Layer 1-3 analysis] → Raw Specs → [Layer 5 sanitization] → Output Specs
                                                     ↑                                        ↑
                                               source-completeness                     fidelity-validation
                                               (source → raw)                      (raw → clean)
                                                     ↑                                        ↑
                                               "Did we capture it?"                   "Did we preserve it?"
```

Together these two validations form a complete chain: source-completeness ensures nothing was missed during analysis, and fidelity-validation ensures nothing was lost during sanitization.

## Integration with Public Documentation

When public documentation is available (docs mode was active), cross-reference the source findings against official docs:
- Features documented in official docs but missing from specs → P0 gap
- Features in source but not in official docs → likely internal, lower priority
- Features in official docs but not in source → version mismatch or deprecated

This cross-reference is especially valuable because official documentation represents the **intended** user-facing surface, while source extraction finds the **actual** surface. Discrepancies in either direction are informative.
