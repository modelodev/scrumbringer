//// This module contains the code to run the sql queries defined in
//// `./src/scrumbringer_server/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `capabilities_create` query
/// defined in `./src/scrumbringer_server/sql/capabilities_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesCreateRow {
  CapabilitiesCreateRow(id: Int, org_id: Int, name: String, created_at: String)
}

/// name: create_capability
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(CapabilitiesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(CapabilitiesCreateRow(id:, org_id:, name:, created_at:))
  }

  "-- name: create_capability
insert into capabilities (org_id, name)
values ($1, $2)
returning
  id,
  org_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `capabilities_is_in_org` query
/// defined in `./src/scrumbringer_server/sql/capabilities_is_in_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesIsInOrgRow {
  CapabilitiesIsInOrgRow(ok: Bool)
}

/// name: capability_is_in_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_is_in_org(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(CapabilitiesIsInOrgRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.bool)
    decode.success(CapabilitiesIsInOrgRow(ok:))
  }

  "-- name: capability_is_in_org
select exists(
  select 1
  from capabilities
  where id = $1
    and org_id = $2
) as ok;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `capabilities_list` query
/// defined in `./src/scrumbringer_server/sql/capabilities_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CapabilitiesListRow {
  CapabilitiesListRow(id: Int, org_id: Int, name: String, created_at: String)
}

/// name: list_capabilities_for_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn capabilities_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(CapabilitiesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(CapabilitiesListRow(id:, org_id:, name:, created_at:))
  }

  "-- name: list_capabilities_for_org
select
  id,
  org_id,
  name,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from capabilities
where org_id = $1
order by name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cards_create` query
/// defined in `./src/scrumbringer_server/sql/cards_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CardsCreateRow {
  CardsCreateRow(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    created_by: Int,
    created_at: String,
  )
}

