//// Tests for rule metrics HTTP endpoints.
////
//// Validates metrics aggregation, date filtering, drill-down to executions,
//// and authorization for admin-only access.

import domain/task_status
import fixtures
import gleam/http
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

// =============================================================================
// Aggregated Metrics Tests
// =============================================================================

pub fn workflow_metrics_empty_returns_zero_counters_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: _db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "MetricsTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Test Workflow")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(_rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Test Rule",
      task_status.Done,
    )

  let res = get_workflow_metrics(handler, session, workflow_id)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "workflow_id"], workflow_id)
  expect.expect_json_field_int(body, ["data", "totals", "evaluated_count"], 0)
  expect.expect_json_field_int(body, ["data", "totals", "applied_count"], 0)
  expect.expect_json_field_int(body, ["data", "totals", "suppressed_count"], 0)

  Nil
}

pub fn rule_metrics_returns_correct_counts_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "MetricsCountsTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Counts Workflow")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Feature", "star")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Counts Rule",
      task_status.Done,
    )
  let assert Ok(task1_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Metric 1")
  let assert Ok(task2_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Metric 2")
  let assert Ok(task3_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Metric 3")
  let assert Ok(task4_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Metric 4")

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", task1_id, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", task2_id, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task3_id,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task4_id,
      "suppressed",
      "not_user_triggered",
      ts,
    )

  // Use explicit wide date range to avoid timing issues
  let res =
    get_rule_metrics_with_dates(
      handler,
      session,
      rule_id,
      "2025-11-15T00:00:00Z",
      "2026-01-30T23:59:59Z",
    )
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "evaluated_count"], 4)
  expect.expect_json_field_int(body, ["data", "applied_count"], 2)
  expect.expect_json_field_int(body, ["data", "suppressed_count"], 2)

  Nil
}

pub fn rule_metrics_suppression_breakdown_is_correct_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "BreakdownTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Breakdown Workflow")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Task", "check")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Breakdown Rule",
      task_status.Done,
    )
  let assert Ok(task1_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 1")
  let assert Ok(task2_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 2")
  let assert Ok(task3_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 3")
  let assert Ok(task4_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 4")
  let assert Ok(task5_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 5")
  let assert Ok(task6_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Breakdown 6")

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task1_id,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task2_id,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task3_id,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task4_id,
      "suppressed",
      "not_user_triggered",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task5_id,
      "suppressed",
      "not_matching",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task6_id,
      "suppressed",
      "inactive",
      ts,
    )

  let res =
    get_rule_metrics_with_dates(
      handler,
      session,
      rule_id,
      "2025-11-15T00:00:00Z",
      "2026-01-30T23:59:59Z",
    )
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(
    body,
    ["data", "suppression_breakdown", "idempotent"],
    3,
  )
  expect.expect_json_field_int(
    body,
    ["data", "suppression_breakdown", "not_user_triggered"],
    1,
  )
  expect.expect_json_field_int(
    body,
    ["data", "suppression_breakdown", "not_matching"],
    1,
  )
  expect.expect_json_field_int(
    body,
    ["data", "suppression_breakdown", "inactive"],
    1,
  )

  Nil
}

pub fn workflow_metrics_aggregates_all_rules_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "AggregationTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Aggregation Workflow",
    )
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Item", "box")
  let assert Ok(rule1_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Rule 1",
      task_status.Done,
    )
  let assert Ok(rule2_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Rule 2",
      task_status.Done,
    )
  let assert Ok(task1_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 1")
  let assert Ok(task2_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 2")
  let assert Ok(task3_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 3")
  let assert Ok(task4_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 4")
  let assert Ok(task5_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 5")
  let assert Ok(task6_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Aggregate 6")

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule1_id,
      admin_id,
      "task",
      task1_id,
      "applied",
      "",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule1_id,
      admin_id,
      "task",
      task2_id,
      "applied",
      "",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule1_id,
      admin_id,
      "task",
      task3_id,
      "suppressed",
      "idempotent",
      ts,
    )

  let assert Ok(Nil) =
    insert_execution(
      db,
      rule2_id,
      admin_id,
      "task",
      task4_id,
      "applied",
      "",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule2_id,
      admin_id,
      "task",
      task5_id,
      "suppressed",
      "not_user_triggered",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule2_id,
      admin_id,
      "task",
      task6_id,
      "suppressed",
      "not_matching",
      ts,
    )

  let res =
    get_workflow_metrics_with_dates(
      handler,
      session,
      workflow_id,
      "2025-11-15T00:00:00Z",
      "2026-01-30T23:59:59Z",
    )
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "totals", "evaluated_count"], 6)
  expect.expect_json_field_int(body, ["data", "totals", "applied_count"], 3)
  expect.expect_json_field_int(body, ["data", "totals", "suppressed_count"], 3)

  Nil
}

// =============================================================================
// Executions Drill-down Tests
// =============================================================================

pub fn executions_list_returns_paginated_results_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app
  let assert Ok(admin_id) = fixtures.get_user_id(db, "admin@example.com")

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "ExecutionsTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(
      handler,
      session,
      project_id,
      "Executions Workflow",
    )
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Story", "bookmark")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Executions Rule",
      task_status.Done,
    )
  let assert Ok(task1_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Execution 1")
  let assert Ok(task2_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Execution 2")
  let assert Ok(task3_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Execution 3")
  let assert Ok(task4_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Execution 4")
  let assert Ok(task5_id) =
    fixtures.create_task(handler, session, project_id, type_id, "Execution 5")

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", task1_id, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", task2_id, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task3_id,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", task4_id, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      task5_id,
      "suppressed",
      "not_user_triggered",
      ts,
    )

  let res =
    get_rule_executions_with_dates(
      handler,
      session,
      rule_id,
      Some(2),
      Some(0),
      "2025-11-15T00:00:00Z",
      "2026-01-30T23:59:59Z",
    )
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "pagination", "total"], 5)
  expect.expect_json_field_int(body, ["data", "pagination", "limit"], 2)
  expect.expect_json_field_int(body, ["data", "pagination", "offset"], 0)

  Nil
}

pub fn executions_list_empty_returns_empty_array_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: _db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "EmptyExecutionsTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Empty Workflow")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Epic", "layers")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Empty Rule",
      task_status.Done,
    )

  let res = get_rule_executions(handler, session, rule_id, None, None)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  expect.expect_json_field_int(body, ["data", "pagination", "total"], 0)

  Nil
}

