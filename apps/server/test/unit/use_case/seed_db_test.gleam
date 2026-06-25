import domain/org_role
import domain/task/state as task_state
import fixtures
import gleam/option.{None, Some}
import pog
import scrumbringer_server
import scrumbringer_server/seed_db
import support/assertions as expect

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

  has_created |> expect.equal(1)
}

pub fn insert_card_accepts_sql_timestamp_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Core", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "card@example.com", org_role.Admin)

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

  has_created |> expect.equal(1)
}

pub fn upsert_project_settings_updates_healthy_pool_limit_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    seed_db.insert_project(db, 1, "Settings Project", None)

  let assert Ok(Nil) = seed_db.upsert_project_settings(db, project_id, 6)
  let assert Ok(Nil) = seed_db.upsert_project_settings(db, project_id, 9)

  let assert Ok(limit) =
    fixtures.query_int(
      db,
      "select healthy_pool_limit::int from project_settings where project_id = $1",
      [pog.int(project_id)],
    )

  limit |> expect.equal(9)
}

pub fn insert_task_accepts_sql_timestamp_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Core", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "task@example.com", org_role.Admin)
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
        execution_state: task_state.Available,
        created_by: user_id,
        card_id: None,
        created_from_rule_id: None,
        pool_lifetime_s: 0,
        due_date: None,
        created_at: Some("NOW()"),
        last_entered_pool_at: None,
      ),
    )

  let assert Ok(has_created) =
    fixtures.query_int(
      db,
      "select (created_at is not null)::int from tasks where id = $1",
      [pog.int(task_id)],
    )

  has_created |> expect.equal(1)
}

pub fn assign_card_to_parent_card_updates_specific_card_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Parented", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "parent-card@example.com", org_role.Admin)
  let assert Ok(parent_id) =
    seed_db.insert_card_simple(db, project_id, "Parent", None, user_id)
  let assert Ok(child_id) =
    seed_db.insert_card_simple(db, project_id, "Child", None, user_id)

  let assert Ok(Nil) =
    seed_db.assign_card_to_parent_card(db, child_id, parent_id)

  let assert Ok(parent_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from cards where id = $1 and parent_card_id = $2",
      [pog.int(child_id), pog.int(parent_id)],
    )

  parent_count |> expect.equal(1)
}

pub fn assign_card_to_parent_card_rejects_parent_with_tasks_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Task parent", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "task-parent@example.com", org_role.Admin)
  let assert Ok(type_id) =
    seed_db.insert_task_type(db, project_id, "Bug", "bug-ant")
  let assert Ok(parent_id) =
    seed_db.insert_card_simple(db, project_id, "Parent", None, user_id)
  let assert Ok(child_id) =
    seed_db.insert_card_simple(db, project_id, "Child", None, user_id)
  let assert Ok(_task_id) =
    seed_db.insert_task_simple(
      db,
      project_id,
      type_id,
      "Parent task",
      user_id,
      Some(parent_id),
    )

  let assert Error(message) =
    seed_db.assign_card_to_parent_card(db, child_id, parent_id)

  message |> expect.equal("parent card already contains tasks")
}

pub fn assign_pool_tasks_to_parent_card_rejects_parent_with_child_cards_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Card parent", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "card-parent@example.com", org_role.Admin)
  let assert Ok(type_id) =
    seed_db.insert_task_type(db, project_id, "Bug", "bug-ant")
  let assert Ok(parent_id) =
    seed_db.insert_card_simple(db, project_id, "Parent", None, user_id)
  let assert Ok(child_id) =
    seed_db.insert_card_simple(db, project_id, "Child", None, user_id)
  let assert Ok(_task_id) =
    seed_db.insert_task_simple(
      db,
      project_id,
      type_id,
      "Pool task",
      user_id,
      None,
    )
  let assert Ok(Nil) =
    seed_db.assign_card_to_parent_card(db, child_id, parent_id)

  let assert Error(message) =
    seed_db.assign_available_pool_tasks_to_parent_card(
      db,
      project_id,
      parent_id,
      1,
    )

  message |> expect.equal("parent card already contains child cards")
}

pub fn insert_task_dependency_creates_dependency_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = seed_db.insert_project(db, 1, "Deps", None)
  let assert Ok(user_id) =
    seed_db.insert_user_simple(db, 1, "dep@example.com", org_role.Admin)
  let assert Ok(type_id) =
    seed_db.insert_task_type(db, project_id, "Bug", "bug-ant")
  let assert Ok(blocked_id) =
    seed_db.insert_task_simple(
      db,
      project_id,
      type_id,
      "Blocked",
      user_id,
      None,
    )
  let assert Ok(depends_on_id) =
    seed_db.insert_task_simple(
      db,
      project_id,
      type_id,
      "Dependency",
      user_id,
      None,
    )

  let assert Ok(Nil) =
    seed_db.insert_task_dependency(db, blocked_id, depends_on_id, user_id)

  let assert Ok(dependency_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from task_dependencies where task_id = $1 and depends_on_task_id = $2",
      [pog.int(blocked_id), pog.int(depends_on_id)],
    )

  dependency_count |> expect.equal(1)
}
