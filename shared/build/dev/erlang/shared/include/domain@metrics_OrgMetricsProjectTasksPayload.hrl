-record(org_metrics_project_tasks_payload, {
    window_days :: integer(),
    project_id :: integer(),
    tasks :: list(domain@metrics:metrics_project_task())
}).
