-record(active_task, {
    task_id :: integer(),
    project_id :: integer(),
    started_at :: binary(),
    accumulated_s :: integer()
}).
