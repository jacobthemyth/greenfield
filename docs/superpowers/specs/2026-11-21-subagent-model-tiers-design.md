# Subagent model tiers: design

Date: 2026-11-21

Status: waiting for review

## Purpose

Greenfield runs about 45 subagent roles from two commands, `/analyze` and `/sanitize`. Today each subagent inherits the model of the session that starts the run. Only `function-analyzer` has a fixed model, and no dispatch sets an effort level. As a result, spec quality changes with the session model.

This change gives each role a fixed model and a fixed effort level. A run from a Sonnet session and a run from a Fable session must send the same role to the same model.

Consistent quality is the first goal. Cost and rate limits are secondary. When the goals conflict, quality wins.

## Terms

- Orchestrator: the session that runs `/analyze` or `/sanitize` and dispatches the subagents.
- Tier: a named pair of one model and one effort level.
- Floor: the weakest model and effort that a role can run on.
- Raise: a move to a stronger model or effort for one dispatch.
- Dispatch record: the file that holds a dispatch prompt, written before the Agent call.

## Decisions

The user made these decisions during the design session.

1. Consistent quality is the main goal.
2. Each role has a fixed floor. The orchestrator can raise a dispatch above the floor, and it can never go below the floor.
3. The top tier is Fable. A raise from the top tier increases the effort level.
4. One tier table holds the assignments. Both agent definitions declare the top tier as the default.
5. There are three tiers, and no role runs on Haiku.
6. Every layer gate enforces the floor. The gate also compares the floor with the model that the subagent ran on.
7. Spec edits and contamination verdicts move from the orchestrator to top-tier subagents.

## Tiers

| Tier | Model | Effort | One raise step |
|------|-------|--------|----------------|
| deep | fable | high | effort becomes xhigh |
| standard | opus | high | moves to deep |
| light | sonnet | medium | moves to standard |

The model order, from weakest to strongest, is haiku, sonnet, opus, fable. The effort order is low, medium, high, xhigh, max.

The raise ladder has four positions: sonnet/medium, opus/high, fable/high, fable/xhigh. The ceiling is fable/xhigh. No dispatch uses effort max.

## Role assignment

Three rules decide the tier of a role.

- If later layers trust the output of a role and do not read the evidence again, the role is deep.
- If a role gathers primary evidence, the role is standard.
- If a role extracts from structured or public input that other sources corroborate, the role is light.

| Tier | Stage | Roles |
|------|-------|-------|
| deep | Layer 2 | feature-discoverer, architecture-analyst, api-extractor, analysis-synthesizer, module-mapper |
| deep | Layer 3 | deep-dive-analyzer, behavior-documenter, user-journey-analyzer, contract-extractor |
| deep | Gates 1, 1b, 2 | spec-verifier, source-completeness-checker, spec-reviewer, spec-remediator |
| deep | Layer 5 | sanitizer, contamination-judge |
| deep | Layer 6 | structural-leakage-reviewer, content-contamination-reviewer, behavioral-completeness-reviewer, deep-read-auditor |
| deep | Layer 7 | fidelity-validator |
| standard | Step 2 | discovery-agent |
| standard | Layer 1 | bundle-splitter, chunk-analyzer, doc-researcher, test-reader, binary-deep-analyzer, cli-explorer, web-ui-explorer, behavior-observer, ux-documenter, visual-explorer, bundle-inspector, applescript-explorer, ui-observer, data-inspector |
| standard | Layer 4 | test-vector-generator, test-generator, acceptance-criteria-writer |
| light | Layer 1 | function-analyzer, contract-parser, test-runner, binary-surveyor, git-archaeologist, community-analyst, sdk-analyzer, integration-test-miner |

Two entries need a note.

- `spec-remediator` is a new role. The section "Inline work moves to subagents" describes it.
- `function-analyzer` moves from Haiku to Sonnet. It is one dispatch that reads every chunk analysis, so Haiku saves little.

The role name `sanitizer` covers every dispatch of the `greenfield:sanitizer` agent type. The dispatch prompts for that agent type carry no `Role:` line today, and this change adds one.

## Tier file

The plugin ships one file, `model-tiers.tsv`, at the plugin root. It is the only place that holds the tiers and the role assignments. The file is tab-separated and holds two kinds of rows. The tool also accepts spaces between the fields.

```text
tier	deep	fable	high
tier	standard	opus	high
tier	light	sonnet	medium
role	deep-dive-analyzer	deep
role	doc-researcher	standard
role	function-analyzer	light
```

A user who has no Fable access changes one row, the `tier deep` row. The README states this.

At the start of a run, a script copies the file to `workspace/provenance/model-tiers.tsv`. The model does not transcribe the table. The workspace copy is the floor for that run, and it is committed with the workspace. A run that resumes keeps the workspace copy that exists.

