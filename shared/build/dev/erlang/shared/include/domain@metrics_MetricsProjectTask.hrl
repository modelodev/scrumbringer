-record(metrics_project_task, {
    task :: domain@task:task(),
    claim_count :: integer(),
    release_count :: integer(),
    complete_count :: integer(),
    first_claim_at :: gleam@option:option(binary())
}).
