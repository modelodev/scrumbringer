---
description: "Register minimal HITL approval/rejection and reflect it in run evidence. Usage: /awo-approve <workflow_id> <entity_id> approved|rejected [--run <run_id|latest>] [comment]"
---

# /awo-approve

Record a HITL decision for a gate/entity in runtime evidence.

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

## Rules

- Stay inside the current repo.
- Do not call the `awo` CLI from this slash command.
- Do not modify source workflow files.
- Emit envelope keys in the same order as shown in examples.
