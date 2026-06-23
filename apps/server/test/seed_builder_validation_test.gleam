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

pub fn realistic_seed_includes_automation_traces_and_warnings_test() {
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

  let assert Ok(selected_rule_count) =
    fixtures.query_int(
      db,
      "select count(distinct r.id)::int
       from rules r
       join rule_templates rt on rt.rule_id = r.id
       where r.name like 'On Task Done%'",
      [],
    )
  let assert Ok(stress_missing_template_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from rules r
       join workflows w on w.id = r.workflow_id
       join projects p on p.id = w.project_id
       left join rule_templates rt on rt.rule_id = r.id
       where p.name = 'Stress Validation Project'
         and r.name = 'Seed warning - template missing'
         and rt.rule_id is null",
      [],
    )
  let assert Ok(applied_execution_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from rule_executions
       where outcome = 'applied'
         and template_id is not null
         and template_version > 0
         and created_task_id is not null",
      [],
    )
  let assert Ok(created_task_trace_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks t
       join rule_executions re on re.created_task_id = t.id
       where t.created_from_rule_id = re.rule_id
         and re.outcome = 'applied'",
      [],
    )

  { selected_rule_count > 0 } |> expect.is_true
  stress_missing_template_count |> expect.equal(1)
  { applied_execution_count > 0 } |> expect.is_true
  { created_task_trace_count > 0 } |> expect.is_true
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
