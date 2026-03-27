---
description: "Execute an AWO workflow and emit H0 runtime evidence. Usage: /awo-run <workflow_id> [context]"
agent: "awo-runtime"
subtask: true
execution_mode: "isolated-runtime"
runtime_command: true
mutates_state: true
requires_context: false
---

# /awo-run

Execute workflow `$1` from compiled runtime assets and write evidence under `.awo/runs/`.

## Execution mode

This is a native OpenCode slash command. Do not invoke it via bash or from a terminal shell.
Correct: `/awo-run <workflow_id>` typed in the OpenCode session.
Incorrect: running `opencode run --command awo-run ...` from a shell or scripting it outside a live session.

## Command surface

- Signature: `/awo-run <workflow_id> [context]`
- Raw arguments: `$ARGUMENTS`
- Required `$1`: workflow id
- Optional context: any remaining free text after `<workflow_id>`
- Missing context is valid and must not trigger a usage error

## Runtime executor contract

Run this command as an isolated runtime subtask with agent `awo-runtime`. Do not inherit plan-only behavior from the parent session.

## Required steps

1. Validate arguments from `$ARGUMENTS`: `$1` is required, context is optional, and missing context is never `INVALID_INPUT`.
2. Read `.awo/generated/opencode/manifest.json` and `.awo/generated/opencode/workflows/$1/compiled_workflow.json`.
3. Create a new run id using the format `run_<unix_seconds>`.
3b. Before creating a new run, check for an existing failed or blocked run for this workflow in `.awo/runs/index/opencode/$1.breadcrumbs.json`. If found, read the run envelope, identify completed `ok` steps, skip them, continue from the first incomplete or failed step, reuse the existing `run_id`, and update the existing `run-envelope.json` and step-reports. Otherwise create a new run as normal.
4. Execute compiled steps in dependency order. For each step:
   a. **BEFORE starting any work on the step**, record the current UTC timestamp as `started_at`.
   b. Execute the step work.
   c. **AFTER finishing all work on the step**, record the current UTC timestamp as `ended_at`.
   d. Write the step-report with the real `started_at` and `ended_at` values captured in (a) and (c).
   This timing contract is critical: `started_at` must reflect when the step began, not when the report was written.
5. For each executed step, write `.awo/runs/<run_id>/steps/<step_id>.step-report.json` with contractual core fields: `schema_version`, `run_id`, `workflow_id`, `workflow_version`, `target`, `step_id`, `status`, `policy_outcome`, `executive_summary`, `artifacts_in`, `artifacts_out`, `next_recommended`, `risks`, `started_at`, `ended_at`, and `budget_used` (`tokens` int >= 0, `cost_usd` number >= 0).
   Additionally, include these observability fields when available:
   - `declared_skill_refs`: list of skill file paths loaded for this step (from compiled_workflow.json `runtime_skill` and `skill_refs`)
   - `observed_skill_refs`: list of skill/reference files actually read during execution
   - `commands_run`: list of shell commands executed, each as `{"cmd": "...", "workdir": "...", "result": "ok|error"}`
   - `artifacts_materialized`: list of file paths created or modified by this step
   - `interruption_events`: list of interruptions, each as `{"kind": "...", "severity": "info|warning|error"}`
6. After the run completes, write `.awo/runs/<run_id>/run-envelope.json` with contractual core fields: `schema_version`, `run_id`, `workflow_id`, `workflow_version`, `target`, `status`, `started_at`, `ended_at`, `step_reports`, `next_step`, `execution_mode` (set to `native_slash_command` for all native executions), and run-level budget telemetry `budget_run_level` (`tokens_total`, `cost_usd_total`, `quality`=`target_native|adapter_estimated`).
>>>>>>> cca063aa7481223e5ba0e9ab360fc53ba1bb59de
7. Write `.awo/runs/index/opencode/$1.breadcrumbs.json` with JSON containing at least `latest_run` set to the new run id.
8. Use RFC3339 UTC timestamps and coherent envelopes: success => run `status=ok`, failure/block => run `status=failed|blocked` with actionable `next_step`.

## Context

Use `$2` only when it is present. Treat an empty `$2` as valid no-context execution.

## JSON examples

```json
{"schema_version":"awo.run_envelope/v1","run_id":"run_20260306_100000","workflow_id":"$1","workflow_version":"1.0.0","target":"opencode","status":"ok","execution_mode":"native_slash_command","started_at":"2026-03-06T10:00:00Z","ended_at":"2026-03-06T10:01:00Z","step_reports":[".awo/runs/run_20260306_100000/steps/draft.step-report.json"],"budget_run_level":{"tokens_total":1200,"cost_usd_total":0.036,"quality":"target_native"},"next_step":"Run /awo-step $1 <step_id> for spot checks"}
```

```json
{"schema_version":"awo.step_report/v1","run_id":"run_20260306_100000","workflow_id":"$1","workflow_version":"1.0.0","target":"opencode","step_id":"draft","status":"ok","policy_outcome":"pass","executive_summary":"Draft completed","artifacts_in":[],"artifacts_out":[],"next_recommended":["review"],"risks":[],"budget_used":{"tokens":1200,"cost_usd":0.036},"started_at":"2026-03-06T10:00:00Z","ended_at":"2026-03-06T10:01:00Z"}
```

```json
{"schema_version":"awo.run_envelope/v1","run_id":"run_20260306_100000","workflow_id":"$1","workflow_version":"1.0.0","target":"opencode","status":"failed","started_at":"2026-03-06T10:00:00Z","ended_at":"2026-03-06T10:01:00Z","step_reports":[".awo/runs/run_20260306_100000/steps/draft.step-report.json"],"next_step":"Inspect failed step-report and re-run /awo-run $1"}
```

```json
{"schema_version":"awo.run_envelope/v1","workflow_id":"$1","target":"opencode","status":"failed","error_code":"RUNTIME_COMMAND_UNAVAILABLE_IN_SESSION","message":"The isolated runtime subtask could not be started for /awo-run","next_step":"Apply generated runtime assets and retry /awo-run $1"}
```

## Rules

- Stay inside the current repo.
- Prefer execution over planning; this is a runtime entrypoint, not a planning prompt.
- Do not call the `awo` CLI from this slash command.
- Do not modify source workflow files.
- Always emit the evidence files before finishing.
- Always set `execution_mode` to `native_slash_command` in the emitted `run-envelope.json`.
