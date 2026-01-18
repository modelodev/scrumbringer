{application, shared, [
    {vsn, "0.1.0"},
    {applications, [gleam_stdlib,
                    gleeunit]},
    {description, ""},
    {modules, [domain@api_error,
               domain@capability,
               domain@metrics,
               domain@org,
               domain@project,
               domain@task,
               domain@task_status,
               domain@task_type]},
    {registered, []}
]}.