// =============================================================================
// Date Range Filtering Tests
// =============================================================================

pub fn date_range_exceeds_90_days_returns_error_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "DateRangeTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "DateRange Workflow")

  let res =
    get_workflow_metrics_with_dates(
      handler,
      session,
      workflow_id,
      "2026-01-01T00:00:00Z",
      "2026-04-15T00:00:00Z",
    )

  expect.expect_status(res, 400)

  Nil
}

pub fn invalid_from_date_returns_validation_error_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "InvalidFromDateTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Invalid From")

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/workflows/"
          <> int.to_string(workflow_id)
          <> "/metrics?from=not-a-date",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 422)
  let assert True = string.contains(simulate.read_body(res), "Invalid from")

  Nil
}

pub fn invalid_execution_limit_returns_validation_error_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "InvalidLimitTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Invalid Limit")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Invalid Limit Rule",
      task_status.Done,
    )

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/rules/" <> int.to_string(rule_id) <> "/executions?limit=101",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 422)
  let assert True = string.contains(simulate.read_body(res), "Invalid limit")

  Nil
}

pub fn duplicate_execution_offset_returns_validation_error_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "DuplicateOffsetTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Duplicate Offset")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug")
  let assert Ok(rule_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Duplicate Offset Rule",
      task_status.Done,
    )

  let res =
    handler(
      simulate.request(
        http.Get,
        "/api/v1/rules/"
          <> int.to_string(rule_id)
          <> "/executions?offset=0&offset=1",
      )
      |> fixtures.with_auth(session),
    )

  expect.expect_status(res, 422)
  let assert True = string.contains(simulate.read_body(res), "Invalid offset")

  Nil
}

// =============================================================================
// Authorization Tests
// =============================================================================

pub fn member_cannot_access_workflow_metrics_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "AuthzTest")
  let assert Ok(workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Authz Workflow")

  let assert Ok(member_id) =
    fixtures.create_member_user(
      handler,
      db,
      "member@example.com",
      "member_invite_token",
    )
  let assert Ok(member_session) =
    fixtures.login(handler, "member@example.com", "passwordpassword")

  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, member_id, "member")

  let res = get_workflow_metrics(handler, member_session, workflow_id)
  expect.expect_status(res, 403)

  Nil
}