## The `greenfield-tiers` tool

The plugin gains one executable, `bin/greenfield-tiers`. Claude Code puts the `bin/` directory of an enabled plugin on the PATH of the Bash tool. The orchestrator runs the tool by its bare name. The tool is a bash script, and it finds the plugin tier file relative to its own location.

| Subcommand | Action |
|------------|--------|
| `greenfield-tiers preflight` | Reports conditions that can override the tier table. |
| `greenfield-tiers init <workspace>` | Copies the tier file to a workspace that has no copy. |
| `greenfield-tiers lookup <workspace> <role> [steps]` | Prints the model and effort for a role, raised by the given number of steps. |
| `greenfield-tiers floor <workspace> <layer>` | Applies the floor rule to one layer and prints PASS, WARN, or FAIL lines. |
| `greenfield-tiers substitute <workspace> <tier> <model> <effort> <reason>` | Records a substitute that the user approved. |

`lookup` exits with a nonzero status for a role that the tier file does not list. The orchestrator must not dispatch a role that `lookup` rejects.

## Dispatch protocol

The Agent Dispatch Protocol section of `commands/analyze.md` changes as follows.

1. Before each dispatch, the orchestrator runs `greenfield-tiers lookup` for the role.
2. The orchestrator passes the printed model and effort as the `model` and `effort` parameters of the Agent call.
3. The line that restricts a model override to `function-analyzer` is removed.
4. The batching rule keeps its cap of four parallel agents. Its text names a per-model rate limit and no longer names Opus.

Every dispatch passes both parameters, including a dispatch at the default tier. The frontmatter default exists for the case where the orchestrator omits them by mistake.

## Agent definitions

`agents/analyzer.md` and `agents/sanitizer.md` each gain two frontmatter fields.

```yaml
model: fable
effort: high
```

A per-call value on the Agent tool overrides the frontmatter. As a result, a dispatch that omits the parameters runs on the top tier. An omission costs more, and it never lowers quality.

## Raise rule

If both conditions are true, the orchestrator raises a dispatch by one step.

- The same role is dispatched again for the same work.
- The cause is deficient output: a gate failure, missing output, or partial output.

Each later round for the same cause adds one more step, up to the ceiling. The orchestrator passes the step count to `greenfield-tiers lookup`.

If the cause is the environment, the orchestrator does not raise. Examples are the wallpaper failure in Layer 1 Tier 3.7, a lost VM, and a TCC denial. Such a dispatch reuses the values of the earlier round.

A gate judge that runs again after a remediation is not raised. Its earlier output was correct. The raise applies to the role that wrote the deficient output.

## Dispatch record

The dispatch record gains four header lines, after the existing `**Scope:**` line.

```markdown
**Role:** chunk-analyzer
**Model:** opus
**Effort:** high
**Raised:** no
```

If the values are at the floor, `**Raised:**` is `no`. If the values are above the floor, `**Raised:**` is `yes: <reason>`. The `**Role:**` line lets the floor rule find the role without parsing the filename.

Each `agent_runs` entry in `workspace.json` gains five fields: `role`, `model`, `effort`, `dispatch_record`, and `session_log`. `dispatch_record` holds the workspace path of the dispatch record. `session_log` holds the workspace path of the captured session log, or `null`.

The filename prefix `L<layer>-` of a dispatch record names its layer. Three cases need a fixed prefix.

- The `discovery-agent` record uses `L1-`.
- The records of Gate 1 and Gate 1b, and of their remediation, use `L3-`.
- The records of Gate 2 and of its remediation use `L4-`.

A record can carry one more header line, `**Supersedes:** <record filename>`. A dispatch that repeats the full work of an earlier dispatch uses this line. The output of the earlier dispatch is discarded.

## Floor rule at the gates

Every layer gate in `/analyze`, from Layer 1 to Layer 7, runs `greenfield-tiers floor` for its layer. Gate 1 and Gate 1b each run it for Layer 3 after their remediation loop, and Gate 2 runs it for Layer 4. A FAIL line fails the gate. A WARN line does not.

The rule has two passes.

The first pass reads each dispatch record that has the prefix of the layer.

- If the layer has no dispatch record, the result is FAIL.
- If the record lacks a `**Role:**`, `**Model:**`, `**Effort:**`, or `**Raised:**` line, the result is FAIL.
- Only the header lines above the prompt fence count. The prompt text is not read.
- If the model is weaker than the floor model of the role, the result is FAIL.
- If the effort is lower than the floor effort of the role, the result is FAIL.
- If the values are above the floor and `**Raised:**` is `no`, the result is FAIL.

