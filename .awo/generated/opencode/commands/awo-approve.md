---
description: "Register minimal HITL approval/rejection and reflect it in run evidence. Usage: /awo-approve <workflow_id> <entity_id> approved|rejected [--run <run_id|latest>] [comment]"
agent: "awo-runtime"
subtask: true
execution_mode: "isolated-runtime"
runtime_command: true
mutates_state: true
requires_context: false
---

# /awo-approve

Record a HITL decision for a gate/entity in runtime evidence.

## Command surface

- Signature: `/awo-approve <workflow_id> <entity_id> approved|rejected [--run <run_id|latest>] [comment]`
- Raw arguments: `$ARGUMENTS`
- Required `$1`: workflow id
- Required `$2`: entity id
- Required `$3`: decision (`approved|rejected`)
- Optional `--run <run_id|latest>` and optional trailing comment are parsed from `$ARGUMENTS`

## Runtime executor contract

Run this command as an isolated runtime subtask with agent `awo-runtime`. Do not inherit the parent session mode.

## Required steps

1. Validate input: `<workflow_id> <entity_id> approved|rejected` is mandatory; invalid action must return `INVALID_INPUT`.
2. Resolve run id from `--run <run_id|latest>` or `.awo/runs/index/opencode/<workflow_id>.breadcrumbs.json` (`latest_run`); if no run is found return `RUN_NOT_FOUND`.
3. Write/update `.awo/runs/<run_id>/approvals/<entity_id>.approval-record.json` with contractual core fields: `schema_version`, `run_id`, `workflow_id`, `target`, `entity_id`, `decision`, `comment`, `recorded_at`.
4. Reflect decision in `.awo/runs/<run_id>/run-envelope.json`: keep previous run timing fields, set `status=blocked` on rejection, keep or raise to `warning` on approval when status was blocked, and set actionable `next_step`.
5. Keep evidence coherent: include approval record path exactly once in `approval_records` (create field when absent), preserve existing `step_reports`, and refresh breadcrumbs latest run for the workflow.
6. Emit exactly one deterministic JSON envelope to stdout with schema `awo.approval_envelope/v1`.

## Context

$5

## JSON examples

```json
{"schema_version":"awo.approval_envelope/v1","status":"ok","run_id":"run_20260306_100000","workflow_id":"$1","entity_id":"$2","decision":"$3","approval_record":".awo/runs/run_20260306_100000/approvals/$2.approval-record.json","run_envelope":".awo/runs/run_20260306_100000/run-envelope.json","next_step":"Re-run /awo-run $1 (new run_id)"}
```

```json
{"schema_version":"awo.approval_envelope/v1","status":"failed","error_code":"RUN_NOT_FOUND","message":"No matching run found for /awo-approve"}
```

```json
{"schema_version":"awo.approval_envelope/v1","status":"failed","error_code":"INVALID_INPUT","message":"Usage: /awo-approve <workflow_id> <entity_id> approved|rejected [--run <run_id|latest>] [comment]"}
```

```json
{"schema_version":"awo.approval_envelope/v1","status":"failed","workflow_id":"$1","entity_id":"$2","error_code":"RUNTIME_COMMAND_UNAVAILABLE_IN_SESSION","message":"The isolated runtime subtask could not be started for /awo-approve"}
```

## Rules

- Stay inside the current repo.
- Prefer execution over planning; this is a runtime entrypoint, not a planning prompt.
- Do not call the `awo` CLI from this slash command.
- Do not modify source workflow files.
- Emit envelope keys in the same order as shown in examples.
