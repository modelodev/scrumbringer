import fixtures
import gleam/option.{None, Some}
import gleeunit/should
import pog
import scrumbringer_server
import scrumbringer_server/seed_db

pub fn insert_project_accepts_sql_timestamp_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    seed_db.insert_project(db, 1, "SQL Project", Some("NOW()"))

  let assert Ok(has_created) =
    fixtures.query_int(
      db,
      "select (created_at is not null)::int from projects where id = $1",
      [pog.int(project_id)],
    )

  has_created |> should.equal(1)
}

pub fn insert_card_accepts_sql_timestamp_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Core", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "card@example.com", "admin")

  let assert Ok(card_id) =
    seed_db.insert_card(
      db,
      seed_db.CardInsertOptions(
        project_id: project_id,
        title: "Card",
        description: "Desc",
        color: None,
        created_by: user_id,
        created_at: Some("NOW()"),
      ),
    )

  let assert Ok(has_created) =
    fixtures.query_int(
      db,
      "select (created_at is not null)::int from cards where id = $1",
      [pog.int(card_id)],
    )

  has_created |> should.equal(1)
}

pub fn insert_task_accepts_sql_timestamp_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Core", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "task@example.com", "admin")
  let assert Ok(type_id) =
    seed_db.insert_task_type(db, project_id, "Bug", "bug-ant")

  let assert Ok(task_id) =
    seed_db.insert_task(
      db,
      seed_db.TaskInsertOptions(
        project_id: project_id,
        type_id: type_id,
        title: "Task",
        description: "Desc",
        priority: 3,
        status: "available",
        created_by: user_id,
        claimed_by: None,
        card_id: None,
        created_at: Some("NOW()"),
        claimed_at: None,
        completed_at: None,
      ),
    )

  let assert Ok(has_created) =
    fixtures.query_int(
      db,
      "select (created_at is not null)::int from tasks where id = $1",
      [pog.int(task_id)],
    )

  has_created |> should.equal(1)
}
