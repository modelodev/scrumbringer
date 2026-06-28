import fixtures
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import pog
import scrumbringer_server/repository/tasks/queries as tasks_queries
import scrumbringer_server/use_case/workflows/claimable_task
import support/assertions as expect
import wisp/simulate

pub fn direct_claim_update_active_card_succeeds_test() {
  let assert Ok(ctx) = create_card_task_context("DB active claim", "active")

  let assert Ok(_) = direct_claim_update(ctx.db, ctx.task_id, ctx.user_id)

  let assert Ok(state) =
    fixtures.query_string(ctx.db, task_state_query(), [pog.int(ctx.task_id)])
  state |> expect.equal("claimed")
}

pub fn direct_claim_update_draft_card_fails_test() {
  let assert Ok(ctx) = create_card_task_context("DB draft claim", "draft")

  let assert Error(_) = direct_claim_update(ctx.db, ctx.task_id, ctx.user_id)
}

pub fn direct_claim_update_closed_card_fails_test() {
  let assert Ok(ctx) = create_card_task_context("DB closed claim", "closed")

  let assert Error(_) = direct_claim_update(ctx.db, ctx.task_id, ctx.user_id)
}

pub fn direct_claim_update_closed_ancestor_fails_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("DB closed ancestor")
  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Closed root")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      root_card_id,
      "Active child",
    )
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      child_card_id,
      "Child task",
    )
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  set_card_state(db, root_card_id, "closed")
  set_card_state(db, child_card_id, "active")

  let assert Error(_) = direct_claim_update(db, task_id, user_id)
}

pub fn direct_claim_update_without_card_fails_test() {
  let #(db, _handler, _session, project_id, type_id) =
    fixtures.require_task_project("DB no card claim")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    insert_no_card_task(db, project_id, type_id, user_id, "No card task")

  let assert Error(_) = direct_claim_update(db, task_id, user_id)
}

pub fn direct_claim_update_missing_claim_fields_fails_test() {
  let assert Ok(ctx) = create_card_task_context("DB incomplete claim", "active")

  let assert Error(_) = direct_claim_update_without_owner(ctx.db, ctx.task_id)
}

pub fn closing_card_with_claimed_descendant_fails_test() {
  let assert Ok(ctx) = create_card_task_context("DB close claimed", "active")
  let assert Ok(_) = direct_claim_update(ctx.db, ctx.task_id, ctx.user_id)

  let assert Error(_) = set_card_state_result(ctx.db, ctx.card_id, "closed")
}

pub fn moving_claimed_card_under_closed_ancestor_fails_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("DB move claimed")
  let assert Ok(closed_parent_id) =
    fixtures.create_card(handler, session, project_id, "Closed parent")
  let assert Ok(work_card_id) =
    fixtures.create_card(handler, session, project_id, "Active work")
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      work_card_id,
      "Move protected task",
    )
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  set_card_state(db, closed_parent_id, "closed")
  set_card_state(db, work_card_id, "active")
  let assert Ok(_) = direct_claim_update(db, task_id, user_id)

  let assert Error(_) = move_card_parent(db, work_card_id, closed_parent_id)
}

pub fn claimable_task_constructor_rejects_draft_card_test() {
  let assert Ok(ctx) =
    create_card_task_context("Repository draft claim", "draft")

  let assert Ok(task) =
    tasks_queries.get_task_for_user(ctx.db, ctx.task_id, ctx.user_id)
  let assert Error(claimable_task.InactiveCardLineage) =
    claimable_task.from_task(ctx.db, task)
  assert_task_still_available(ctx.db, ctx.task_id)
  assert_task_claim_audit_count(ctx.db, ctx.task_id, 0)
}

pub fn claimable_task_constructor_rejects_closed_card_test() {
  let assert Ok(ctx) =
    create_card_task_context("Repository closed claim", "closed")

  let assert Ok(task) =
    tasks_queries.get_task_for_user(ctx.db, ctx.task_id, ctx.user_id)
  let assert Error(claimable_task.InactiveCardLineage) =
    claimable_task.from_task(ctx.db, task)
  assert_task_still_available(ctx.db, ctx.task_id)
  assert_task_claim_audit_count(ctx.db, ctx.task_id, 0)
}