/// name: create_card
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(CardsCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.string)
    use created_by <- decode.field(4, decode.int)
    use created_at <- decode.field(5, decode.string)
    decode.success(CardsCreateRow(
      id:,
      project_id:,
      title:,
      description:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: create_card
INSERT INTO cards (project_id, title, description, created_by)
VALUES ($1, $2, $3, $4)
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// name: delete_card
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_delete(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- name: delete_card
DELETE FROM cards WHERE id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cards_get` query
/// defined in `./src/scrumbringer_server/sql/cards_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CardsGetRow {
  CardsGetRow(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    created_by: Int,
    created_at: String,
    task_count: Int,
    completed_count: Int,
    available_count: Int,
  )
}

/// name: get_card
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_get(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(CardsGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.string)
    use created_by <- decode.field(4, decode.int)
    use created_at <- decode.field(5, decode.string)
    use task_count <- decode.field(6, decode.int)
    use completed_count <- decode.field(7, decode.int)
    use available_count <- decode.field(8, decode.int)
    decode.success(CardsGetRow(
      id:,
      project_id:,
      title:,
      description:,
      created_by:,
      created_at:,
      task_count:,
      completed_count:,
      available_count:,
    ))
  }

  "-- name: get_card
SELECT
    c.id,
    c.project_id,
    c.title,
    coalesce(c.description, '') as description,
    c.created_by,
    to_char(c.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    COUNT(t.id)::int AS task_count,
    COUNT(t.id) FILTER (WHERE t.status = 'completed')::int AS completed_count,
    COUNT(t.id) FILTER (WHERE t.status = 'available')::int AS available_count
FROM cards c
LEFT JOIN tasks t ON t.card_id = c.id
WHERE c.id = $1
GROUP BY c.id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cards_list` query
/// defined in `./src/scrumbringer_server/sql/cards_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CardsListRow {
  CardsListRow(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    created_by: Int,
    created_at: String,
    task_count: Int,
    completed_count: Int,
    available_count: Int,
  )
}

/// name: list_cards_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(CardsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.string)
    use created_by <- decode.field(4, decode.int)
    use created_at <- decode.field(5, decode.string)
    use task_count <- decode.field(6, decode.int)
    use completed_count <- decode.field(7, decode.int)
    use available_count <- decode.field(8, decode.int)
    decode.success(CardsListRow(
      id:,
      project_id:,
      title:,
      description:,
      created_by:,
      created_at:,
      task_count:,
      completed_count:,
      available_count:,
    ))
  }

  "-- name: list_cards_for_project
SELECT
    c.id,
    c.project_id,
    c.title,
    coalesce(c.description, '') as description,
    c.created_by,
    to_char(c.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    COUNT(t.id)::int AS task_count,
    COUNT(t.id) FILTER (WHERE t.status = 'completed')::int AS completed_count,
    COUNT(t.id) FILTER (WHERE t.status = 'available')::int AS available_count
FROM cards c
LEFT JOIN tasks t ON t.card_id = c.id
WHERE c.project_id = $1
GROUP BY c.id
ORDER BY c.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cards_task_count` query
/// defined in `./src/scrumbringer_server/sql/cards_task_count.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CardsTaskCountRow {
  CardsTaskCountRow(task_count: Int)
}

/// name: count_tasks_for_card
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_task_count(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(CardsTaskCountRow), pog.QueryError) {
  let decoder = {
    use task_count <- decode.field(0, decode.int)
    decode.success(CardsTaskCountRow(task_count:))
  }

  "-- name: count_tasks_for_card
SELECT COUNT(*)::int as task_count
FROM tasks
WHERE card_id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `cards_update` query
/// defined in `./src/scrumbringer_server/sql/cards_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CardsUpdateRow {
  CardsUpdateRow(
    id: Int,
    project_id: Int,
    title: String,
    description: String,
    created_by: Int,
    created_at: String,
  )
}

/// name: update_card
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn cards_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(CardsUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use description <- decode.field(3, decode.string)
    use created_by <- decode.field(4, decode.int)
    use created_at <- decode.field(5, decode.string)
    decode.success(CardsUpdateRow(
      id:,
      project_id:,
      title:,
      description:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: update_card
UPDATE cards
SET title = $2, description = $3
WHERE id = $1
RETURNING
    id,
    project_id,
    title,
    coalesce(description, '') as description,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `engine_get_project_name` query
/// defined in `./src/scrumbringer_server/sql/engine_get_project_name.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EngineGetProjectNameRow {
  EngineGetProjectNameRow(name: String)
}

/// name: engine_get_project_name
/// Get project name for variable substitution.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn engine_get_project_name(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(EngineGetProjectNameRow), pog.QueryError) {
  let decoder = {
    use name <- decode.field(0, decode.string)
    decode.success(EngineGetProjectNameRow(name:))
  }

  "-- name: engine_get_project_name
-- Get project name for variable substitution.
select name from projects where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `engine_get_user_name` query
/// defined in `./src/scrumbringer_server/sql/engine_get_user_name.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type EngineGetUserNameRow {
  EngineGetUserNameRow(display_name: String)
}

/// name: engine_get_user_name
/// Get user email for variable substitution.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn engine_get_user_name(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(EngineGetUserNameRow), pog.QueryError) {
  let decoder = {
    use display_name <- decode.field(0, decode.string)
    decode.success(EngineGetUserNameRow(display_name:))
  }

  "-- name: engine_get_user_name
-- Get user email for variable substitution.
select email as display_name from users where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_my` query
/// defined in `./src/scrumbringer_server/sql/metrics_my.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsMyRow {
  MetricsMyRow(claimed_count: Int, released_count: Int, completed_count: Int)
}

/// name: metrics_my
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_my(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsMyRow), pog.QueryError) {
  let decoder = {
    use claimed_count <- decode.field(0, decode.int)
    use released_count <- decode.field(1, decode.int)
    use completed_count <- decode.field(2, decode.int)
    decode.success(MetricsMyRow(
      claimed_count:,
      released_count:,
      completed_count:,
    ))
  }

  "-- name: metrics_my
select
  coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
  coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as released_count,
  coalesce(sum(case when event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
from task_events
where actor_user_id = $1
  and created_at >= now() - ($2 || ' days')::interval;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_org_overview` query
/// defined in `./src/scrumbringer_server/sql/metrics_org_overview.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsOrgOverviewRow {
  MetricsOrgOverviewRow(
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
  )
}

/// name: metrics_org_overview
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_org_overview(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsOrgOverviewRow), pog.QueryError) {
  let decoder = {
    use claimed_count <- decode.field(0, decode.int)
    use released_count <- decode.field(1, decode.int)
    use completed_count <- decode.field(2, decode.int)
    decode.success(MetricsOrgOverviewRow(
      claimed_count:,
      released_count:,
      completed_count:,
    ))
  }

  "-- name: metrics_org_overview
select
  coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
  coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as released_count,
  coalesce(sum(case when event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
from task_events
where org_id = $1
  and created_at >= now() - ($2 || ' days')::interval;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_org_overview_by_project` query
/// defined in `./src/scrumbringer_server/sql/metrics_org_overview_by_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsOrgOverviewByProjectRow {
  MetricsOrgOverviewByProjectRow(
    project_id: Int,
    project_name: String,
    claimed_count: Int,
    released_count: Int,
    completed_count: Int,
  )
}

/// name: metrics_org_overview_by_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_org_overview_by_project(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsOrgOverviewByProjectRow), pog.QueryError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    use project_name <- decode.field(1, decode.string)
    use claimed_count <- decode.field(2, decode.int)
    use released_count <- decode.field(3, decode.int)
    use completed_count <- decode.field(4, decode.int)
    decode.success(MetricsOrgOverviewByProjectRow(
      project_id:,
      project_name:,
      claimed_count:,
      released_count:,
      completed_count:,
    ))
  }

  "-- name: metrics_org_overview_by_project
select
  p.id as project_id,
  p.name as project_name,
  coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
  coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as released_count,
  coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
from projects p
left join task_events e
  on e.project_id = p.id
  and e.created_at >= now() - ($2 || ' days')::interval
where p.org_id = $1
group by p.id, p.name
order by p.name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_project_tasks` query
/// defined in `./src/scrumbringer_server/sql/metrics_project_tasks.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsProjectTasksRow {
  MetricsProjectTasksRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    title: String,
    description: String,
    priority: Int,
    status: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    claim_count: Int,
    release_count: Int,
    complete_count: Int,
    first_claim_at: String,
  )
}

/// name: metrics_project_tasks
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_project_tasks(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsProjectTasksRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use type_name <- decode.field(3, decode.string)
    use type_icon <- decode.field(4, decode.string)
    use title <- decode.field(5, decode.string)
    use description <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use status <- decode.field(8, decode.string)
    use is_ongoing <- decode.field(9, decode.bool)
    use ongoing_by_user_id <- decode.field(10, decode.int)
    use created_by <- decode.field(11, decode.int)
    use claimed_by <- decode.field(12, decode.int)
    use claimed_at <- decode.field(13, decode.string)
    use completed_at <- decode.field(14, decode.string)
    use created_at <- decode.field(15, decode.string)
    use version <- decode.field(16, decode.int)
    use claim_count <- decode.field(17, decode.int)
    use release_count <- decode.field(18, decode.int)
    use complete_count <- decode.field(19, decode.int)
    use first_claim_at <- decode.field(20, decode.string)
    decode.success(MetricsProjectTasksRow(
      id:,
      project_id:,
      type_id:,
      type_name:,
      type_icon:,
      title:,
      description:,
      priority:,
      status:,
      is_ongoing:,
      ongoing_by_user_id:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      claim_count:,
      release_count:,
      complete_count:,
      first_claim_at:,
    ))
  }

  "-- name: metrics_project_tasks
with task_scope as (
  select
    t.id,
    t.project_id,
    t.type_id,
    tt.name as type_name,
    tt.icon as type_icon,
    t.title,
    coalesce(t.description, '') as description,
    t.priority,
     t.status,
     (
       t.status = 'claimed'
       and exists(
         select 1
         from user_task_work_session ws
         where ws.task_id = t.id and ws.ended_at is null
       )
     ) as is_ongoing,
     coalesce((
       select ws.user_id
       from user_task_work_session ws
       where ws.task_id = t.id and ws.ended_at is null
       order by ws.started_at desc
       limit 1
     ), 0) as ongoing_by_user_id,
     t.created_by,

    coalesce(t.claimed_by, 0) as claimed_by,
    coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    t.version
  from tasks t
  join task_types tt on tt.id = t.type_id
  where t.project_id = $1
), event_counts as (
  select
    e.task_id,
    coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claim_count,
    coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as release_count,
    coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as complete_count,
    coalesce(min(case when e.event_type = 'task_claimed' then e.created_at else null end), null) as first_claim_at
  from task_events e
  where e.project_id = $1
    and e.created_at >= now() - ($2 || ' days')::interval
  group by e.task_id
)
select
  ts.id,
  ts.project_id,
  ts.type_id,
  ts.type_name,
  ts.type_icon,
  ts.title,
  ts.description,
  ts.priority,
  ts.status,
  ts.is_ongoing,
  ts.ongoing_by_user_id,
  ts.created_by,
  ts.claimed_by,
  ts.claimed_at,
  ts.completed_at,
  ts.created_at,
  ts.version,
  coalesce(ec.claim_count, 0) as claim_count,
  coalesce(ec.release_count, 0) as release_count,
  coalesce(ec.complete_count, 0) as complete_count,
  coalesce(to_char(ec.first_claim_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as first_claim_at
from task_scope ts
left join event_counts ec on ec.task_id = ts.id
order by ts.created_at desc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_release_rate_buckets` query
/// defined in `./src/scrumbringer_server/sql/metrics_release_rate_buckets.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsReleaseRateBucketsRow {
  MetricsReleaseRateBucketsRow(bucket: String, count: Int)
}

/// name: metrics_release_rate_buckets
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_release_rate_buckets(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsReleaseRateBucketsRow), pog.QueryError) {
  let decoder = {
    use bucket <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(MetricsReleaseRateBucketsRow(bucket:, count:))
  }

  "-- name: metrics_release_rate_buckets
with per_user as (
  select
    actor_user_id,
    coalesce(sum(case when event_type = 'task_claimed' then 1 else 0 end), 0) as claims,
    coalesce(sum(case when event_type = 'task_released' then 1 else 0 end), 0) as releases
  from task_events
  where org_id = $1
    and created_at >= now() - ($2 || ' days')::interval
  group by actor_user_id
), rates as (
  select
    actor_user_id,
    case
      when claims = 0 then null
      else releases::numeric / claims::numeric
    end as rate
  from per_user
)
select bucket, count::int as count
from (
  select
    case
      when rate is null then 'no-claims'
      when rate = 0 then '0%'
      when rate <= 0.15 then '0-15%'
      when rate <= 0.50 then '15-50%'
      else '>50%'
    end as bucket,
    case
      when rate is null then 5
      when rate = 0 then 1
      when rate <= 0.15 then 2
      when rate <= 0.50 then 3
      else 4
    end as sort_key,
    count(*) as count
  from rates
  group by bucket, sort_key
) b
order by sort_key;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_time_to_first_claim_buckets` query
/// defined in `./src/scrumbringer_server/sql/metrics_time_to_first_claim_buckets.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsTimeToFirstClaimBucketsRow {
  MetricsTimeToFirstClaimBucketsRow(bucket: String, count: Int)
}

/// name: metrics_time_to_first_claim_buckets
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_time_to_first_claim_buckets(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsTimeToFirstClaimBucketsRow), pog.QueryError) {
  let decoder = {
    use bucket <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(MetricsTimeToFirstClaimBucketsRow(bucket:, count:))
  }

  "-- name: metrics_time_to_first_claim_buckets
with first_claim as (
  select
    actor_user_id,
    min(created_at) as first_claim_at
  from task_events
  where org_id = $1
    and event_type = 'task_claimed'
    and created_at >= now() - ($2 || ' days')::interval
  group by actor_user_id
), deltas as (
  select
    u.id as user_id,
    extract(epoch from (fc.first_claim_at - u.first_login_at)) * 1000 as delta_ms
  from first_claim fc
  join users u on u.id = fc.actor_user_id
  where u.first_login_at is not null
    and (fc.first_claim_at - u.first_login_at) >= interval '0 seconds'
),
buckets as (
  select
    case
      when delta_ms <= 3600000 then '0-1h'
      when delta_ms <= 14400000 then '1-4h'
      when delta_ms <= 86400000 then '4-24h'
      else '>24h'
    end as bucket,
    case
      when delta_ms <= 3600000 then 1
      when delta_ms <= 14400000 then 2
      when delta_ms <= 86400000 then 3
      else 4
    end as sort_key
  from deltas
)
select bucket, count(*)::int as count
from buckets
group by bucket, sort_key
order by sort_key;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `metrics_time_to_first_claim_p50_ms` query
/// defined in `./src/scrumbringer_server/sql/metrics_time_to_first_claim_p50_ms.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type MetricsTimeToFirstClaimP50MsRow {
  MetricsTimeToFirstClaimP50MsRow(p50_ms: Int, sample_size: Int)
}

/// name: metrics_time_to_first_claim_p50_ms
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn metrics_time_to_first_claim_p50_ms(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(MetricsTimeToFirstClaimP50MsRow), pog.QueryError) {
  let decoder = {
    use p50_ms <- decode.field(0, decode.int)
    use sample_size <- decode.field(1, decode.int)
    decode.success(MetricsTimeToFirstClaimP50MsRow(p50_ms:, sample_size:))
  }

  "-- name: metrics_time_to_first_claim_p50_ms
with first_claim as (
  select
    actor_user_id,
    min(created_at) as first_claim_at
  from task_events
  where org_id = $1
    and event_type = 'task_claimed'
    and created_at >= now() - ($2 || ' days')::interval
  group by actor_user_id
), deltas as (
  select
    extract(epoch from (fc.first_claim_at - u.first_login_at)) * 1000 as delta_ms
  from first_claim fc
  join users u on u.id = fc.actor_user_id
  where u.first_login_at is not null
    and (fc.first_claim_at - u.first_login_at) >= interval '0 seconds'
)
select
  coalesce(
    percentile_disc(0.5) within group (order by delta_ms)::bigint,
    0
  ) as p50_ms,
  count(*)::int as sample_size
from deltas;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invite_links_list` query
/// defined in `./src/scrumbringer_server/sql/org_invite_links_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInviteLinksListRow {
  OrgInviteLinksListRow(
    email: String,
    token: String,
    created_at: String,
    used_at: String,
    invalidated_at: String,
    state: String,
  )
}

/// name: list_org_invite_links
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invite_links_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(OrgInviteLinksListRow), pog.QueryError) {
  let decoder = {
    use email <- decode.field(0, decode.string)
    use token <- decode.field(1, decode.string)
    use created_at <- decode.field(2, decode.string)
    use used_at <- decode.field(3, decode.string)
    use invalidated_at <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    decode.success(OrgInviteLinksListRow(
      email:,
      token:,
      created_at:,
      used_at:,
      invalidated_at:,
      state:,
    ))
  }

  "-- name: list_org_invite_links
select
  email,
  token,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as invalidated_at,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state
from org_invite_links
where org_id = $1
order by email asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invite_links_upsert` query
/// defined in `./src/scrumbringer_server/sql/org_invite_links_upsert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInviteLinksUpsertRow {
  OrgInviteLinksUpsertRow(
    email: String,
    token: String,
    created_at: String,
    used_at: String,
    invalidated_at: String,
    state: String,
  )
}

/// name: upsert_org_invite_link
/// Invalidate any active invite link for email and create a new one.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invite_links_upsert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(OrgInviteLinksUpsertRow), pog.QueryError) {
  let decoder = {
    use email <- decode.field(0, decode.string)
    use token <- decode.field(1, decode.string)
    use created_at <- decode.field(2, decode.string)
    use used_at <- decode.field(3, decode.string)
    use invalidated_at <- decode.field(4, decode.string)
    use state <- decode.field(5, decode.string)
    decode.success(OrgInviteLinksUpsertRow(
      email:,
      token:,
      created_at:,
      used_at:,
      invalidated_at:,
      state:,
    ))
  }

  "-- name: upsert_org_invite_link
-- Invalidate any active invite link for email and create a new one.
with invalidated as (
  update org_invite_links
  set invalidated_at = now()
  where org_id = $1
    and email = $2
    and used_at is null
    and invalidated_at is null
  returning 1
),
inserted as (
  insert into org_invite_links (org_id, email, token, created_by)
  values ($1, $2, $3, $4)
  returning email, token, created_at, used_at, invalidated_at
)
select
  email,
  token,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(to_char(used_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as used_at,
  coalesce(to_char(invalidated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as invalidated_at,
  case
    when used_at is not null then 'used'
    when invalidated_at is not null then 'invalidated'
    else 'active'
  end as state
from inserted
where (select count(*) from invalidated) >= 0;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_invites` query
/// defined in `./src/scrumbringer_server/sql/org_invites.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgInvitesRow {
  OrgInvitesRow(code: String, created_at: String, expires_at: String)
}

/// name: create_org_invite
/// Insert a new org invite and return the API-facing fields.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_invites(
  db: pog.Connection,
  arg_1: String,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
) -> Result(pog.Returned(OrgInvitesRow), pog.QueryError) {
  let decoder = {
    use code <- decode.field(0, decode.string)
    use created_at <- decode.field(1, decode.string)
    use expires_at <- decode.field(2, decode.string)
    decode.success(OrgInvitesRow(code:, created_at:, expires_at:))
  }

  "-- name: create_org_invite
-- Insert a new org invite and return the API-facing fields.
insert into org_invites (code, org_id, created_by, expires_at)
values ($1, $2, $3, now() + (($4::int) * interval '1 hour'))
returning
  code,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  to_char(expires_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as expires_at;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `org_users_list` query
/// defined in `./src/scrumbringer_server/sql/org_users_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type OrgUsersListRow {
  OrgUsersListRow(id: Int, email: String, org_role: String, created_at: String)
}

/// name: list_org_users
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn org_users_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
) -> Result(pog.Returned(OrgUsersListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use email <- decode.field(1, decode.string)
    use org_role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(OrgUsersListRow(id:, email:, org_role:, created_at:))
  }

  "-- name: list_org_users
select
  id,
  email,
  org_role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from users
where org_id = $1
  and ($2 = '' or email ilike ('%' || $2 || '%'))
order by email asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `ping` query
/// defined in `./src/scrumbringer_server/sql/ping.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PingRow {
  PingRow(ok: Int)
}

/// Simple query used to verify Squirrel generation
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn ping(
  db: pog.Connection,
) -> Result(pog.Returned(PingRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.int)
    decode.success(PingRow(ok:))
  }

  "-- Simple query used to verify Squirrel generation
select 1 as ok;
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_insert` query
/// defined in `./src/scrumbringer_server/sql/project_members_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersInsertRow {
  ProjectMembersInsertRow(
    project_id: Int,
    user_id: Int,
    role: String,
    created_at: String,
  )
}

/// name: insert_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_insert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
) -> Result(pog.Returned(ProjectMembersInsertRow), pog.QueryError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(ProjectMembersInsertRow(
      project_id:,
      user_id:,
      role:,
      created_at:,
    ))
  }

  "-- name: insert_project_member
insert into project_members (project_id, user_id, role)
values ($1, $2, $3)
returning
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_is_admin` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_admin.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsAdminRow {
  ProjectMembersIsAdminRow(is_admin: Bool)
}

/// name: is_project_admin
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_admin(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsAdminRow), pog.QueryError) {
  let decoder = {
    use is_admin <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsAdminRow(is_admin:))
  }

  "-- name: is_project_admin
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
    and role = 'admin'
) as is_admin;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_is_any_admin_in_org` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_any_admin_in_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsAnyAdminInOrgRow {
  ProjectMembersIsAnyAdminInOrgRow(is_admin: Bool)
}

/// name: is_any_project_admin_in_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_any_admin_in_org(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsAnyAdminInOrgRow), pog.QueryError) {
  let decoder = {
    use is_admin <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsAnyAdminInOrgRow(is_admin:))
  }

  "-- name: is_any_project_admin_in_org
select exists(
  select 1
  from project_members pm
  join projects p on p.id = pm.project_id
  where pm.user_id = $1
    and pm.role = 'admin'
    and p.org_id = $2
) as is_admin;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_is_member` query
/// defined in `./src/scrumbringer_server/sql/project_members_is_member.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersIsMemberRow {
  ProjectMembersIsMemberRow(is_member: Bool)
}

/// name: is_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_is_member(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersIsMemberRow), pog.QueryError) {
  let decoder = {
    use is_member <- decode.field(0, decode.bool)
    decode.success(ProjectMembersIsMemberRow(is_member:))
  }

  "-- name: is_project_member
select exists(
  select 1
  from project_members
  where project_id = $1
    and user_id = $2
) as is_member;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_list` query
/// defined in `./src/scrumbringer_server/sql/project_members_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersListRow {
  ProjectMembersListRow(
    project_id: Int,
    user_id: Int,
    role: String,
    created_at: String,
  )
}

/// name: list_project_members
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectMembersListRow), pog.QueryError) {
  let decoder = {
    use project_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use role <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    decode.success(ProjectMembersListRow(
      project_id:,
      user_id:,
      role:,
      created_at:,
    ))
  }

  "-- name: list_project_members
select
  project_id,
  user_id,
  role,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from project_members
where project_id = $1
order by user_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `project_members_remove` query
/// defined in `./src/scrumbringer_server/sql/project_members_remove.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectMembersRemoveRow {
  ProjectMembersRemoveRow(target_role: String, admin_count: Int, removed: Bool)
}

/// name: remove_project_member
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn project_members_remove(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(ProjectMembersRemoveRow), pog.QueryError) {
  let decoder = {
    use target_role <- decode.field(0, decode.string)
    use admin_count <- decode.field(1, decode.int)
    use removed <- decode.field(2, decode.bool)
    decode.success(ProjectMembersRemoveRow(target_role:, admin_count:, removed:))
  }

  "-- name: remove_project_member
with
  target as (
    select role
    from project_members
    where project_id = $1
      and user_id = $2
  ), admin_count as (
    select count(*)::int as count
    from project_members
    where project_id = $1
      and role = 'admin'
  ), deleted as (
    delete from project_members
    where project_id = $1
      and user_id = $2
      and not (
        (select role from target) = 'admin'
        and (select count from admin_count) = 1
      )
    returning 1 as ok
  )
select
  coalesce((select role from target), '') as target_role,
  (select count from admin_count) as admin_count,
  exists(select 1 from deleted) as removed;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_create` query
/// defined in `./src/scrumbringer_server/sql/projects_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsCreateRow {
  ProjectsCreateRow(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: String,
  )
}

/// name: create_project
/// Create a project and add the creator as an admin member.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(ProjectsCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use my_role <- decode.field(4, decode.string)
    decode.success(ProjectsCreateRow(id:, org_id:, name:, created_at:, my_role:))
  }

  "-- name: create_project
-- Create a project and add the creator as an admin member.
with new_project as (
  insert into projects (org_id, name)
  values ($1, $2)
  returning id, org_id, name, created_at
), membership as (
  insert into project_members (project_id, user_id, role)
  select new_project.id, $3, 'admin'
  from new_project
)
select
  new_project.id,
  new_project.org_id,
  new_project.name,
  to_char(new_project.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  'admin' as my_role
from new_project;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_for_user` query
/// defined in `./src/scrumbringer_server/sql/projects_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsForUserRow {
  ProjectsForUserRow(
    id: Int,
    org_id: Int,
    name: String,
    created_at: String,
    my_role: String,
  )
}

/// name: list_projects_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_for_user(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectsForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.string)
    use my_role <- decode.field(4, decode.string)
    decode.success(ProjectsForUserRow(
      id:,
      org_id:,
      name:,
      created_at:,
      my_role:,
    ))
  }

  "-- name: list_projects_for_user
select
  p.id,
  p.org_id,
  p.name,
  to_char(p.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  pm.role as my_role
from projects p
join project_members pm on pm.project_id = p.id
where pm.user_id = $1
order by p.name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `projects_org_id` query
/// defined in `./src/scrumbringer_server/sql/projects_org_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ProjectsOrgIdRow {
  ProjectsOrgIdRow(org_id: Int)
}

/// name: project_org_id
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn projects_org_id(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ProjectsOrgIdRow), pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    decode.success(ProjectsOrgIdRow(org_id:))
  }

  "-- name: project_org_id
select org_id
from projects
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_executions_check` query
/// defined in `./src/scrumbringer_server/sql/rule_executions_check.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleExecutionsCheckRow {
  RuleExecutionsCheckRow(id: Int, outcome: String, suppression_reason: String)
}

/// name: rule_executions_check
/// Check if a rule has already been executed for a given origin (idempotency).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_executions_check(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(RuleExecutionsCheckRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use outcome <- decode.field(1, decode.string)
    use suppression_reason <- decode.field(2, decode.string)
    decode.success(RuleExecutionsCheckRow(id:, outcome:, suppression_reason:))
  }

  "-- name: rule_executions_check
-- Check if a rule has already been executed for a given origin (idempotency).
select
  id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason
from rule_executions
where rule_id = $1
  and origin_type = $2
  and origin_id = $3
limit 1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_executions_count` query
/// defined in `./src/scrumbringer_server/sql/rule_executions_count.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleExecutionsCountRow {
  RuleExecutionsCountRow(total: Int)
}

/// name: rule_executions_count
/// Count total executions for a rule (for pagination).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_executions_count(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(RuleExecutionsCountRow), pog.QueryError) {
  let decoder = {
    use total <- decode.field(0, decode.int)
    decode.success(RuleExecutionsCountRow(total:))
  }

  "-- name: rule_executions_count
-- Count total executions for a rule (for pagination).
select count(*)::int as total
from rule_executions
where rule_id = $1
    and created_at >= $2::timestamp
    and created_at <= $3::timestamp;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_executions_list` query
/// defined in `./src/scrumbringer_server/sql/rule_executions_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleExecutionsListRow {
  RuleExecutionsListRow(
    id: Int,
    origin_type: String,
    origin_id: Int,
    outcome: String,
    suppression_reason: String,
    user_id: Int,
    user_email: String,
    created_at: String,
  )
}

/// name: rule_executions_list
/// Get paginated list of executions for a rule (drill-down).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_executions_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
  arg_4: Int,
  arg_5: Int,
) -> Result(pog.Returned(RuleExecutionsListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use origin_type <- decode.field(1, decode.string)
    use origin_id <- decode.field(2, decode.int)
    use outcome <- decode.field(3, decode.string)
    use suppression_reason <- decode.field(4, decode.string)
    use user_id <- decode.field(5, decode.int)
    use user_email <- decode.field(6, decode.string)
    use created_at <- decode.field(7, decode.string)
    decode.success(RuleExecutionsListRow(
      id:,
      origin_type:,
      origin_id:,
      outcome:,
      suppression_reason:,
      user_id:,
      user_email:,
      created_at:,
    ))
  }

  "-- name: rule_executions_list
-- Get paginated list of executions for a rule (drill-down).
select
    re.id,
    re.origin_type,
    re.origin_id,
    re.outcome,
    coalesce(re.suppression_reason, '') as suppression_reason,
    coalesce(re.user_id, 0) as user_id,
    coalesce(u.email, '') as user_email,
    to_char(re.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from rule_executions re
left join users u on u.id = re.user_id
where re.rule_id = $1
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
order by re.created_at desc
limit $4 offset $5;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_executions_log` query
/// defined in `./src/scrumbringer_server/sql/rule_executions_log.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleExecutionsLogRow {
  RuleExecutionsLogRow(
    id: Int,
    rule_id: Int,
    origin_type: String,
    origin_id: Int,
    outcome: String,
    suppression_reason: String,
    user_id: Int,
    created_at: String,
  )
}

/// name: rule_executions_log
/// Log a rule execution for idempotency tracking and metrics.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_executions_log(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
) -> Result(pog.Returned(RuleExecutionsLogRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use rule_id <- decode.field(1, decode.int)
    use origin_type <- decode.field(2, decode.string)
    use origin_id <- decode.field(3, decode.int)
    use outcome <- decode.field(4, decode.string)
    use suppression_reason <- decode.field(5, decode.string)
    use user_id <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    decode.success(RuleExecutionsLogRow(
      id:,
      rule_id:,
      origin_type:,
      origin_id:,
      outcome:,
      suppression_reason:,
      user_id:,
      created_at:,
    ))
  }

  "-- name: rule_executions_log
-- Log a rule execution for idempotency tracking and metrics.
insert into rule_executions (rule_id, origin_type, origin_id, outcome, suppression_reason, user_id)
values ($1, $2, $3, $4, nullif($5, ''), $6)
on conflict (rule_id, origin_type, origin_id) do nothing
returning
  id,
  rule_id,
  origin_type,
  origin_id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason,
  coalesce(user_id, 0) as user_id,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_metrics_by_rule` query
/// defined in `./src/scrumbringer_server/sql/rule_metrics_by_rule.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleMetricsByRuleRow {
  RuleMetricsByRuleRow(
    rule_id: Int,
    rule_name: String,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
    suppressed_idempotent: Int,
    suppressed_not_user: Int,
    suppressed_not_matching: Int,
    suppressed_inactive: Int,
  )
}

/// name: rule_metrics_by_rule
/// Get detailed metrics for a single rule with suppression breakdown.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_metrics_by_rule(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(RuleMetricsByRuleRow), pog.QueryError) {
  let decoder = {
    use rule_id <- decode.field(0, decode.int)
    use rule_name <- decode.field(1, decode.string)
    use evaluated_count <- decode.field(2, decode.int)
    use applied_count <- decode.field(3, decode.int)
    use suppressed_count <- decode.field(4, decode.int)
    use suppressed_idempotent <- decode.field(5, decode.int)
    use suppressed_not_user <- decode.field(6, decode.int)
    use suppressed_not_matching <- decode.field(7, decode.int)
    use suppressed_inactive <- decode.field(8, decode.int)
    decode.success(RuleMetricsByRuleRow(
      rule_id:,
      rule_name:,
      evaluated_count:,
      applied_count:,
      suppressed_count:,
      suppressed_idempotent:,
      suppressed_not_user:,
      suppressed_not_matching:,
      suppressed_inactive:,
    ))
  }

  "-- name: rule_metrics_by_rule
-- Get detailed metrics for a single rule with suppression breakdown.
select
    r.id as rule_id,
    r.name as rule_name,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count,
    count(re.id) filter (where re.suppression_reason = 'idempotent')::int as suppressed_idempotent,
    count(re.id) filter (where re.suppression_reason = 'not_user_triggered')::int as suppressed_not_user,
    count(re.id) filter (where re.suppression_reason = 'not_matching')::int as suppressed_not_matching,
    count(re.id) filter (where re.suppression_reason = 'inactive')::int as suppressed_inactive
from rules r
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where r.id = $1
group by r.id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_metrics_by_workflow` query
/// defined in `./src/scrumbringer_server/sql/rule_metrics_by_workflow.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleMetricsByWorkflowRow {
  RuleMetricsByWorkflowRow(
    rule_id: Int,
    rule_name: String,
    active: Bool,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

/// name: rule_metrics_by_workflow
/// Get aggregated metrics for all rules in a workflow.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_metrics_by_workflow(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(RuleMetricsByWorkflowRow), pog.QueryError) {
  let decoder = {
    use rule_id <- decode.field(0, decode.int)
    use rule_name <- decode.field(1, decode.string)
    use active <- decode.field(2, decode.bool)
    use evaluated_count <- decode.field(3, decode.int)
    use applied_count <- decode.field(4, decode.int)
    use suppressed_count <- decode.field(5, decode.int)
    decode.success(RuleMetricsByWorkflowRow(
      rule_id:,
      rule_name:,
      active:,
      evaluated_count:,
      applied_count:,
      suppressed_count:,
    ))
  }

  "-- name: rule_metrics_by_workflow
-- Get aggregated metrics for all rules in a workflow.
select
    r.id as rule_id,
    r.name as rule_name,
    r.active,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count
from rules r
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where r.workflow_id = $1
group by r.id
order by r.name;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_metrics_org_summary` query
/// defined in `./src/scrumbringer_server/sql/rule_metrics_org_summary.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleMetricsOrgSummaryRow {
  RuleMetricsOrgSummaryRow(
    workflow_id: Int,
    workflow_name: String,
    project_id: Int,
    rule_count: Int,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

/// name: rule_metrics_org_summary
/// Get org-wide rule metrics summary.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_metrics_org_summary(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(RuleMetricsOrgSummaryRow), pog.QueryError) {
  let decoder = {
    use workflow_id <- decode.field(0, decode.int)
    use workflow_name <- decode.field(1, decode.string)
    use project_id <- decode.field(2, decode.int)
    use rule_count <- decode.field(3, decode.int)
    use evaluated_count <- decode.field(4, decode.int)
    use applied_count <- decode.field(5, decode.int)
    use suppressed_count <- decode.field(6, decode.int)
    decode.success(RuleMetricsOrgSummaryRow(
      workflow_id:,
      workflow_name:,
      project_id:,
      rule_count:,
      evaluated_count:,
      applied_count:,
      suppressed_count:,
    ))
  }

  "-- name: rule_metrics_org_summary
-- Get org-wide rule metrics summary.
select
    w.id as workflow_id,
    w.name as workflow_name,
    coalesce(w.project_id, 0) as project_id,
    count(distinct r.id)::int as rule_count,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count
from workflows w
left join rules r on r.workflow_id = w.id
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where w.org_id = $1
group by w.id
order by w.name;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_metrics_project_summary` query
/// defined in `./src/scrumbringer_server/sql/rule_metrics_project_summary.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleMetricsProjectSummaryRow {
  RuleMetricsProjectSummaryRow(
    workflow_id: Int,
    workflow_name: String,
    rule_count: Int,
    evaluated_count: Int,
    applied_count: Int,
    suppressed_count: Int,
  )
}

/// name: rule_metrics_project_summary
/// Get project-scoped rule metrics summary.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_metrics_project_summary(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Timestamp,
  arg_3: Timestamp,
) -> Result(pog.Returned(RuleMetricsProjectSummaryRow), pog.QueryError) {
  let decoder = {
    use workflow_id <- decode.field(0, decode.int)
    use workflow_name <- decode.field(1, decode.string)
    use rule_count <- decode.field(2, decode.int)
    use evaluated_count <- decode.field(3, decode.int)
    use applied_count <- decode.field(4, decode.int)
    use suppressed_count <- decode.field(5, decode.int)
    decode.success(RuleMetricsProjectSummaryRow(
      workflow_id:,
      workflow_name:,
      rule_count:,
      evaluated_count:,
      applied_count:,
      suppressed_count:,
    ))
  }

  "-- name: rule_metrics_project_summary
-- Get project-scoped rule metrics summary.
select
    w.id as workflow_id,
    w.name as workflow_name,
    count(distinct r.id)::int as rule_count,
    count(re.id)::int as evaluated_count,
    count(re.id) filter (where re.outcome = 'applied')::int as applied_count,
    count(re.id) filter (where re.outcome = 'suppressed')::int as suppressed_count
from workflows w
left join rules r on r.workflow_id = w.id
left join rule_executions re on re.rule_id = r.id
    and re.created_at >= $2::timestamp
    and re.created_at <= $3::timestamp
where w.project_id = $1
group by w.id
order by w.name;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.timestamp(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_templates_attach` query
/// defined in `./src/scrumbringer_server/sql/rule_templates_attach.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleTemplatesAttachRow {
  RuleTemplatesAttachRow(rule_id: Int)
}

/// name: attach_rule_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_templates_attach(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(RuleTemplatesAttachRow), pog.QueryError) {
  let decoder = {
    use rule_id <- decode.field(0, decode.int)
    decode.success(RuleTemplatesAttachRow(rule_id:))
  }

  "-- name: attach_rule_template
INSERT INTO rule_templates (rule_id, template_id, execution_order)
VALUES ($1, $2, $3)
ON CONFLICT (rule_id, template_id)
DO NOTHING
RETURNING rule_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_templates_detach` query
/// defined in `./src/scrumbringer_server/sql/rule_templates_detach.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleTemplatesDetachRow {
  RuleTemplatesDetachRow(rule_id: Int)
}

/// name: detach_rule_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_templates_detach(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(RuleTemplatesDetachRow), pog.QueryError) {
  let decoder = {
    use rule_id <- decode.field(0, decode.int)
    decode.success(RuleTemplatesDetachRow(rule_id:))
  }

  "-- name: detach_rule_template
DELETE FROM rule_templates
WHERE rule_id = $1
  AND template_id = $2
RETURNING rule_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rule_templates_list_for_rule` query
/// defined in `./src/scrumbringer_server/sql/rule_templates_list_for_rule.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RuleTemplatesListForRuleRow {
  RuleTemplatesListForRuleRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
    execution_order: Int,
  )
}

/// name: list_rule_templates_for_rule
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rule_templates_list_for_rule(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(RuleTemplatesListForRuleRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use type_name <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use created_by <- decode.field(8, decode.int)
    use created_at <- decode.field(9, decode.string)
    use execution_order <- decode.field(10, decode.int)
    decode.success(RuleTemplatesListForRuleRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      type_name:,
      priority:,
      created_by:,
      created_at:,
      execution_order:,
    ))
  }

  "-- name: list_rule_templates_for_rule
SELECT
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  tt.name as type_name,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  rt.execution_order
FROM rule_templates rt
JOIN task_templates t ON t.id = rt.template_id
JOIN task_types tt ON tt.id = t.type_id
WHERE rt.rule_id = $1
ORDER BY rt.execution_order ASC, t.created_at ASC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_create` query
/// defined in `./src/scrumbringer_server/sql/rules_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesCreateRow {
  RulesCreateRow(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Int,
    to_state: String,
    active: Bool,
    created_at: String,
  )
}

/// name: create_rule
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: String,
  arg_7: Bool,
) -> Result(pog.Returned(RulesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use workflow_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use goal <- decode.field(3, decode.string)
    use resource_type <- decode.field(4, decode.string)
    use task_type_id <- decode.field(5, decode.int)
    use to_state <- decode.field(6, decode.string)
    use active <- decode.field(7, decode.bool)
    use created_at <- decode.field(8, decode.string)
    decode.success(RulesCreateRow(
      id:,
      workflow_id:,
      name:,
      goal:,
      resource_type:,
      task_type_id:,
      to_state:,
      active:,
      created_at:,
    ))
  }

  "-- name: create_rule
INSERT INTO rules (
  workflow_id,
  name,
  goal,
  resource_type,
  task_type_id,
  to_state,
  active
)
VALUES (
  $1,
  $2,
  nullif($3, ''),
  $4,
  CASE WHEN $5 <= 0 THEN null ELSE $5 END,
  $6,
  $7
)
RETURNING
  id,
  workflow_id,
  name,
  coalesce(goal, '') as goal,
  resource_type,
  coalesce(task_type_id, 0) as task_type_id,
  to_state,
  active,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.bool(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_delete` query
/// defined in `./src/scrumbringer_server/sql/rules_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesDeleteRow {
  RulesDeleteRow(id: Int)
}

/// name: delete_rule
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_delete(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(RulesDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(RulesDeleteRow(id:))
  }

  "-- name: delete_rule
DELETE FROM rules
WHERE id = $1
RETURNING id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_find_matching` query
/// defined in `./src/scrumbringer_server/sql/rules_find_matching.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesFindMatchingRow {
  RulesFindMatchingRow(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Int,
    to_state: String,
    active: Bool,
    created_at: String,
    workflow_org_id: Int,
    workflow_project_id: Int,
  )
}

/// name: rules_find_matching
/// Find active rules that match a state change event.
/// For task events, filters by task_type_id if specified.
/// For card events, task_type_id filter is ignored.
/// Params: $1=resource_type, $2=to_state, $3=project_id, $4=org_id, $5=task_type_id (-1 means no filter)
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_find_matching(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
  arg_4: Int,
  arg_5: Int,
) -> Result(pog.Returned(RulesFindMatchingRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use workflow_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use goal <- decode.field(3, decode.string)
    use resource_type <- decode.field(4, decode.string)
    use task_type_id <- decode.field(5, decode.int)
    use to_state <- decode.field(6, decode.string)
    use active <- decode.field(7, decode.bool)
    use created_at <- decode.field(8, decode.string)
    use workflow_org_id <- decode.field(9, decode.int)
    use workflow_project_id <- decode.field(10, decode.int)
    decode.success(RulesFindMatchingRow(
      id:,
      workflow_id:,
      name:,
      goal:,
      resource_type:,
      task_type_id:,
      to_state:,
      active:,
      created_at:,
      workflow_org_id:,
      workflow_project_id:,
    ))
  }

  "-- name: rules_find_matching
-- Find active rules that match a state change event.
-- For task events, filters by task_type_id if specified.
-- For card events, task_type_id filter is ignored.
-- Params: $1=resource_type, $2=to_state, $3=project_id, $4=org_id, $5=task_type_id (-1 means no filter)
select
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  coalesce(r.task_type_id, 0) as task_type_id,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  w.org_id as workflow_org_id,
  coalesce(w.project_id, 0) as workflow_project_id
from rules r
join workflows w on w.id = r.workflow_id
where r.active = true
  and w.active = true
  and r.resource_type = $1
  and r.to_state = $2
  -- Scope: org-wide workflows apply to all projects in org
  -- Project-scoped workflows only apply to their project
  and w.org_id = $4
  and (w.project_id is null or w.project_id = $3)
  -- Task type filter: only for task events, ignore if task_type_id is null or -1
  and (
    $1 != 'task'
    or r.task_type_id is null
    or $5 < 0
    or r.task_type_id = $5
  )
order by w.project_id nulls last, r.id;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_get` query
/// defined in `./src/scrumbringer_server/sql/rules_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesGetRow {
  RulesGetRow(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Int,
    to_state: String,
    active: Bool,
    created_at: String,
  )
}

/// name: get_rule
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_get(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(RulesGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use workflow_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use goal <- decode.field(3, decode.string)
    use resource_type <- decode.field(4, decode.string)
    use task_type_id <- decode.field(5, decode.int)
    use to_state <- decode.field(6, decode.string)
    use active <- decode.field(7, decode.bool)
    use created_at <- decode.field(8, decode.string)
    decode.success(RulesGetRow(
      id:,
      workflow_id:,
      name:,
      goal:,
      resource_type:,
      task_type_id:,
      to_state:,
      active:,
      created_at:,
    ))
  }

  "-- name: get_rule
SELECT
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  coalesce(r.task_type_id, 0) as task_type_id,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
FROM rules r
WHERE r.id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_get_templates_for_execution` query
/// defined in `./src/scrumbringer_server/sql/rules_get_templates_for_execution.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesGetTemplatesForExecutionRow {
  RulesGetTemplatesForExecutionRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    type_id: Int,
    priority: Int,
    created_by: Int,
    created_at: String,
    execution_order: Int,
  )
}

/// name: rules_get_templates_for_execution
/// Get templates attached to a rule for execution, ordered by execution_order.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_get_templates_for_execution(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(RulesGetTemplatesForExecutionRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use priority <- decode.field(6, decode.int)
    use created_by <- decode.field(7, decode.int)
    use created_at <- decode.field(8, decode.string)
    use execution_order <- decode.field(9, decode.int)
    decode.success(RulesGetTemplatesForExecutionRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      priority:,
      created_by:,
      created_at:,
      execution_order:,
    ))
  }

  "-- name: rules_get_templates_for_execution
-- Get templates attached to a rule for execution, ordered by execution_order.
select
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  rt.execution_order
from rule_templates rt
join task_templates t on t.id = rt.template_id
where rt.rule_id = $1
order by rt.execution_order, t.id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_list_for_workflow` query
/// defined in `./src/scrumbringer_server/sql/rules_list_for_workflow.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesListForWorkflowRow {
  RulesListForWorkflowRow(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Int,
    to_state: String,
    active: Bool,
    created_at: String,
  )
}

/// name: list_rules_for_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_list_for_workflow(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(RulesListForWorkflowRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use workflow_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use goal <- decode.field(3, decode.string)
    use resource_type <- decode.field(4, decode.string)
    use task_type_id <- decode.field(5, decode.int)
    use to_state <- decode.field(6, decode.string)
    use active <- decode.field(7, decode.bool)
    use created_at <- decode.field(8, decode.string)
    decode.success(RulesListForWorkflowRow(
      id:,
      workflow_id:,
      name:,
      goal:,
      resource_type:,
      task_type_id:,
      to_state:,
      active:,
      created_at:,
    ))
  }

  "-- name: list_rules_for_workflow
SELECT
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  coalesce(r.task_type_id, 0) as task_type_id,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
FROM rules r
WHERE r.workflow_id = $1
ORDER BY r.created_at ASC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_set_active_for_workflow` query
/// defined in `./src/scrumbringer_server/sql/rules_set_active_for_workflow.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesSetActiveForWorkflowRow {
  RulesSetActiveForWorkflowRow(id: Int)
}

/// name: set_rules_active_for_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_set_active_for_workflow(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Bool,
) -> Result(pog.Returned(RulesSetActiveForWorkflowRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(RulesSetActiveForWorkflowRow(id:))
  }

  "-- name: set_rules_active_for_workflow
UPDATE rules
SET active = $2
WHERE workflow_id = $1
RETURNING id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.bool(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `rules_update` query
/// defined in `./src/scrumbringer_server/sql/rules_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RulesUpdateRow {
  RulesUpdateRow(
    id: Int,
    workflow_id: Int,
    name: String,
    goal: String,
    resource_type: String,
    task_type_id: Int,
    to_state: String,
    active: Bool,
    created_at: String,
  )
}

/// name: update_rule
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn rules_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: String,
  arg_7: Int,
) -> Result(pog.Returned(RulesUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use workflow_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use goal <- decode.field(3, decode.string)
    use resource_type <- decode.field(4, decode.string)
    use task_type_id <- decode.field(5, decode.int)
    use to_state <- decode.field(6, decode.string)
    use active <- decode.field(7, decode.bool)
    use created_at <- decode.field(8, decode.string)
    decode.success(RulesUpdateRow(
      id:,
      workflow_id:,
      name:,
      goal:,
      resource_type:,
      task_type_id:,
      to_state:,
      active:,
      created_at:,
    ))
  }

  "-- name: update_rule
UPDATE rules
SET
  name = case when $2 = '__unset__' then name else $2 end,
  goal = case when $3 = '__unset__' then goal else nullif($3, '') end,
  resource_type = case when $4 = '__unset__' then resource_type else $4 end,
  task_type_id = case
    when $5 = -1 then task_type_id
    when $5 <= 0 then null
    else $5
  end,
  to_state = case when $6 = '__unset__' then to_state else $6 end,
  active = case when $7 = -1 then active else ($7 = 1) end
WHERE id = $1
RETURNING
  id,
  workflow_id,
  name,
  coalesce(goal, '') as goal,
  resource_type,
  coalesce(task_type_id, 0) as task_type_id,
  to_state,
  active,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_events_insert` query
/// defined in `./src/scrumbringer_server/sql/task_events_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskEventsInsertRow {
  TaskEventsInsertRow(id: Int)
}

/// name: task_events_insert
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_events_insert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
  arg_5: String,
) -> Result(pog.Returned(TaskEventsInsertRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(TaskEventsInsertRow(id:))
  }

  "-- name: task_events_insert
insert into task_events (
  org_id,
  project_id,
  task_id,
  actor_user_id,
  event_type,
  created_at
)
values ($1, $2, $3, $4, $5, now())
returning id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_notes_create` query
/// defined in `./src/scrumbringer_server/sql/task_notes_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskNotesCreateRow {
  TaskNotesCreateRow(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

/// name: task_notes_create
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_notes_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
) -> Result(pog.Returned(TaskNotesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use task_id <- decode.field(1, decode.int)
    use user_id <- decode.field(2, decode.int)
    use content <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(TaskNotesCreateRow(
      id:,
      task_id:,
      user_id:,
      content:,
      created_at:,
    ))
  }

  "-- name: task_notes_create
insert into task_notes (task_id, user_id, content)
values ($1, $2, $3)
returning
  id,
  task_id,
  user_id,
  content,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_notes_list` query
/// defined in `./src/scrumbringer_server/sql/task_notes_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskNotesListRow {
  TaskNotesListRow(
    id: Int,
    task_id: Int,
    user_id: Int,
    content: String,
    created_at: String,
  )
}

/// name: task_notes_list
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_notes_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskNotesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use task_id <- decode.field(1, decode.int)
    use user_id <- decode.field(2, decode.int)
    use content <- decode.field(3, decode.string)
    use created_at <- decode.field(4, decode.string)
    decode.success(TaskNotesListRow(
      id:,
      task_id:,
      user_id:,
      content:,
      created_at:,
    ))
  }

  "-- name: task_notes_list
select
  n.id,
  n.task_id,
  n.user_id,
  n.content,
  to_char(n.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from task_notes n
where n.task_id = $1
order by n.created_at asc, n.id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_positions_list_for_user` query
/// defined in `./src/scrumbringer_server/sql/task_positions_list_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskPositionsListForUserRow {
  TaskPositionsListForUserRow(
    task_id: Int,
    user_id: Int,
    x: Int,
    y: Int,
    updated_at: String,
  )
}

/// name: task_positions_list_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_positions_list_for_user(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TaskPositionsListForUserRow), pog.QueryError) {
  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use x <- decode.field(2, decode.int)
    use y <- decode.field(3, decode.int)
    use updated_at <- decode.field(4, decode.string)
    decode.success(TaskPositionsListForUserRow(
      task_id:,
      user_id:,
      x:,
      y:,
      updated_at:,
    ))
  }

  "-- name: task_positions_list_for_user
select
  tp.task_id,
  tp.user_id,
  tp.x,
  tp.y,
  to_char(tp.updated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as updated_at
from task_positions tp
join tasks t on t.id = tp.task_id
where tp.user_id = $1
  and ($2 = 0 or t.project_id = $2)
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $1
  )
order by tp.task_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_positions_upsert` query
/// defined in `./src/scrumbringer_server/sql/task_positions_upsert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskPositionsUpsertRow {
  TaskPositionsUpsertRow(
    task_id: Int,
    user_id: Int,
    x: Int,
    y: Int,
    updated_at: String,
  )
}

/// name: task_positions_upsert
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_positions_upsert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: Int,
) -> Result(pog.Returned(TaskPositionsUpsertRow), pog.QueryError) {
  let decoder = {
    use task_id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use x <- decode.field(2, decode.int)
    use y <- decode.field(3, decode.int)
    use updated_at <- decode.field(4, decode.string)
    decode.success(TaskPositionsUpsertRow(
      task_id:,
      user_id:,
      x:,
      y:,
      updated_at:,
    ))
  }

  "-- name: task_positions_upsert
insert into task_positions (task_id, user_id, x, y, updated_at)
values ($1, $2, $3, $4, now())
on conflict (task_id, user_id) do update
set x = $3,
    y = $4,
    updated_at = now()
returning
  task_id,
  user_id,
  x,
  y,
  to_char(updated_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as updated_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_create` query
/// defined in `./src/scrumbringer_server/sql/task_templates_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesCreateRow {
  TaskTemplatesCreateRow(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: String,
    type_id: Int,
    priority: Int,
    created_by: Int,
    created_at: String,
    type_name: String,
  )
}

/// name: create_task_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(TaskTemplatesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.optional(decode.int))
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use priority <- decode.field(6, decode.int)
    use created_by <- decode.field(7, decode.int)
    use created_at <- decode.field(8, decode.string)
    use type_name <- decode.field(9, decode.string)
    decode.success(TaskTemplatesCreateRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      priority:,
      created_by:,
      created_at:,
      type_name:,
    ))
  }

  "-- name: create_task_template
WITH type_ok AS (
  SELECT tt.id
  FROM task_types tt
  JOIN projects p ON p.id = tt.project_id
  WHERE tt.id = $3
    AND (
      CASE
        WHEN $2 <= 0 THEN p.org_id = $1
        ELSE tt.project_id = $2
      END
    )
), inserted AS (
  INSERT INTO task_templates (org_id, project_id, name, description, type_id, priority, created_by)
  SELECT
    $1,
    CASE WHEN $2 <= 0 THEN null ELSE $2 END,
    $4,
    nullif($5, ''),
    type_ok.id,
    $6,
    $7
  FROM type_ok
  RETURNING
    id,
    org_id,
    project_id,
    name,
    coalesce(description, '') as description,
    type_id,
    priority,
    created_by,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
)
SELECT
  inserted.*,
  tt.name as type_name
FROM inserted
JOIN task_types tt on tt.id = inserted.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_delete` query
/// defined in `./src/scrumbringer_server/sql/task_templates_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesDeleteRow {
  TaskTemplatesDeleteRow(id: Int)
}

/// name: delete_task_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_delete(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TaskTemplatesDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(TaskTemplatesDeleteRow(id:))
  }

  "-- name: delete_task_template
DELETE FROM task_templates
WHERE id = $1
  AND org_id = $2
RETURNING id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_get` query
/// defined in `./src/scrumbringer_server/sql/task_templates_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesGetRow {
  TaskTemplatesGetRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
  )
}

/// name: get_task_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_get(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskTemplatesGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use type_name <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use created_by <- decode.field(8, decode.int)
    use created_at <- decode.field(9, decode.string)
    decode.success(TaskTemplatesGetRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      type_name:,
      priority:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: get_task_template
SELECT
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  tt.name as type_name,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
WHERE t.id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_list_for_org` query
/// defined in `./src/scrumbringer_server/sql/task_templates_list_for_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesListForOrgRow {
  TaskTemplatesListForOrgRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
  )
}

/// name: list_task_templates_for_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_list_for_org(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskTemplatesListForOrgRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use type_name <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use created_by <- decode.field(8, decode.int)
    use created_at <- decode.field(9, decode.string)
    decode.success(TaskTemplatesListForOrgRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      type_name:,
      priority:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: list_task_templates_for_org
SELECT
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  tt.name as type_name,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
WHERE t.org_id = $1
  AND t.project_id is null
ORDER BY t.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_list_for_project` query
/// defined in `./src/scrumbringer_server/sql/task_templates_list_for_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesListForProjectRow {
  TaskTemplatesListForProjectRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    type_id: Int,
    type_name: String,
    priority: Int,
    created_by: Int,
    created_at: String,
  )
}

/// name: list_task_templates_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_list_for_project(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskTemplatesListForProjectRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use type_name <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use created_by <- decode.field(8, decode.int)
    use created_at <- decode.field(9, decode.string)
    decode.success(TaskTemplatesListForProjectRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      type_name:,
      priority:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: list_task_templates_for_project
SELECT
  t.id,
  t.org_id,
  coalesce(t.project_id, 0) as project_id,
  t.name,
  coalesce(t.description, '') as description,
  t.type_id,
  tt.name as type_name,
  t.priority,
  t.created_by,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
FROM task_templates t
JOIN task_types tt on tt.id = t.type_id
WHERE t.project_id = $1
ORDER BY t.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_templates_update` query
/// defined in `./src/scrumbringer_server/sql/task_templates_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTemplatesUpdateRow {
  TaskTemplatesUpdateRow(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: String,
    type_id: Int,
    priority: Int,
    created_by: Int,
    created_at: String,
    type_name: String,
  )
}

/// name: update_task_template
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_templates_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(TaskTemplatesUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.optional(decode.int))
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use type_id <- decode.field(5, decode.int)
    use priority <- decode.field(6, decode.int)
    use created_by <- decode.field(7, decode.int)
    use created_at <- decode.field(8, decode.string)
    use type_name <- decode.field(9, decode.string)
    decode.success(TaskTemplatesUpdateRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      type_id:,
      priority:,
      created_by:,
      created_at:,
      type_name:,
    ))
  }

  "-- name: update_task_template
WITH current AS (
  SELECT id, type_id
  FROM task_templates
  WHERE id = $1
    AND org_id = $3
), type_ok AS (
  SELECT
    CASE
      WHEN $6 = -1 THEN current.type_id
      ELSE (
        SELECT tt.id
        FROM task_types tt
        JOIN projects p ON p.id = tt.project_id
        WHERE tt.id = $6
          AND (
            CASE
              WHEN $2 <= 0 THEN p.org_id = $3
              ELSE tt.project_id = $2
            END
          )
      )
    END as type_id
  FROM current
), updated AS (
  UPDATE task_templates
  SET
    name = case when $4 = '__unset__' then name else $4 end,
    description = case when $5 = '__unset__' then description else nullif($5, '') end,
    type_id = type_ok.type_id,
    priority = case when $7 = -1 then priority else $7 end
  FROM type_ok
  WHERE task_templates.id = $1
    AND task_templates.org_id = $3
    AND type_ok.type_id is not null
  RETURNING
    task_templates.id,
    task_templates.org_id,
    task_templates.project_id,
    task_templates.name,
    coalesce(task_templates.description, '') as description,
    task_templates.type_id,
    task_templates.priority,
    task_templates.created_by,
    to_char(task_templates.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
)
SELECT
  updated.*,
  tt.name as type_name
FROM updated
JOIN task_types tt on tt.id = updated.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_create` query
/// defined in `./src/scrumbringer_server/sql/task_types_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesCreateRow {
  TaskTypesCreateRow(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Int,
  )
}

/// name: create_task_type
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
  arg_4: Int,
) -> Result(pog.Returned(TaskTypesCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use icon <- decode.field(3, decode.string)
    use capability_id <- decode.field(4, decode.int)
    decode.success(TaskTypesCreateRow(
      id:,
      project_id:,
      name:,
      icon:,
      capability_id:,
    ))
  }

  "-- name: create_task_type
insert into task_types (project_id, name, icon, capability_id)
values ($1, $2, $3, nullif($4, 0))
returning
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_is_in_project` query
/// defined in `./src/scrumbringer_server/sql/task_types_is_in_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesIsInProjectRow {
  TaskTypesIsInProjectRow(ok: Bool)
}

/// name: task_type_is_in_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_is_in_project(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TaskTypesIsInProjectRow), pog.QueryError) {
  let decoder = {
    use ok <- decode.field(0, decode.bool)
    decode.success(TaskTypesIsInProjectRow(ok:))
  }

  "-- name: task_type_is_in_project
select exists(
  select 1
  from task_types
  where id = $1
    and project_id = $2
) as ok;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `task_types_list` query
/// defined in `./src/scrumbringer_server/sql/task_types_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TaskTypesListRow {
  TaskTypesListRow(
    id: Int,
    project_id: Int,
    name: String,
    icon: String,
    capability_id: Int,
  )
}

/// name: list_task_types_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn task_types_list(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(TaskTypesListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use name <- decode.field(2, decode.string)
    use icon <- decode.field(3, decode.string)
    use capability_id <- decode.field(4, decode.int)
    decode.success(TaskTypesListRow(
      id:,
      project_id:,
      name:,
      icon:,
      capability_id:,
    ))
  }

  "-- name: list_task_types_for_project
select
  id,
  project_id,
  name,
  icon,
  coalesce(capability_id, 0) as capability_id
from task_types
where project_id = $1
order by name asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_claim` query
/// defined in `./src/scrumbringer_server/sql/tasks_claim.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksClaimRow {
  TasksClaimRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
    type_name: String,
    type_icon: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
  )
}

/// name: claim_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_claim(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksClaimRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    use card_id <- decode.field(13, decode.int)
    use type_name <- decode.field(14, decode.string)
    use type_icon <- decode.field(15, decode.string)
    use is_ongoing <- decode.field(16, decode.bool)
    use ongoing_by_user_id <- decode.field(17, decode.int)
    decode.success(TasksClaimRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
      type_name:,
      type_icon:,
      is_ongoing:,
      ongoing_by_user_id:,
    ))
  }

  "-- name: claim_task
with updated as (
  update tasks
  set
    claimed_by = $2,
    claimed_at = now(),
    status = 'claimed',
    version = version + 1
  where id = $1
    and status = 'available'
    and version = $3
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id
from updated
join task_types tt on tt.id = updated.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_complete` query
/// defined in `./src/scrumbringer_server/sql/tasks_complete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksCompleteRow {
  TasksCompleteRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
    type_name: String,
    type_icon: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
  )
}

/// name: complete_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_complete(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksCompleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    use card_id <- decode.field(13, decode.int)
    use type_name <- decode.field(14, decode.string)
    use type_icon <- decode.field(15, decode.string)
    use is_ongoing <- decode.field(16, decode.bool)
    use ongoing_by_user_id <- decode.field(17, decode.int)
    decode.success(TasksCompleteRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
      type_name:,
      type_icon:,
      is_ongoing:,
      ongoing_by_user_id:,
    ))
  }

  "-- name: complete_task
with updated as (
  update tasks
  set
    status = 'completed',
    completed_at = now(),
    version = version + 1
  where id = $1
    and status = 'claimed'
    and claimed_by = $2
    and version = $3
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id
from updated
join task_types tt on tt.id = updated.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_create` query
/// defined in `./src/scrumbringer_server/sql/tasks_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksCreateRow {
  TasksCreateRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
    type_name: String,
    type_icon: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
  )
}

/// name: create_task
/// Create a new task in a project, ensuring the task type belongs to the project
/// and optionally associating with a card (if card_id > 0 and belongs to same project).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(TasksCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    use card_id <- decode.field(13, decode.int)
    use type_name <- decode.field(14, decode.string)
    use type_icon <- decode.field(15, decode.string)
    use is_ongoing <- decode.field(16, decode.bool)
    use ongoing_by_user_id <- decode.field(17, decode.int)
    decode.success(TasksCreateRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
      type_name:,
      type_icon:,
      is_ongoing:,
      ongoing_by_user_id:,
    ))
  }

  "-- name: create_task
