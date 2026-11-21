# Greenfield

**Reverse engineer clean behavioral specs from any codebase.**

Greenfield reads source code, documentation, SDKs, runtime behavior, and binaries, then produces behavioral specifications, test vectors, acceptance criteria, and a full provenance trail. The output describes *what* the software does — not *how* any particular codebase does it — so a fresh implementation team can build against the specs without inheriting the original's internal structure.

Greenfield is a [Claude Code](https://claude.com/claude-code) plugin. It runs inside the `claude` CLI and uses Claude agents as the workers that read code, write specs, and audit output.

## Installation

```bash
/plugin marketplace add prime-radiant-inc/prime-radiant-marketplace
/plugin install greenfield@prime-radiant-marketplace
```

Restart Claude Code after installing.

## Usage

### Extract specs

```bash
claude
> /analyze /path/to/target
```

`/analyze` runs a seven-layer pipeline. It discovers the available intelligence sources (source, docs, SDK, community, runtime, binary, git history, tests, UI, contracts), gathers evidence from each, synthesizes behavioral specs with provenance citations, generates test vectors and acceptance criteria, sanitizes the specs of implementation details, then runs a second-pass review of the result.

Target shape doesn't matter. Greenfield has been used on single-file minified JavaScript bundles and on source-tree projects; the pipeline also has a path for decompiled native binaries. The methodology adapts to what's there.

macOS app analysis runs in a disposable environment — a Tart or Lume VM, or a throwaway account — chosen at dispatch time, so no personal data enters the analysis.

Workspace output:

```
workspace/
├── raw/         # Analysis artifacts with source references
├── output/      # Sanitized specs for the implementation team
│   ├── specs/
│   ├── test-vectors/
│   └── validation/
└── provenance/  # Citation audit trail
```

### Re-sanitize an existing workspace

```bash
claude
> /sanitize /path/to/workspace
```

Re-runs the sanitization pass on an existing workspace. Useful when the initial pass left contamination that the audit caught.

### Implement from the output specs

Greenfield stops at the specs. The implementation team reads `workspace/output/` and builds against the behavioral specs, test vectors, and acceptance criteria there.

## How it works

The pipeline dispatches agents with role-specific prompts across the seven layers. Each dispatch runs one of two generic agent types loaded with a specific skill:

- **analyzer** — the workhorse. Reads evidence and writes specs. Dispatched under many roles across layers: `discovery-agent`, `bundle-splitter`, `chunk-analyzer`, `function-analyzer`, `doc-researcher`, `community-analyst`, `sdk-analyzer`, `cli-explorer`, `behavior-observer`, `feature-discoverer`, `architecture-analyst`, `api-extractor`, `synthesizer`, `module-mapper`, `deep-dive-analyzer`, `behavior-documenter`, `user-journey-analyzer`, `contract-extractor`, `spec-verifier`, `spec-remediator`, `source-completeness-checker`, `test-vector-generator`, `test-generator`, `acceptance-criteria-writer`, `spec-reviewer`, `structural-leakage-reviewer`, `content-contamination-reviewer`, `behavioral-completeness-reviewer`, `deep-read-auditor`, `fidelity-validator`.
- **sanitizer** — rewrites raw specs into output specs free of implementation details. Dispatched during Layer 5 and for remediation during Layers 6 and 7.

### Pipeline

| Layer | Roles | Output |
|-------|-------|--------|
| L1: Intelligence | bundle-splitter, chunk-analyzer, function-analyzer, doc-researcher, community-analyst, sdk-analyzer, cli-explorer, behavior-observer | Raw evidence from source, docs, SDK, community, runtime, binary |
| L2: Synthesis | feature-discoverer, architecture-analyst, api-extractor, synthesizer, module-mapper | Feature inventory, architecture model, module map |
| L3: Deep Docs | deep-dive-analyzer, behavior-documenter, user-journey-analyzer, contract-extractor | Behavioral specs, journeys, contracts |
| Gate 1 | spec-verifier, spec-remediator | Correctness, contradictions, gaps |
| Gate 1b | source-completeness-checker | Every user-facing surface captured |
| L4: Validation | test-vector-generator, test-generator, acceptance-criteria-writer | Test vectors, test specs, acceptance criteria |
| Gate 2 | spec-reviewer, spec-remediator | Implementation leakage, completeness, quality |
| L5: Sanitization | sanitizer | Output specs rewritten from understanding, not copied |
| L6: Review | structural, content, completeness reviewers + deep-read auditors | Second-pass contamination review |
| L7: Fidelity | fidelity-validators | Flags behavioral detail lost or weakened during sanitization |

## Model tiers

Each role runs on a fixed model and effort level. The model of your session does not change them.

| Tier | Model | Effort | One raise step |
|------|-------|--------|----------------|
| deep | fable | high | effort becomes xhigh |
| standard | opus | high | moves to deep |
| light | sonnet | medium | moves to standard |

| Tier | Stage | Roles |
|------|-------|-------|
| deep | Layer 2 | `feature-discoverer`, `architecture-analyst`, `api-extractor`, `analysis-synthesizer`, `module-mapper` |
| deep | Layer 3 | `deep-dive-analyzer`, `behavior-documenter`, `user-journey-analyzer`, `contract-extractor` |
| deep | Gates 1, 1b, 2 | `spec-verifier`, `source-completeness-checker`, `spec-reviewer`, `spec-remediator` |
| deep | Layer 5 | `sanitizer`, `contamination-judge` |
| deep | Layer 6 | `structural-leakage-reviewer`, `content-contamination-reviewer`, `behavioral-completeness-reviewer`, `deep-read-auditor` |
| deep | Layer 7 | `fidelity-validator` |
| standard | Step 2 | `discovery-agent` |
| standard | Layer 1 | `bundle-splitter`, `chunk-analyzer`, `doc-researcher`, `test-reader`, `binary-deep-analyzer`, `cli-explorer`, `web-ui-explorer`, `behavior-observer`, `ux-documenter`, `visual-explorer`, `bundle-inspector`, `applescript-explorer`, `ui-observer`, `data-inspector` |
| standard | Layer 4 | `test-vector-generator`, `test-generator`, `acceptance-criteria-writer` |
| light | Layer 1 | `function-analyzer`, `contract-parser`, `test-runner`, `binary-surveyor`, `git-archaeologist`, `community-analyst`, `sdk-analyzer`, `integration-test-miner` |

If a dispatch returns deficient output, the next dispatch of the same role moves up one step. Each step follows the "One raise step" column. The ceiling is fable at xhigh effort. No dispatch uses effort max.

If you have no Fable access, change the `tier deep` row in `model-tiers.tsv`. Also change the `model:` and `effort:` lines of `agents/analyzer.md` and `agents/sanitizer.md`. The lint requires the agent defaults to equal that row.

Two environment variables override the table. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` sets one model for every subagent. `CLAUDE_CODE_EFFORT_LEVEL` sets one effort for every dispatch. If either variable is set, the run does not use the tiers. Run `greenfield-tiers preflight` to see which of them are set.

Model tiers need Claude Code 2.1.292 or later.

Run `scripts/test-tiers.sh` to test the tier tool and `scripts/lint-tiers.sh` to check that the plugin files agree with the tier file.

## License

Apache 2.0. Copyright 2026 Prime Radiant, Inc.
