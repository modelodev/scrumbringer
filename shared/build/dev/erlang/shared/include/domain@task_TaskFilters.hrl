-record(task_filters, {
    status :: gleam@option:option(binary()),
    type_id :: gleam@option:option(integer()),
    capability_id :: gleam@option:option(integer()),
    q :: gleam@option:option(binary())
}).
