import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/list
import gleeunit
import pog
import scrumbringer_server
import scrumbringer_server/seed_builder
import scrumbringer_server/seed_db
import support/assertions as expect
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

pub fn seed_creates_visible_operational_tasks_under_active_cards_test() {
  let assert Ok(#(app, handler, _bootstrap_session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(#(org_id, admin_id)) = seed_db.reset_seed_database(db)
  let assert Ok(stats) =
    seed_builder.build_seed(db, org_id, admin_id, compact_seed_config())
  let assert Ok(session) =
    fixtures.login(handler, "admin@example.com", "passwordpassword")
  let assert Ok(default_project_id) =
    fixtures.query_int(db, "select id from projects where name = 'Default'", [])

  stats.task_types |> expect.equal(12)

  let assert Ok(active_card_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from cards where execution_state = 'active'",
      [],
    )
  expect.is_true(active_card_count > 0)

  let assert Ok(card_hierarchy_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from cards where parent_card_id is not null",
      [],
    )
  expect.is_true(card_hierarchy_count > 0)

  let assert Ok(seed_capability_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from capabilities where project_id = $1",
      [pog.int(default_project_id)],
    )
  seed_capability_count |> expect.equal(6)

  let assert Ok(seed_capabilities_used_by_tasks) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from (
         select tt.capability_id
         from task_types tt
         join tasks t on t.type_id = tt.id
         where tt.project_id = $1
           and tt.capability_id is not null
         group by tt.capability_id
       ) used_capabilities",
      [pog.int(default_project_id)],
    )
  seed_capabilities_used_by_tasks |> expect.equal(6)

  let assert Ok(max_card_depth) =
    fixtures.query_int(
      db,
      "with recursive card_tree as (
         select id, parent_card_id, 1 as depth
         from cards
         where parent_card_id is null
         union all
         select c.id, c.parent_card_id, card_tree.depth + 1
         from cards c
         join card_tree on c.parent_card_id = card_tree.id
       )
       select coalesce(max(depth), 0)::int from card_tree",
      [],
    )
  expect.is_true(max_card_depth >= 3)

  let assert Ok(root_open_task_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from tasks where card_id is null and execution_state in ('available', 'claimed')",
      [],
    )
  root_open_task_count |> expect.equal(0)

  let assert Ok(non_active_open_task_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks t
       join cards c on c.id = t.card_id
       where t.execution_state in ('available', 'claimed')
         and c.execution_state <> 'active'",
      [],
    )
  non_active_open_task_count |> expect.equal(0)

  let available_res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/projects/"
          <> int.to_string(default_project_id)
          <> "/tasks?status=available",
      )
      |> fixtures.with_auth(session),
    )
  expect.expect_status(available_res, 200)
  expect.is_true(decode_task_count(simulate.read_body(available_res)) > 0)
}

pub fn reset_seed_database_is_rerunnable_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(#(_, _)) = seed_db.reset_seed_database(db)
  let assert Ok(#(_, _)) = seed_db.reset_seed_database(db)

  let assert Ok(admin_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from users where email = 'admin@example.com'",
      [],
    )
  admin_count |> expect.equal(1)

  let assert Ok(project_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from projects where name = 'Default'",
      [],
    )
  project_count |> expect.equal(1)
}

fn compact_seed_config() -> seed_builder.SeedConfig {
  seed_builder.SeedConfig(
    user_count: 5,
    inactive_user_count: 0,
    project_count: 1,
    empty_project_count: 0,
    tasks_per_project: 7,
    priority_distribution: [1, 2, 3],
    status_distribution: seed_builder.StatusDistribution(
      available: 35,
      claimed: 40,
      closed: 25,
    ),
    cards_per_project: 5,
    empty_card_count: 2,
    date_range_days: 10,
  )
}

fn decode_task_count(body: String) -> Int {
  let tasks =
    fixtures.require_data(
      body,
      decode.field("tasks", decode.list(decode.dynamic), decode.success),
    )
  list.length(tasks)
}
