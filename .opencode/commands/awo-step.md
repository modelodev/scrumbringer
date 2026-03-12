---
description: "Execute one compiled AWO step and keep run evidence coherent. Usage: /awo-step <workflow_id> <step_id> [context] [--run <run_id|latest>]"
---

# /awo-step

Execute one compiled step and update evidence under `.awo/runs/`.

## Required steps

1. Validate arguments: workflow id and step id are required; reject unknown workflow/step ids with `INVALID_INPUT`.
2. Resolve run id: use `--run <run_id|latest>` when provided; otherwise use `.awo/runs/index/opencode/<workflow_id>.breadcrumbs.json` (`latest_run`) or create `run_<unix_seconds>` if missing.
3. Validate dependencies using `.awo/generated/opencode/workflows/<workflow_id>/compiled_workflow.json`: every dependency must have a step-report with `status=ok|warning` in the selected run.
4. If dependencies are unmet, write/update `.awo/runs/<run_id>/steps/<step_id>.step-report.json` with `status=blocked` and `policy_outcome=fail`, then update `.awo/runs/<run_id>/run-envelope.json` (`status=blocked`, include the step report path, actionable `next_step`).
5. If dependencies are met, execute only `<step_id>` and write/update the same step-report with contractual core fields (`schema_version`, `run_id`, `workflow_id`, `workflow_version`, `target`, `step_id`, `status`, `policy_outcome`, `executive_summary`, `artifacts_in`, `artifacts_out`, `next_recommended`, `risks`, `started_at`, `ended_at`).
6. Keep evidence coherent: ensure `.awo/runs/<run_id>/run-envelope.json` exists, includes the step report path exactly once in `step_reports`, has coherent `status` (`ok|warning|blocked|failed`), and refresh `.awo/runs/index/opencode/<workflow_id>.breadcrumbs.json` (`latest_run=<run_id>`).
7. Emit exactly one deterministic JSON envelope to stdout with schema `awo.step_envelope/v1`.

## Context

$3

## JSON examples

```json
{"schema_version":"awo.step_envelope/v1","status":"ok","run_id":"run_20260306_100000","workflow_id":"$1","step_id":"$2","step_report":".awo/runs/run_20260306_100000/steps/$2.step-report.json","run_envelope":".awo/runs/run_20260306_100000/run-envelope.json","next_step":"Continue with next recommended step from step-report"}
```

```json
{"schema_version":"awo.step_envelope/v1","status":"blocked","run_id":"run_20260306_100000","workflow_id":"$1","step_id":"$2","error_code":"STEP_DEPENDENCY_BLOCKED","step_report":".awo/runs/run_20260306_100000/steps/$2.step-report.json","run_envelope":".awo/runs/run_20260306_100000/run-envelope.json","next_step":"Complete missing dependencies and re-run /awo-step $1 $2"}
```

```json
{"schema_version":"awo.step_envelope/v1","status":"failed","error_code":"INVALID_INPUT","message":"Usage: /awo-step <workflow_id> <step_id> [context] [--run <run_id|latest>]"}
```

## Rules

- Stay inside the current repo.
- Do not call the `awo` CLI from this slash command.
- Do not modify source workflow files.
- Emit envelope keys in the same order as shown in examples.
