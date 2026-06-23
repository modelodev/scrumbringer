import fixtures
import pog
import scrumbringer_server
import scrumbringer_server/seed_builder
import support/assertions as expect

pub fn realistic_seed_marks_healthy_and_stress_pool_projects_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(_stats) =
    seed_builder.build_seed(
      db,
      org_id,
      admin_id,
      seed_builder.realistic_config(),
    )

  let assert Ok(healthy_project_id) =
    project_id_by_name(db, "Healthy Validation Project")
  let assert Ok(stress_project_id) =
    project_id_by_name(db, "Stress Validation Project")

  let assert Ok(healthy_limit) = healthy_pool_limit(db, healthy_project_id)
  let assert Ok(stress_limit) = healthy_pool_limit(db, stress_project_id)
  let assert Ok(healthy_pool_count) = open_pool_count(db, healthy_project_id)
  let assert Ok(stress_pool_count) = open_pool_count(db, stress_project_id)

  healthy_limit |> expect.equal(40)
  stress_limit |> expect.equal(6)
  { healthy_pool_count <= healthy_limit } |> expect.is_true
  { stress_pool_count > stress_limit } |> expect.is_true
}

fn project_id_by_name(db: pog.Connection, name: String) -> Result(Int, String) {
  fixtures.query_int(db, "select id::int from projects where name = $1", [
    pog.text(name),
  ])
}

fn healthy_pool_limit(
  db: pog.Connection,
  project_id: Int,
) -> Result(Int, String) {
  fixtures.query_int(
    db,
    "select healthy_pool_limit::int from project_settings where project_id = $1",
    [pog.int(project_id)],
  )
}

fn open_pool_count(db: pog.Connection, project_id: Int) -> Result(Int, String) {
  fixtures.query_int(
    db,
    "select count(*)::int from tasks where project_id = $1 and card_id is null and execution_state = 'available' and closed_at is null",
    [pog.int(project_id)],
  )
}
