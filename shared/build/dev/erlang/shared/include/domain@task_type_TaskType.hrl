-record(task_type, {
    id :: integer(),
    name :: binary(),
    icon :: binary(),
    capability_id :: gleam@option:option(integer())
}).