-- Create a new task in a project, ensuring the task type belongs to the project
-- and optionally associating with a card (if card_id > 0 and belongs to same project).
with type_ok as (
  select id
  from task_types
  where id = $1
    and project_id = $2
), card_ok as (
  -- If card_id is 0 (or null-like sentinel), allow creation.
  -- If card_id > 0, require it to belong to the same project.
  select case
    when $7 <= 0 then null
    else (select id from cards where id = $7 and project_id = $2)
  end as id
), inserted as (
  insert into tasks (project_id, type_id, title, description, priority, created_by, card_id)
  select
    $2,
    type_ok.id,
    $3,
    nullif($4, ''),
    $5,
    $6,
    card_ok.id
  from type_ok, card_ok
  where type_ok.id is not null
    -- Block if card_id > 0 but card_ok.id is null (invalid card)
    and (($7 <= 0) or (card_ok.id is not null))
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  inserted.*,
  tt.name as type_name,
  tt.icon as type_icon,
  (false) as is_ongoing,
  0 as ongoing_by_user_id
from inserted
join task_types tt on tt.id = inserted.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_get_for_user` query
/// defined in `./src/scrumbringer_server/sql/tasks_get_for_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksGetForUserRow {
  TasksGetForUserRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    title: String,
    description: String,
    priority: Int,
    status: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
  )
}

