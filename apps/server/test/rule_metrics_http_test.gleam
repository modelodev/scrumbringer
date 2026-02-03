//// Tests for rule metrics HTTP endpoints.
////
//// Validates metrics aggregation, date filtering, drill-down to executions,
//// and authorization for admin-only access.

import fixtures
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import gleeunit/should
import pog
import scrumbringer_server
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
      "completed",
    )

  let res = get_workflow_metrics(handler, session, workflow_id)
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_workflow_id(body) |> should.equal(workflow_id)
  let _ = decode_totals_evaluated(body) |> should.equal(0)
  let _ = decode_totals_applied(body) |> should.equal(0)
  let _ = decode_totals_suppressed(body) |> should.equal(0)

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
      "completed",
    )

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", 1, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", 2, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      3,
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
      4,
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
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_data_int(body, "evaluated_count") |> should.equal(4)
  let _ = decode_data_int(body, "applied_count") |> should.equal(2)
  let _ = decode_data_int(body, "suppressed_count") |> should.equal(2)

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
      "completed",
    )

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      1,
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
      2,
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
      3,
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
      4,
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
      5,
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
      6,
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
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_breakdown_field(body, "idempotent") |> should.equal(3)
  let _ = decode_breakdown_field(body, "not_user_triggered") |> should.equal(1)
  let _ = decode_breakdown_field(body, "not_matching") |> should.equal(1)
  let _ = decode_breakdown_field(body, "inactive") |> should.equal(1)

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
      "completed",
    )
  let assert Ok(rule2_id) =
    fixtures.create_rule(
      handler,
      session,
      workflow_id,
      Some(type_id),
      "Rule 2",
      "completed",
    )

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(db, rule1_id, admin_id, "task", 1, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(db, rule1_id, admin_id, "task", 2, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule1_id,
      admin_id,
      "task",
      3,
      "suppressed",
      "idempotent",
      ts,
    )

  let assert Ok(Nil) =
    insert_execution(db, rule2_id, admin_id, "task", 4, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule2_id,
      admin_id,
      "task",
      5,
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
      6,
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
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_totals_evaluated(body) |> should.equal(6)
  let _ = decode_totals_applied(body) |> should.equal(3)
  let _ = decode_totals_suppressed(body) |> should.equal(3)

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
      "completed",
    )

  let ts = execution_time()
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", 1, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", 2, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      3,
      "suppressed",
      "idempotent",
      ts,
    )
  let assert Ok(Nil) =
    insert_execution(db, rule_id, admin_id, "task", 4, "applied", "", ts)
  let assert Ok(Nil) =
    insert_execution(
      db,
      rule_id,
      admin_id,
      "task",
      5,
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
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_pagination_total(body) |> should.equal(5)
  let _ = decode_pagination_limit(body) |> should.equal(2)
  let _ = decode_pagination_offset(body) |> should.equal(0)

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
      "completed",
    )

  let res = get_rule_executions(handler, session, rule_id, None, None)
  res.status |> should.equal(200)

  let body = simulate.read_body(res)
  let _ = decode_pagination_total(body) |> should.equal(0)

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

  res.status |> should.equal(400)

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
  res.status |> should.equal(403)

  Nil
}

pub fn org_admin_can_access_org_metrics_test() {
  let assert Ok(#(_app, handler, session)) = fixtures.bootstrap()

  let res = get_org_metrics(handler, session)
  res.status |> should.equal(200)

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
  origin_type: String,
  origin_id: Int,
  outcome: String,
  suppression_reason: String,
  created_at: timestamp.Timestamp,
) -> Result(Nil, String) {
  let sql =
    "INSERT INTO rule_executions (rule_id, origin_type, origin_id, outcome, suppression_reason, user_id, created_at) "
    <> "VALUES ($1, $2, $3, $4, NULLIF($5, ''), $6, $7)"

  pog.query(sql)
  |> pog.parameter(pog.int(rule_id))
  |> pog.parameter(pog.text(origin_type))
  |> pog.parameter(pog.int(origin_id))
  |> pog.parameter(pog.text(outcome))
  |> pog.parameter(pog.text(suppression_reason))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.timestamp(created_at))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_execution failed: " <> string.inspect(e) })
}

// =============================================================================
// Response Decoders
// =============================================================================

fn decode_workflow_id(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use workflow_id <- decode.field("workflow_id", decode.int)
      decode.success(workflow_id)
    })
    decode.success(data)
  }

  let assert Ok(workflow_id) = decode.run(dynamic, response_decoder)
  workflow_id
}

fn decode_totals_evaluated(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use totals <- decode.field("totals", {
        use evaluated_count <- decode.field("evaluated_count", decode.int)
        decode.success(evaluated_count)
      })
      decode.success(totals)
    })
    decode.success(data)
  }

  let assert Ok(evaluated_count) = decode.run(dynamic, response_decoder)
  evaluated_count
}

fn decode_totals_applied(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use totals <- decode.field("totals", {
        use applied_count <- decode.field("applied_count", decode.int)
        decode.success(applied_count)
      })
      decode.success(totals)
    })
    decode.success(data)
  }

  let assert Ok(applied_count) = decode.run(dynamic, response_decoder)
  applied_count
}

fn decode_totals_suppressed(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use totals <- decode.field("totals", {
        use suppressed_count <- decode.field("suppressed_count", decode.int)
        decode.success(suppressed_count)
      })
      decode.success(totals)
    })
    decode.success(data)
  }

  let assert Ok(suppressed_count) = decode.run(dynamic, response_decoder)
  suppressed_count
}

fn decode_data_int(body: String, field: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use value <- decode.field(field, decode.int)
      decode.success(value)
    })
    decode.success(data)
  }

  let assert Ok(value) = decode.run(dynamic, response_decoder)
  value
}

fn decode_breakdown_field(body: String, field: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use breakdown <- decode.field("suppression_breakdown", {
        use value <- decode.field(field, decode.int)
        decode.success(value)
      })
      decode.success(breakdown)
    })
    decode.success(data)
  }

  let assert Ok(value) = decode.run(dynamic, response_decoder)
  value
}

fn decode_pagination_total(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use pagination <- decode.field("pagination", {
        use total <- decode.field("total", decode.int)
        decode.success(total)
      })
      decode.success(pagination)
    })
    decode.success(data)
  }

  let assert Ok(total) = decode.run(dynamic, response_decoder)
  total
}

fn decode_pagination_limit(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use pagination <- decode.field("pagination", {
        use limit <- decode.field("limit", decode.int)
        decode.success(limit)
      })
      decode.success(pagination)
    })
    decode.success(data)
  }

  let assert Ok(limit) = decode.run(dynamic, response_decoder)
  limit
}

fn decode_pagination_offset(body: String) -> Int {
  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let response_decoder = {
    use data <- decode.field("data", {
      use pagination <- decode.field("pagination", {
        use offset <- decode.field("offset", decode.int)
        decode.success(offset)
      })
      decode.success(pagination)
    })
    decode.success(data)
  }

  let assert Ok(offset) = decode.run(dynamic, response_decoder)
  offset
}
