-record(org_metrics_project_overview, {
    project_id :: integer(),
    project_name :: binary(),
    claimed_count :: integer(),
    released_count :: integer(),
    completed_count :: integer(),
    release_rate_percent :: gleam@option:option(integer()),
    pool_flow_ratio_percent :: gleam@option:option(integer())
}).
