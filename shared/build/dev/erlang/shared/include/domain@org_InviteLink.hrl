-record(invite_link, {
    email :: binary(),
    token :: binary(),
    url_path :: binary(),
    state :: binary(),
    created_at :: binary(),
    used_at :: gleam@option:option(binary()),
    invalidated_at :: gleam@option:option(binary())
}).