pub fn claimable_task_constructor_rejects_closed_ancestor_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("Repository closed ancestor")
  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Closed root")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      root_card_id,
      "Active child",
    )
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      child_card_id,
      "Repository child task",
    )
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  set_card_state(db, root_card_id, "closed")
  set_card_state(db, child_card_id, "active")

  let assert Ok(task) = tasks_queries.get_task_for_user(db, task_id, user_id)
  let assert Error(claimable_task.InactiveCardLineage) =
    claimable_task.from_task(db, task)
  assert_task_still_available(db, task_id)
  assert_task_claim_audit_count(db, task_id, 0)
}

pub fn repository_claim_active_card_task_inserts_one_audit_event_test() {
  let assert Ok(ctx) =
    create_card_task_context("Repository active claim", "active")

  let assert Ok(task) =
    tasks_queries.get_task_for_user(ctx.db, ctx.task_id, ctx.user_id)
  let assert Ok(claimable) = claimable_task.from_task(ctx.db, task)
  let assert Ok(_) =
    tasks_queries.claim_task(ctx.db, ctx.org_id, claimable, ctx.user_id, 1)

  let assert Ok(state) =
    fixtures.query_string(ctx.db, task_state_query(), [pog.int(ctx.task_id)])
  state |> expect.equal("claimed")
  assert_task_claim_audit_count(ctx.db, ctx.task_id, 1)
}

pub fn http_claim_draft_card_task_is_rejected_test() {
  let assert Ok(ctx) = create_card_task_context("HTTP draft claim", "draft")

  let res = claim_request(ctx.handler, ctx.session, ctx.task_id, 1)

  assert_card_not_active_response(res)
  assert_task_still_available(ctx.db, ctx.task_id)
  assert_task_claim_audit_count(ctx.db, ctx.task_id, 0)
}

pub fn http_claim_closed_card_task_is_rejected_test() {
  let assert Ok(ctx) = create_card_task_context("HTTP closed claim", "closed")

  let res = claim_request(ctx.handler, ctx.session, ctx.task_id, 1)

  assert_card_not_active_response(res)
  assert_task_still_available(ctx.db, ctx.task_id)
  assert_task_claim_audit_count(ctx.db, ctx.task_id, 0)
}

pub fn http_claim_closed_ancestor_task_is_rejected_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("HTTP closed ancestor")
  let assert Ok(root_card_id) =
    fixtures.create_card(handler, session, project_id, "Closed root")
  let assert Ok(child_card_id) =
    fixtures.create_child_card(
      handler,
      session,
      project_id,
      root_card_id,
      "Active child",
    )
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      child_card_id,
      "HTTP child task",
    )
  set_card_state(db, root_card_id, "closed")
  set_card_state(db, child_card_id, "active")

  let res = claim_request(handler, session, task_id, 1)

  assert_card_not_active_response(res)
  assert_task_still_available(db, task_id)
  assert_task_claim_audit_count(db, task_id, 0)
}

pub fn http_claim_without_card_task_is_rejected_test() {
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project("HTTP no card claim")
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(task_id) =
    insert_no_card_task(db, project_id, type_id, user_id, "HTTP no card task")

  let res = claim_request(handler, session, task_id, 1)

  assert_card_not_active_response(res)
  assert_task_still_available(db, task_id)
  assert_task_claim_audit_count(db, task_id, 0)
}

type CardTaskContext {
  CardTaskContext(
    db: pog.Connection,
    handler: fixtures.Handler,
    session: fixtures.Session,
    card_id: Int,
    task_id: Int,
    user_id: Int,
    org_id: Int,
  )
}