pub fn project_manager_can_access_project_rule_metrics_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) =
    fixtures.create_project(handler, session, "ProjectMetricsAuthzTest")
  let assert Ok(_workflow_id) =
    fixtures.create_workflow(handler, session, project_id, "Project Metrics")

  let assert Ok(manager_id) =
    fixtures.create_member_user(
      handler,
      db,
      "manager@example.com",
      "manager_invite_token",
    )
  let assert Ok(manager_session) =
    fixtures.login(handler, "manager@example.com", "passwordpassword")

  let assert Ok(_) =
    fixtures.add_member(handler, session, project_id, manager_id, "manager")

  let res = get_project_metrics(handler, manager_session, project_id)
  expect.expect_status(res, 200)

  Nil
}

pub fn org_admin_can_access_org_metrics_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = get_org_metrics(handler, session)
  expect.expect_status(res, 200)

  Nil
}

// =============================================================================
// Request Helpers
// =============================================================================

fn get_workflow_metrics(handler, session, workflow_id: Int) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/workflows/" <> int.to_string(workflow_id) <> "/metrics",
    )
    |> fixtures.with_auth(session),
  )
}

fn get_workflow_metrics_with_dates(
  handler,
  session,
  workflow_id: Int,
  from: String,
  to: String,
) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/workflows/"
        <> int.to_string(workflow_id)
        <> "/metrics?from="
        <> from
        <> "&to="
        <> to,
    )
    |> fixtures.with_auth(session),
  )
}

fn get_rule_metrics_with_dates(
  handler,
  session,
  rule_id: Int,
  from: String,
  to: String,
) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/rules/"
        <> int.to_string(rule_id)
        <> "/metrics?from="
        <> from
        <> "&to="
        <> to,
    )
    |> fixtures.with_auth(session),
  )
}

fn get_rule_executions(handler, session, rule_id: Int, limit, offset) {
  let base_path = "/api/v1/rules/" <> int.to_string(rule_id) <> "/executions"
  let path = case limit, offset {
    Some(l), Some(o) ->
      base_path
      <> "?limit="
      <> int.to_string(l)
      <> "&offset="
      <> int.to_string(o)
    Some(l), None -> base_path <> "?limit=" <> int.to_string(l)
    None, Some(o) -> base_path <> "?offset=" <> int.to_string(o)
    None, None -> base_path
  }
  handler(
    simulate.request(http.Get, path)
    |> fixtures.with_auth(session),
  )
}

fn get_rule_executions_with_dates(
  handler,
  session,
  rule_id: Int,
  limit,
  offset,
  from: String,
  to: String,
) {
  let base_path =
    "/api/v1/rules/"
    <> int.to_string(rule_id)
    <> "/executions?from="
    <> from
    <> "&to="
    <> to
  let path = case limit, offset {
    Some(l), Some(o) ->
      base_path
      <> "&limit="
      <> int.to_string(l)
      <> "&offset="
      <> int.to_string(o)
    Some(l), None -> base_path <> "&limit=" <> int.to_string(l)
    None, Some(o) -> base_path <> "&offset=" <> int.to_string(o)
    None, None -> base_path
  }
  handler(
    simulate.request(http.Get, path)
    |> fixtures.with_auth(session),
  )
}

fn get_project_metrics(handler, session, project_id: Int) {
  handler(
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/rule-metrics",
    )
    |> fixtures.with_auth(session),
  )
}

fn get_org_metrics(handler, session) {
  handler(
    simulate.request(http.Get, "/api/v1/org/rule-metrics")
    |> fixtures.with_auth(session),
  )
}

// =============================================================================
// Database Helpers
// =============================================================================

fn execution_time() -> timestamp.Timestamp {
  let assert Ok(ts) = timestamp.parse_rfc3339("2026-01-15T12:00:00Z")
  ts
}

fn insert_execution(
  db: pog.Connection,
  rule_id: Int,
  user_id: Int,
  target_type: String,
  target_id: Int,
  outcome: String,
  suppression_reason: String,
  created_at: timestamp.Timestamp,
) -> Result(Nil, String) {
  let sql =
    "INSERT INTO rule_executions (rule_id, task_id, card_id, outcome, suppression_reason, user_id, created_at) "
    <> "VALUES ($1, CASE WHEN $2 = 'task' THEN $3::bigint ELSE NULL END, CASE WHEN $2 = 'card' THEN $3::bigint ELSE NULL END, $4, NULLIF($5, ''), $6, $7)"

  pog.query(sql)
  |> pog.parameter(pog.int(rule_id))
  |> pog.parameter(pog.text(target_type))
  |> pog.parameter(pog.int(target_id))
  |> pog.parameter(pog.text(outcome))
  |> pog.parameter(pog.text(suppression_reason))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.timestamp(created_at))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_execution failed: " <> string.inspect(e) })
}