The second pass reads each `agent_runs` entry whose `dispatch_record` has the prefix of the layer.

- If the entry has a session log, the tool reads the model of each assistant message with `jq`.
- If any such model is weaker than the floor model of the role, the result is FAIL.
- If the entry has no session log, or `jq` is not installed, the result is WARN.
- If a model ID names no known alias, the result is WARN.

The second pass exists because Claude Code can replace a blocked model with a fallback model and report no error. The session log holds a full model ID, such as `claude-opus-5-5`. The tool maps an ID to an alias by the alias name inside the ID. The session log does not give a reliable effort level, so the second pass compares only the model.

The existing Tier 2b test in the Layer 1 gate stays. It continues to require a record and a `**Scope:**` line for each Layer 1 role.

## Floor failures

A FAIL line from the first pass means that a dispatch ran below its floor, or that its record cannot prove otherwise. The orchestrator dispatches the role again for the same full scope, at the values that `lookup` prints. The new record names the old record in a `**Supersedes:**` line. The floor rule skips a superseded record and its `agent_runs` entries, and it prints a SKIP line for each. The orchestrator never edits a record to clear a FAIL.

A FAIL line from the second pass means that Claude Code ran a weaker model than the dispatch named. The orchestrator stops and asks the user, as for a model that is not available.

A workspace from before this change holds records with no model lines. On the first `init` in such a workspace, the tool writes the names of those records to `provenance/model-tiers-baseline.txt`. The floor rule skips each record in that file and prints a SKIP line.

## Session log path

The session capture step in `commands/analyze.md` looks for the log at `~/.claude/projects/<encoded-cwd>/<agentId>.jsonl`. Claude Code stores a subagent log at a different path.

```text
~/.claude/projects/<encoded-cwd>/<session-id>/subagents/agent-<agentId>.jsonl
```

The capture step changes to find the file by its name under the project directory. The step does not need the session ID. Capture stays best-effort, and a missing log produces a WARN line at the gate.

## Preflight

Step 0 of `/analyze` and Phase 1 of `/sanitize` run `greenfield-tiers preflight`. The tool reports three conditions.

- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set. Claude Code then ignores the model of every dispatch.
- `CLAUDE_CODE_EFFORT_LEVEL` is set. Claude Code then ignores the effort of every dispatch.
- The Claude Code version is older than 2.1.292. That version added the per-call `effort` parameter. A version that the tool cannot read counts as this condition.

If the tool reports a condition, the orchestrator stops and asks the user. The user can end the run or continue. If the user continues, the orchestrator writes the condition and the answer to `provenance/audit-log.md`.

A dispatch can fail because the account has no access to a model. In that case, the orchestrator stops and asks the user for a substitute. The orchestrator never selects a weaker model on its own. If the user approves a substitute, the orchestrator runs `greenfield-tiers substitute`. The tool rewrites the tier row in the workspace copy and appends a comment line with the old values, the reason, and the time. The floor rule then uses the substitute, and the final summary prints it.

## Inline work moves to subagents

Today the orchestrator writes spec text in two places, on the session model.

- In `/analyze`, after a Gate 1 or Gate 2 failure, the orchestrator reads the report and edits the specs.
- In `/sanitize` Phase 5, the orchestrator reads each output file and gives a contamination verdict.

Both move to deep-tier subagents.

For Gate 1 and Gate 2, the orchestrator dispatches `greenfield:analyzer` with the new role `spec-remediator`. The prompt names the gate report and the affected spec files. The agent follows the skill that the original writer followed, and it changes only the sections that the report names. The first remediation round runs at the floor. Later rounds follow the raise rule.

For `/sanitize` Phase 5, the orchestrator dispatches `contamination-judge` in batches of four or five files. The prompt is the one that `/analyze` Layer 5 uses. The orchestrator reads the verdicts and sends failed files back to the sanitizer.

After this change, the orchestrator writes no spec text. It runs gate scripts, commits output, batches dispatches, and asks the user questions.

## Changes to `/sanitize`

- The `allowed-tools` list names `Agent` in place of `Task`.
- Phase 1 runs `greenfield-tiers preflight` and `greenfield-tiers init`.
- Each dispatch runs `lookup`, passes `model` and `effort`, and writes a dispatch record to `provenance/dispatch/` with the prefix `L5-`.
- Each sanitizer prompt starts with `Role: sanitizer.`
- Phase 5 dispatches `contamination-judge`, as described above.
- Phase 5 runs `greenfield-tiers floor` for Layer 5 before it reports a result.

## Documentation