fn create_card_task_context(
  title: String,
  card_state: String,
) -> Result(CardTaskContext, String) {
  let project_name = title <> " project"
  let card_title = title <> " card"
  let task_title = title <> " task"
  let #(db, handler, session, project_id, type_id) =
    fixtures.require_task_project(project_name)
  let assert Ok(card_id) =
    fixtures.create_card(handler, session, project_id, card_title)
  let assert Ok(task_id) =
    fixtures.create_task_with_card(
      handler,
      session,
      project_id,
      type_id,
      card_id,
      task_title,
    )
  let assert Ok(user_id) = fixtures.get_user_id(db, "admin@example.com")
  let assert Ok(org_id) =
    fixtures.query_int(db, "select org_id from users where id = $1", [
      pog.int(user_id),
    ])
  set_card_state(db, card_id, card_state)
  Ok(CardTaskContext(
    db: db,
    handler: handler,
    session: session,
    card_id: card_id,
    task_id: task_id,
    user_id: user_id,
    org_id: org_id,
  ))
}

fn claim_request(
  handler: fixtures.Handler,
  session: fixtures.Session,
  task_id: Int,
  version: Int,
) {
  handler(
    simulate.request(
      http.Post,
      "/api/v1/tasks/" <> int.to_string(task_id) <> "/claim",
    )
    |> fixtures.with_auth(session)
    |> simulate.json_body(json.object([#("version", json.int(version))])),
  )
}

fn direct_claim_update(db: pog.Connection, task_id: Int, user_id: Int) {
  pog.query(
    "update tasks
     set execution_state = 'claimed',
         claimed_by = $1,
         claimed_at = now(),
         claimed_mode = 'taken'
     where id = $2",
  )
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.execute(db)
}

fn direct_claim_update_without_owner(db: pog.Connection, task_id: Int) {
  pog.query(
    "update tasks
     set execution_state = 'claimed',
         claimed_at = now(),
         claimed_mode = 'taken'
     where id = $1",
  )
  |> pog.parameter(pog.int(task_id))
  |> pog.execute(db)
}

fn insert_no_card_task(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  user_id: Int,
  title: String,
) {
  fixtures.query_int(
    db,
    "insert into tasks (
       project_id,
       type_id,
       title,
       description,
       priority,
       execution_state,
       created_by
     ) values ($1, $2, $3, '', 3, 'available', $4)
     returning id",
    [pog.int(project_id), pog.int(type_id), pog.text(title), pog.int(user_id)],
  )
}

fn set_card_state(db: pog.Connection, card_id: Int, state: String) {
  let assert Ok(_) = set_card_state_result(db, card_id, state)
  Nil
}

fn set_card_state_result(db: pog.Connection, card_id: Int, state: String) {
  pog.query("update cards set execution_state = $1 where id = $2")
  |> pog.parameter(pog.text(state))
  |> pog.parameter(pog.int(card_id))
  |> pog.execute(db)
}

fn move_card_parent(db: pog.Connection, card_id: Int, parent_card_id: Int) {
  pog.query("update cards set parent_card_id = $1 where id = $2")
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.parameter(pog.int(card_id))
  |> pog.execute(db)
}

fn assert_task_still_available(db: pog.Connection, task_id: Int) {
  let assert Ok(state) =
    fixtures.query_string(db, task_state_query(), [pog.int(task_id)])
  state |> expect.equal("available")

  let assert Ok(claimed_by) =
    fixtures.query_int(
      db,
      "select coalesce(claimed_by, 0)::int from tasks where id = $1",
      [pog.int(task_id)],
    )
  claimed_by |> expect.equal(0)
}

fn assert_task_claim_audit_count(
  db: pog.Connection,
  task_id: Int,
  expected: Int,
) {
  let assert Ok(count) =
    fixtures.query_int(
      db,
      "select count(*)::int
       from audit_events
       where task_id = $1
         and event_type = 'task_claimed'",
      [pog.int(task_id)],
    )
  count |> expect.equal(expected)
}

fn assert_card_not_active_response(response) {
  expect.expect_status(response, 409)
  let body = simulate.read_body(response)
  let assert True = string.contains(body, "TASK_CARD_NOT_ACTIVE")
}

fn task_state_query() -> String {
  "select execution_state from tasks where id = $1"
}
