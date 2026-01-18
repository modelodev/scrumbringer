-record(active_task_payload, {
    active_task :: gleam@option:option(domain@task:active_task()),
    as_of :: binary()
}).