/// name: get_task_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_get_for_user(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(TasksGetForUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use type_name <- decode.field(3, decode.string)
    use type_icon <- decode.field(4, decode.string)
    use title <- decode.field(5, decode.string)
    use description <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use status <- decode.field(8, decode.string)
    use is_ongoing <- decode.field(9, decode.bool)
    use ongoing_by_user_id <- decode.field(10, decode.int)
    use created_by <- decode.field(11, decode.int)
    use claimed_by <- decode.field(12, decode.int)
    use claimed_at <- decode.field(13, decode.string)
    use completed_at <- decode.field(14, decode.string)
    use created_at <- decode.field(15, decode.string)
    use version <- decode.field(16, decode.int)
    use card_id <- decode.field(17, decode.int)
    decode.success(TasksGetForUserRow(
      id:,
      project_id:,
      type_id:,
      type_name:,
      type_icon:,
      title:,
      description:,
      priority:,
      status:,
      is_ongoing:,
      ongoing_by_user_id:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
    ))
  }

  "-- name: get_task_for_user
select
  t.id,
  t.project_id,
  t.type_id,
  tt.name as type_name,
  tt.icon as type_icon,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  (
    t.status = 'claimed'
    and exists(
      select 1
      from user_task_work_session ws
      where ws.task_id = t.id and ws.ended_at is null
    )
  ) as is_ongoing,
  coalesce((
    select ws.user_id
    from user_task_work_session ws
    where ws.task_id = t.id and ws.ended_at is null
    order by ws.started_at desc
    limit 1
  ), 0) as ongoing_by_user_id,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  t.version,
  coalesce(t.card_id, 0) as card_id