- `README.md` gains a "Model tiers" section. The section holds the tier table, the role assignment, the row to change without Fable access, and the two environment variables that override the table.
- The role list in `README.md` gains `spec-remediator`.
- The pre-flight dispatch count in `commands/analyze.md` shows the tier beside each line. The text "(Haiku)" is removed.
- The pipeline overview in `commands/analyze.md` states that each dispatch takes its model and effort from the tier file.
- The Failure Handling table gains one row for a model that is not available.

## Tests

The plugin has no test suite today. This change adds two bash scripts under `scripts/`. Neither script calls a model.

`scripts/lint-tiers.sh` reads the plugin files and fails on drift.

- Every `Role:` name in `commands/analyze.md` and `commands/sanitize.md` has exactly one `role` row in `model-tiers.tsv`.
- Every `role` row has a dispatch prompt in one of the two commands.
- Every `role` row names a tier that has a `tier` row.
- Both agent definitions declare the model and effort of the `deep` tier.
- The tier table in `README.md` matches the `tier` rows.

`scripts/test-tiers.sh` runs `greenfield-tiers` against fixture workspaces under `tests/fixtures/`.

| Fixture | Expected result |
|---------|-----------------|
| Record at the floor | PASS |
| Record below the floor model | FAIL |
| Record below the floor effort | FAIL |
| Record with no `**Model:**` line | FAIL |
| Record above the floor, `**Raised:** no` | FAIL |
| Record above the floor, `**Raised:** yes: <reason>` | PASS |
| Session log with a model below the floor | FAIL |
| No session log | WARN |
| `lookup` with 0, 1, 2, and 5 steps for one role of each tier | The ladder values, capped at fable/xhigh |
| `lookup` for an unknown role | Nonzero exit status |
| `substitute`, then `floor` | The floor uses the substitute |
| Record below the floor that a later record supersedes | SKIP |
| Record without model lines that the baseline file lists | SKIP |
| Record whose prompt text holds a `**Model:**` line | The header decides the result |
| Tier file with spaces between fields and CRLF line ends | `lookup` prints the same values |

One manual run closes the work. Start `/analyze` from a Sonnet session on a small target and stop after Layer 2. Then make sure that each dispatch record names the tier values, and that each captured session log shows the same model. This run also proves that `bin/greenfield-tiers` is on the PATH.

## Files

| File | Change |
|------|--------|
| `model-tiers.tsv` | New. Tiers and role assignments. |
| `bin/greenfield-tiers` | New. The five subcommands. |
| `scripts/lint-tiers.sh` | New. Drift test. |
| `scripts/test-tiers.sh` | New. Fixture test. |
| `tests/fixtures/` | New. Fixture workspaces. |
| `agents/analyzer.md` | `model` and `effort` frontmatter. |
| `agents/sanitizer.md` | `model` and `effort` frontmatter. |
| `commands/analyze.md` | Preflight, dispatch protocol, raise rule, record lines, floor rule at seven gates, `spec-remediator`, session log path, pre-flight count, failure row. |
| `commands/sanitize.md` | The changes in "Changes to `/sanitize`". |
| `README.md` | "Model tiers" section and role list. |

## Facts from the Claude Code documentation

The design depends on these facts. Each was read on 2026-11-21.

- Plugin agents honor the `model` and `effort` frontmatter fields. Source: https://code.claude.com/docs/en/plugins/components.md
- The per-call `model` parameter of the Agent tool takes an alias and overrides the frontmatter. Source: https://code.claude.com/docs/en/sub-agents.md
- The per-call `effort` parameter overrides the frontmatter and needs version 2.1.292 or later. Source: https://code.claude.com/docs/en/sub-agents.md
- `CLAUDE_CODE_EFFORT_LEVEL` overrides every effort value. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` overrides every model value. Source: https://code.claude.com/docs/en/sub-agents.md
- A model that the `availableModels` configuration blocks is replaced by a fallback model, and the request does not fail. Source: https://code.claude.com/docs/en/model-config.md
- An effort level that a model does not support falls back to the highest supported level below it. Source: https://code.claude.com/docs/en/model-config.md
- Files in the `bin/` directory of an enabled plugin are on the PATH of the Bash tool. Source: https://code.claude.com/docs/en/plugins/components.md
- Subagent logs are stored at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. Source: https://code.claude.com/docs/en/sub-agents.md

One fact came from a local file and not from the documentation. Each assistant entry of a subagent log holds the model ID at `.message.model`.

## Not in this change

- The model and effort of the orchestrator stay those of the session. The orchestrator still decides inventory, batching, and domain groups. A later change can pin the orchestrator through the `model` and `effort` frontmatter of the command.
- Tier assignments do not change with the size of a module or a chunk.
- The gates do not compare the effort that a subagent ran on.
- `/sanitize` Phase 6 stays an orchestrator step.
- The skills do not change.
