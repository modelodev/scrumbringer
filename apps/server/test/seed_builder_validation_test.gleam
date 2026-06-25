import fixtures
import gleam/result
import pog
import scrumbringer_server
import scrumbringer_server/seed_builder
import support/assertions as expect

pub fn realistic_seed_marks_healthy_and_stress_pool_projects_test() {
  let assert Ok(#(db, _org_id, _admin_id)) = build_realistic_seed()

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
  // Covers the seed_automation_diagnostics scenario module.
  let assert Ok(#(db, _org_id, _admin_id)) = build_realistic_seed()

  let assert Ok(selected_rule_count) =
    fixtures.query_int(
      db,
      "select count(distinct r.id)::int
       from rules r
       join rule_templates rt on rt.rule_id = r.id
       where r.name like 'On Task Done%'",
      [],
    )
  let assert Ok(unused_template_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from task_templates tt
       left join rule_templates rt on rt.template_id = tt.id
       where rt.template_id is null",
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
  let assert Ok(ignored_duplicate_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from rule_executions re
       join rules r on r.id = re.rule_id
       join workflows w on w.id = r.workflow_id
       join projects p on p.id = w.project_id
       where p.name = 'Stress Validation Project'
         and re.outcome = 'suppressed'
         and re.suppression_reason = 'idempotent'
         and re.event_key like 'seed:duplicate:stress:%'
         and re.created_task_id is null",
      [],
    )
  let assert Ok(noisy_engine_execution_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from rule_executions re
       join rules r on r.id = re.rule_id
       join workflows w on w.id = r.workflow_id
       join projects p on p.id = w.project_id
       join tasks t on t.id = re.created_task_id
       where p.name = 'Stress Validation Project'
         and re.outcome = 'applied'
         and re.event_key like 'seed:noisy:stress:%'
         and re.template_id is not null
         and re.template_version > 0
         and t.created_from_rule_id = re.rule_id
         and t.execution_state = 'available'",
      [],
    )

  { selected_rule_count > 0 } |> expect.is_true
  { unused_template_count > 0 } |> expect.is_true
  stress_missing_template_count |> expect.equal(1)
  { applied_execution_count > 0 } |> expect.is_true
  { created_task_trace_count > 0 } |> expect.is_true
  ignored_duplicate_count |> expect.equal(1)
  noisy_engine_execution_count |> expect.equal(8)
}

pub fn realistic_seed_covers_cards_tasks_and_due_dates_test() {
  let assert Ok(#(db, _org_id, _admin_id)) = build_realistic_seed()

  let assert Ok(card_state_count) =
    fixtures.query_int(
      db,
      "select count(distinct execution_state)::int
       from cards
       where execution_state in ('draft', 'active', 'closed')",
      [],
    )
  let assert Ok(loose_task_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where card_id is null",
      [],
    )
  let assert Ok(card_task_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where card_id is not null",
      [],
    )
  let assert Ok(closed_task_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where execution_state = 'closed'
         and closed_at is not null",
      [],
    )
  let assert Ok(overdue_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where due_date < CURRENT_DATE
         and execution_state <> 'closed'",
      [],
    )
  let assert Ok(due_today_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where due_date = CURRENT_DATE
         and execution_state <> 'closed'",
      [],
    )
  let assert Ok(due_soon_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from tasks
       where due_date > CURRENT_DATE
         and due_date <= CURRENT_DATE + 7
         and execution_state <> 'closed'",
      [],
    )
  let assert Ok(blocked_task_count) =
    fixtures.query_int(
      db,
      "select count(distinct task_id)::int
       from task_dependencies",
      [],
    )

  card_state_count |> expect.equal(3)
  { loose_task_count > 0 } |> expect.is_true
  { card_task_count > 0 } |> expect.is_true
  { closed_task_count > 0 } |> expect.is_true
  { overdue_count > 0 } |> expect.is_true
  { due_today_count > 0 } |> expect.is_true
  { due_soon_count > 0 } |> expect.is_true
  { blocked_task_count > 0 } |> expect.is_true
}

pub fn realistic_seed_covers_people_capabilities_notes_and_activity_test() {
  // Covers the seed_activity_scenarios support module.
  let assert Ok(#(db, _org_id, _admin_id)) = build_realistic_seed()

  let assert Ok(active_user_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from users
       where first_login_at is not null",
      [],
    )
  let assert Ok(capability_count) =
    fixtures.query_int(db, "select count(*)::int from capabilities", [])
  let assert Ok(member_capability_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from project_member_capabilities",
      [],
    )
  let assert Ok(seed_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join task_notes tn on tn.note_id = n.id
       where n.content like 'Seed note:%'",
      [],
    )
  let assert Ok(pinned_task_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join task_notes tn on tn.note_id = n.id
       where n.content like 'Seed note:%'
         and n.pinned = true",
      [],
    )
  let assert Ok(unpinned_task_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join task_notes tn on tn.note_id = n.id
       where n.content like 'Seed note:%'
         and n.pinned = false",
      [],
    )
  let assert Ok(seed_card_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join card_notes cn on cn.note_id = n.id
       where n.content like 'Seed card note:%'",
      [],
    )
  let assert Ok(pinned_card_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join card_notes cn on cn.note_id = n.id
       where n.content like 'Seed card note:%'
         and n.pinned = true",
      [],
    )
  let assert Ok(unpinned_card_note_count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from notes n
       join card_notes cn on cn.note_id = n.id
       where n.content like 'Seed card note:%'
         and n.pinned = false",
      [],
    )
  let assert Ok(activity_count) =
    fixtures.query_int(db, "select count(*)::int from audit_events", [])
  let assert Ok(work_session_count) =
    fixtures.query_int(
      db,
      "select count(*)::int from user_task_work_session",
      [],
    )

  { active_user_count > 1 } |> expect.is_true
  { capability_count > 0 } |> expect.is_true
  { member_capability_count > 0 } |> expect.is_true
  seed_note_count |> expect.equal(5)
  pinned_task_note_count |> expect.equal(1)
  { unpinned_task_note_count > 0 } |> expect.is_true
  seed_card_note_count |> expect.equal(2)
  pinned_card_note_count |> expect.equal(1)
  unpinned_card_note_count |> expect.equal(1)
  { activity_count > 0 } |> expect.is_true
  { work_session_count > 0 } |> expect.is_true
}

fn build_realistic_seed() -> Result(#(pog.Connection, Int, Int), String) {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(org_id) = fixtures.get_org_id(db)
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  use _stats <- result.try(seed_builder.build_seed(
    db,
    org_id,
    admin_id,
    seed_builder.realistic_config(),
  ))

  Ok(#(db, org_id, admin_id))
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