from tasks t
join task_types tt on tt.id = t.type_id
where t.id = $1
  and exists(
    select 1
    from project_members pm
    where pm.project_id = t.project_id
      and pm.user_id = $2
  );
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_list` query
/// defined in `./src/scrumbringer_server/sql/tasks_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksListRow {
  TasksListRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    type_name: String,
    type_icon: String,
    title: String,
    description: String,
    priority: Int,
    status: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
  )
}

/// name: list_tasks_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: Int,
  arg_4: Int,
  arg_5: String,
) -> Result(pog.Returned(TasksListRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use type_name <- decode.field(3, decode.string)
    use type_icon <- decode.field(4, decode.string)
    use title <- decode.field(5, decode.string)
    use description <- decode.field(6, decode.string)
    use priority <- decode.field(7, decode.int)
    use status <- decode.field(8, decode.string)
    use is_ongoing <- decode.field(9, decode.bool)
    use ongoing_by_user_id <- decode.field(10, decode.int)
    use created_by <- decode.field(11, decode.int)
    use claimed_by <- decode.field(12, decode.int)
    use claimed_at <- decode.field(13, decode.string)
    use completed_at <- decode.field(14, decode.string)
    use created_at <- decode.field(15, decode.string)
    use version <- decode.field(16, decode.int)
    use card_id <- decode.field(17, decode.int)
    decode.success(TasksListRow(
      id:,
      project_id:,
      type_id:,
      type_name:,
      type_icon:,
      title:,
      description:,
      priority:,
      status:,
      is_ongoing:,
      ongoing_by_user_id:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
    ))
  }

  "-- name: list_tasks_for_project
select
  t.id,
  t.project_id,
  t.type_id,
  tt.name as type_name,
  tt.icon as type_icon,
  t.title,
  coalesce(t.description, '') as description,
  t.priority,
  t.status,
  (
    t.status = 'claimed'
    and exists(
      select 1
      from user_task_work_session ws
      where ws.task_id = t.id and ws.ended_at is null
    )
  ) as is_ongoing,
  coalesce((
    select ws.user_id
    from user_task_work_session ws
    where ws.task_id = t.id and ws.ended_at is null
    order by ws.started_at desc
    limit 1
  ), 0) as ongoing_by_user_id,
  t.created_by,
  coalesce(t.claimed_by, 0) as claimed_by,
  coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
  coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
  to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  t.version,
  coalesce(t.card_id, 0) as card_id
from tasks t
join task_types tt on tt.id = t.type_id
where t.project_id = $1
  and ($2 = '' or t.status = $2)
  and ($3 = 0 or t.type_id = $3)
  and ($4 = 0 or tt.capability_id = $4)
  and (
    $5 = ''
    or t.title ilike ('%' || $5 || '%')
    or t.description ilike ('%' || $5 || '%')
  )
order by t.created_at desc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_release` query
/// defined in `./src/scrumbringer_server/sql/tasks_release.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksReleaseRow {
  TasksReleaseRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
    type_name: String,
    type_icon: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
  )
}

