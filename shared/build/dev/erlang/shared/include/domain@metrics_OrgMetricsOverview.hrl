-record(org_metrics_overview, {
    window_days :: integer(),
    claimed_count :: integer(),
    released_count :: integer(),
    completed_count :: integer(),
    release_rate_percent :: gleam@option:option(integer()),
    pool_flow_ratio_percent :: gleam@option:option(integer()),
    time_to_first_claim_p50_ms :: gleam@option:option(integer()),
    time_to_first_claim_sample_size :: integer(),
    time_to_first_claim_buckets :: list(domain@metrics:org_metrics_bucket()),
    release_rate_buckets :: list(domain@metrics:org_metrics_bucket()),
    by_project :: list(domain@metrics:org_metrics_project_overview())
}).
