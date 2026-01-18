-record(task, {
    id :: integer(),
    project_id :: integer(),
    type_id :: integer(),
    task_type :: domain@task_type:task_type_inline(),
    ongoing_by :: gleam@option:option(domain@task_status:ongoing_by()),
    title :: binary(),
    description :: gleam@option:option(binary()),
    priority :: integer(),
    status :: domain@task_status:task_status(),
    work_state :: domain@task_status:work_state(),
    created_by :: integer(),
    claimed_by :: gleam@option:option(integer()),
    claimed_at :: gleam@option:option(binary()),
    completed_at :: gleam@option:option(binary()),
    created_at :: binary(),
    version :: integer()
}).