/// name: release_task
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_release(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(TasksReleaseRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    use card_id <- decode.field(13, decode.int)
    use type_name <- decode.field(14, decode.string)
    use type_icon <- decode.field(15, decode.string)
    use is_ongoing <- decode.field(16, decode.bool)
    use ongoing_by_user_id <- decode.field(17, decode.int)
    decode.success(TasksReleaseRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
      type_name:,
      type_icon:,
      is_ongoing:,
      ongoing_by_user_id:,
    ))
  }

  "-- name: release_task
with updated as (
  update tasks
  set
    claimed_by = null,
    claimed_at = null,
    status = 'available',
    version = version + 1
  where id = $1
    and status = 'claimed'
    and claimed_by = $2
    and version = $3
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id
from updated
join task_types tt on tt.id = updated.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `tasks_update` query
/// defined in `./src/scrumbringer_server/sql/tasks_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type TasksUpdateRow {
  TasksUpdateRow(
    id: Int,
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    status: String,
    created_by: Int,
    claimed_by: Int,
    claimed_at: String,
    completed_at: String,
    created_at: String,
    version: Int,
    card_id: Int,
    type_name: String,
    type_icon: String,
    is_ongoing: Bool,
    ongoing_by_user_id: Int,
  )
}

/// name: update_task_claimed_by_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn tasks_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
  arg_4: String,
  arg_5: Int,
  arg_6: Int,
  arg_7: Int,
) -> Result(pog.Returned(TasksUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use project_id <- decode.field(1, decode.int)
    use type_id <- decode.field(2, decode.int)
    use title <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use priority <- decode.field(5, decode.int)
    use status <- decode.field(6, decode.string)
    use created_by <- decode.field(7, decode.int)
    use claimed_by <- decode.field(8, decode.int)
    use claimed_at <- decode.field(9, decode.string)
    use completed_at <- decode.field(10, decode.string)
    use created_at <- decode.field(11, decode.string)
    use version <- decode.field(12, decode.int)
    use card_id <- decode.field(13, decode.int)
    use type_name <- decode.field(14, decode.string)
    use type_icon <- decode.field(15, decode.string)
    use is_ongoing <- decode.field(16, decode.bool)
    use ongoing_by_user_id <- decode.field(17, decode.int)
    decode.success(TasksUpdateRow(
      id:,
      project_id:,
      type_id:,
      title:,
      description:,
      priority:,
      status:,
      created_by:,
      claimed_by:,
      claimed_at:,
      completed_at:,
      created_at:,
      version:,
      card_id:,
      type_name:,
      type_icon:,
      is_ongoing:,
      ongoing_by_user_id:,
    ))
  }

  "-- name: update_task_claimed_by_user
with updated as (
  update tasks
  set
    title = case when $3 = '__unset__' then title else $3 end,
    description = case when $4 = '__unset__' then description else nullif($4, '') end,
    priority = case when $5 = -1 then priority else $5 end,
    type_id = case when $6 = -1 then type_id else $6 end,
    version = version + 1
  where id = $1
    and claimed_by = $2
    and status = 'claimed'
    and version = $7
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  updated.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id
from updated
join task_types tt on tt.id = updated.type_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.parameter(pog.int(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_delete_all` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_delete_all.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesDeleteAllRow {
  UserCapabilitiesDeleteAllRow(user_id: Int)
}

/// name: delete_user_capabilities_for_user
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_delete_all(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(UserCapabilitiesDeleteAllRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.int)
    decode.success(UserCapabilitiesDeleteAllRow(user_id:))
  }

  "-- name: delete_user_capabilities_for_user
delete from user_capabilities
where user_id = $1
returning user_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_insert` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_insert.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesInsertRow {
  UserCapabilitiesInsertRow(user_id: Int, capability_id: Int)
}

/// name: insert_user_capability
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_insert(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(UserCapabilitiesInsertRow), pog.QueryError) {
  let decoder = {
    use user_id <- decode.field(0, decode.int)
    use capability_id <- decode.field(1, decode.int)
    decode.success(UserCapabilitiesInsertRow(user_id:, capability_id:))
  }

  "-- name: insert_user_capability
insert into user_capabilities (user_id, capability_id)
values ($1, $2)
returning user_id, capability_id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `user_capabilities_list` query
/// defined in `./src/scrumbringer_server/sql/user_capabilities_list.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserCapabilitiesListRow {
  UserCapabilitiesListRow(capability_id: Int)
}

/// name: list_user_capability_ids
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn user_capabilities_list(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
) -> Result(pog.Returned(UserCapabilitiesListRow), pog.QueryError) {
  let decoder = {
    use capability_id <- decode.field(0, decode.int)
    decode.success(UserCapabilitiesListRow(capability_id:))
  }

  "-- name: list_user_capability_ids
select
  uc.capability_id
from user_capabilities uc
join capabilities c on c.id = uc.capability_id
where uc.user_id = $1
  and c.org_id = $2
order by uc.capability_id asc;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `users_org_id` query
/// defined in `./src/scrumbringer_server/sql/users_org_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UsersOrgIdRow {
  UsersOrgIdRow(org_id: Int)
}

/// name: user_org_id
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn users_org_id(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(UsersOrgIdRow), pog.QueryError) {
  let decoder = {
    use org_id <- decode.field(0, decode.int)
    decode.success(UsersOrgIdRow(org_id:))
  }

  "-- name: user_org_id
select org_id
from users
where id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_create` query
/// defined in `./src/scrumbringer_server/sql/workflows_create.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsCreateRow {
  WorkflowsCreateRow(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: String,
    active: Bool,
    created_by: Int,
    created_at: String,
  )
}

/// name: create_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_create(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: String,
  arg_4: String,
  arg_5: Bool,
  arg_6: Int,
) -> Result(pog.Returned(WorkflowsCreateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.optional(decode.int))
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use active <- decode.field(5, decode.bool)
    use created_by <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    decode.success(WorkflowsCreateRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      active:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: create_workflow
INSERT INTO workflows (org_id, project_id, name, description, active, created_by)
VALUES (
  $1,
  CASE WHEN $2 <= 0 THEN null ELSE $2 END,
  $3,
  nullif($4, ''),
  $5,
  $6
)
RETURNING
  id,
  org_id,
  project_id,
  name,
  coalesce(description, '') as description,
  active,
  created_by,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.bool(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_delete` query
/// defined in `./src/scrumbringer_server/sql/workflows_delete.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsDeleteRow {
  WorkflowsDeleteRow(id: Int)
}

/// name: delete_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_delete(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
) -> Result(pog.Returned(WorkflowsDeleteRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(WorkflowsDeleteRow(id:))
  }

  "-- name: delete_workflow
DELETE FROM workflows
WHERE id = $1
  AND org_id = $2
  AND (
    CASE
      WHEN $3 <= 0 THEN project_id is null
      ELSE project_id = $3
    END
  )
RETURNING id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_get` query
/// defined in `./src/scrumbringer_server/sql/workflows_get.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsGetRow {
  WorkflowsGetRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    active: Bool,
    created_by: Int,
    created_at: String,
    rule_count: Int,
  )
}

/// name: get_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_get(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(WorkflowsGetRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use active <- decode.field(5, decode.bool)
    use created_by <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    use rule_count <- decode.field(8, decode.int)
    decode.success(WorkflowsGetRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      active:,
      created_by:,
      created_at:,
      rule_count:,
    ))
  }

  "-- name: get_workflow
SELECT
  w.id,
  w.org_id,
  coalesce(w.project_id, 0) as project_id,
  w.name,
  coalesce(w.description, '') as description,
  w.active,
  w.created_by,
  to_char(w.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(r.rule_count, 0) as rule_count
FROM workflows w
LEFT JOIN (
  SELECT workflow_id, count(*)::int as rule_count
  FROM rules
  GROUP BY workflow_id
) r ON r.workflow_id = w.id
WHERE w.id = $1;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_list_for_org` query
/// defined in `./src/scrumbringer_server/sql/workflows_list_for_org.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsListForOrgRow {
  WorkflowsListForOrgRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    active: Bool,
    created_by: Int,
    created_at: String,
    rule_count: Int,
  )
}

/// name: list_workflows_for_org
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_list_for_org(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(WorkflowsListForOrgRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use active <- decode.field(5, decode.bool)
    use created_by <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    use rule_count <- decode.field(8, decode.int)
    decode.success(WorkflowsListForOrgRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      active:,
      created_by:,
      created_at:,
      rule_count:,
    ))
  }

  "-- name: list_workflows_for_org
SELECT
  w.id,
  w.org_id,
  coalesce(w.project_id, 0) as project_id,
  w.name,
  coalesce(w.description, '') as description,
  w.active,
  w.created_by,
  to_char(w.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(r.rule_count, 0) as rule_count
FROM workflows w
LEFT JOIN (
  SELECT workflow_id, count(*)::int as rule_count
  FROM rules
  GROUP BY workflow_id
) r ON r.workflow_id = w.id
WHERE w.org_id = $1
  AND w.project_id is null
ORDER BY w.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_list_for_project` query
/// defined in `./src/scrumbringer_server/sql/workflows_list_for_project.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsListForProjectRow {
  WorkflowsListForProjectRow(
    id: Int,
    org_id: Int,
    project_id: Int,
    name: String,
    description: String,
    active: Bool,
    created_by: Int,
    created_at: String,
    rule_count: Int,
  )
}

/// name: list_workflows_for_project
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_list_for_project(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(WorkflowsListForProjectRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.int)
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use active <- decode.field(5, decode.bool)
    use created_by <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    use rule_count <- decode.field(8, decode.int)
    decode.success(WorkflowsListForProjectRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      active:,
      created_by:,
      created_at:,
      rule_count:,
    ))
  }

  "-- name: list_workflows_for_project
SELECT
  w.id,
  w.org_id,
  coalesce(w.project_id, 0) as project_id,
  w.name,
  coalesce(w.description, '') as description,
  w.active,
  w.created_by,
  to_char(w.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at,
  coalesce(r.rule_count, 0) as rule_count
FROM workflows w
LEFT JOIN (
  SELECT workflow_id, count(*)::int as rule_count
  FROM rules
  GROUP BY workflow_id
) r ON r.workflow_id = w.id
WHERE w.project_id = $1
ORDER BY w.created_at DESC;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_set_active` query
/// defined in `./src/scrumbringer_server/sql/workflows_set_active.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsSetActiveRow {
  WorkflowsSetActiveRow(id: Int)
}

/// name: set_workflow_active
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_set_active(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: Bool,
) -> Result(pog.Returned(WorkflowsSetActiveRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    decode.success(WorkflowsSetActiveRow(id:))
  }

  "-- name: set_workflow_active
UPDATE workflows
SET active = $4
WHERE id = $1
  AND org_id = $2
  AND (
    CASE
      WHEN $3 <= 0 THEN project_id is null
      ELSE project_id = $3
    END
  )
RETURNING id;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.bool(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `workflows_update` query
/// defined in `./src/scrumbringer_server/sql/workflows_update.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type WorkflowsUpdateRow {
  WorkflowsUpdateRow(
    id: Int,
    org_id: Int,
    project_id: Option(Int),
    name: String,
    description: String,
    active: Bool,
    created_by: Int,
    created_at: String,
  )
}

/// name: update_workflow
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn workflows_update(
  db: pog.Connection,
  arg_1: Int,
  arg_2: Int,
  arg_3: Int,
  arg_4: String,
  arg_5: String,
  arg_6: Int,
) -> Result(pog.Returned(WorkflowsUpdateRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use org_id <- decode.field(1, decode.int)
    use project_id <- decode.field(2, decode.optional(decode.int))
    use name <- decode.field(3, decode.string)
    use description <- decode.field(4, decode.string)
    use active <- decode.field(5, decode.bool)
    use created_by <- decode.field(6, decode.int)
    use created_at <- decode.field(7, decode.string)
    decode.success(WorkflowsUpdateRow(
      id:,
      org_id:,
      project_id:,
      name:,
      description:,
      active:,
      created_by:,
      created_at:,
    ))
  }

  "-- name: update_workflow
UPDATE workflows
SET
  name = case when $4 = '__unset__' then name else $4 end,
  description = case when $5 = '__unset__' then description else nullif($5, '') end,
  active = case when $6 = -1 then active else ($6 = 1) end
WHERE id = $1
  AND org_id = $2
  AND (
    CASE
      WHEN $3 <= 0 THEN project_id is null
      ELSE project_id = $3
    END
  )
RETURNING
  id,
  org_id,
  project_id,
  name,
  coalesce(description, '') as description,
  active,
  created_by,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
