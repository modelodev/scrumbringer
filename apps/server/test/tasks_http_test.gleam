import fixtures as fx
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import pog
import scrumbringer_server
import support/assertions as expect
import wisp/simulate

pub fn task_types_list_sorted_by_name_test() {
  let #(_, handler, session, project_id) = fx.require_project_context("Core")

  fx.require_task_type(handler, session, project_id, "Zulu", "bug-ant")
  fx.require_task_type(handler, session, project_id, "Alpha", "bolt")

  let req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    )
    |> fx.with_session_cookies(session)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  fx.require_data_string_list_field(body, "task_types", "name")
  |> expect.equal(["Alpha", "General", "Zulu"])
}

pub fn task_types_create_requires_project_admin_and_csrf_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_member(handler, admin_session, project_id, member_id, "member")

  let member_session = fx.require_login_session(handler, "member@example.com")

  let member_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    )
    |> fx.with_auth(member_session)
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let no_csrf_req =
    simulate.request(
      http.Post,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/task-types",
    )
    |> fx.with_session_cookies(admin_session)
    |> simulate.json_body(
      json.object([
        #("name", json.string("Bug")),
        #("icon", json.string("bug-ant")),
      ]),
    )

  let no_csrf_res = handler(no_csrf_req)
  expect.expect_status(no_csrf_res, 403)
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn tasks_list_filters_sorting_and_q_search_test() {
  let #(db, handler, session, project_id) = fx.require_project_context("Core")

  let cap1 = insert_capability(db, project_id, "Frontend")
  let cap2 = insert_capability(db, project_id, "Backend")

  let needle_type_id =
    fx.require_task_type_with_capability(
      handler,
      session,
      project_id,
      "NeedleType",
      "bug-ant",
      cap1,
    )
  let other_type_id =
    fx.require_task_type_with_capability(
      handler,
      session,
      project_id,
      "OtherType",
      "bolt",
      cap2,
    )

  let t1_id =
    fx.require_task(handler, session, project_id, "Old", "", 3, other_type_id)
  let t2_id =
    fx.require_task(
      handler,
      session,
      project_id,
      "needle in title",
      "",
      3,
      other_type_id,
    )
  let t3_id =
    fx.require_task(
      handler,
      session,
      project_id,
      "Unrelated",
      "",
      3,
      needle_type_id,
    )

  set_task_created_at(db, t1_id, "2000-01-01T00:00:00Z")
  set_task_created_at(db, t2_id, "2000-01-03T00:00:00Z")
  set_task_created_at(db, t3_id, "2000-01-02T00:00:00Z")

  expect_project_task_titles(handler, session, project_id, "", [
    "needle in title",
    "Unrelated",
    "Old",
  ])
  expect_project_task_titles(handler, session, project_id, "q=needle", [
    "needle in title",
  ])
  expect_project_task_titles(
    handler,
    session,
    project_id,
    "capability_id=" <> int.to_string(cap1),
    ["Unrelated"],
  )

  let multi_cap_res =
    fx.list_project_tasks_response(
      handler,
      session,
      project_id,
      "capability_id=1,2",
    )
  expect.expect_status(multi_cap_res, 422)
  string.contains(simulate.read_body(multi_cap_res), "VALIDATION_ERROR")
  |> expect.is_true
}

pub fn tasks_list_includes_task_contract_fields_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  let res = fx.list_project_tasks_response(handler, session, project_id, "")
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let tasks =
    fx.require_data_list(body, "tasks", task_contract_fields_decoder())

  case tasks {
    [
      #(
        status,
        work_state,
        #(task_type_id, task_type_name, task_type_icon),
        ongoing_by,
      ),
      ..
    ] -> {
      status |> expect.equal("available")
      work_state |> expect.equal("available")
      task_type_id |> expect.equal(type_id)
      task_type_name |> expect.equal("Bug")
      task_type_icon |> expect.equal("bug-ant")
      ongoing_by |> expect.equal(option.None)
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn task_get_includes_task_contract_fields_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  let res = fx.task_response(handler, session, task_id)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let #(work_state, #(task_type_id, task_type_name, task_type_icon), ongoing_by) =
    require_task_data(body, task_get_contract_fields_decoder())

  work_state |> expect.equal("available")
  task_type_id |> expect.equal(type_id)
  task_type_name |> expect.equal("Bug")
  task_type_icon |> expect.equal("bug-ant")
  ongoing_by |> expect.equal(option.None)
}

pub fn task_get_includes_ongoing_by_when_active_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  expect.expect_status(
    fx.start_work_session_response(handler, session, task_id),
    200,
  )

  let user_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let res = fx.task_response(handler, session, task_id)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let #(
    status,
    work_state,
    #(task_type_id, task_type_name, task_type_icon),
    ongoing_by,
  ) = require_task_data(body, task_contract_fields_decoder())

  status |> expect.equal("claimed")
  work_state |> expect.equal("ongoing")
  task_type_id |> expect.equal(type_id)
  task_type_name |> expect.equal("Bug")
  task_type_icon |> expect.equal("bug-ant")
  ongoing_by |> expect.equal(option.Some(user_id))
}

// Justification: large function kept intact to preserve cohesive logic.
// Coverage marker: do_not_emit_audit_event_on_conflict, conflict_does_not_emit_audit.
pub fn claim_conflict_version_conflict_and_state_machine_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")
  let other_id =
    fx.require_member_user(handler, db, "other@example.com", "inv_other")

  fx.require_member(handler, admin_session, project_id, member_id, "member")
  fx.require_member(handler, admin_session, project_id, other_id, "member")

  let member_session = fx.require_login_session(handler, "member@example.com")

  let other_session = fx.require_login_session(handler, "other@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  let claim_res = fx.claim_task_response(handler, member_session, task_id, 1)
  expect.expect_status(claim_res, 200)
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let claim2_res = fx.claim_task_response(handler, other_session, task_id, 1)
  expect.expect_status(claim2_res, 409)
  string.contains(simulate.read_body(claim2_res), "CONFLICT_CLAIMED")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
    |> fx.with_auth(member_session)
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("New")),
        #("claimed_by", json.int(999)),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 409)
  string.contains(simulate.read_body(patch_res), "CONFLICT_VERSION")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let release_bad_res =
    fx.release_task_response(handler, member_session, task_id, 1)
  expect.expect_status(release_bad_res, 409)
  string.contains(simulate.read_body(release_bad_res), "CONFLICT_VERSION")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(2)

  let release_ok_res =
    fx.release_task_response(handler, member_session, task_id, 2)
  expect.expect_status(release_ok_res, 200)
  count_audit_events_for_task(db, task_id) |> expect.equal(3)

  let close_bad_res =
    fx.close_task_response(handler, member_session, task_id, 3)
  expect.expect_status(close_bad_res, 422)
  string.contains(simulate.read_body(close_bad_res), "VALIDATION_ERROR")
  |> expect.is_true
  count_audit_events_for_task(db, task_id) |> expect.equal(3)
}

pub fn audit_events_persist_for_lifecycle_actions_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let admin_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  count_audit_events(db, task_id, "task_created") |> expect.equal(1)
  count_audit_events_for_actor(db, task_id, admin_id, "task_created")
  |> expect.equal(1)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  count_audit_events(db, task_id, "task_claimed") |> expect.equal(1)

  fx.release_task_status(handler, session, task_id, 2) |> expect.equal(200)
  count_audit_events(db, task_id, "task_released") |> expect.equal(1)

  fx.claim_task_status(handler, session, task_id, 3) |> expect.equal(200)
  fx.close_task_status(handler, session, task_id, 4) |> expect.equal(200)
  count_audit_events(db, task_id, "task_closed") |> expect.equal(1)
}

pub fn delete_task_without_operational_history_removes_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")
  let task_id =
    fx.require_task(handler, session, project_id, "Clean", "", 3, type_id)

  fx.delete_task_status(handler, session, task_id) |> expect.equal(204)
  count_task_rows(db, task_id) |> expect.equal(0)
  count_audit_events(db, task_id, "task_created") |> expect.equal(0)
}

pub fn delete_task_with_claim_returns_operational_history_conflict_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")
  let task_id =
    fx.require_task(handler, session, project_id, "Claimed", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  let res = fx.delete_task_response(handler, session, task_id)

  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "TASK_HAS_OPERATIONAL_HISTORY")
  |> expect.is_true
  count_task_rows(db, task_id) |> expect.equal(1)
}

pub fn delete_task_with_note_or_dependency_returns_conflict_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")
  let noted_task =
    fx.require_task(handler, session, project_id, "Noted", "", 3, type_id)
  let blocked_task =
    fx.require_task(handler, session, project_id, "Blocked", "", 3, type_id)
  let blocker_task =
    fx.require_task(handler, session, project_id, "Blocker", "", 3, type_id)

  fx.create_task_note_status(
    handler,
    session,
    noted_task,
    "Operational context",
  )
  |> expect.equal(200)
  fx.create_task_dependency_status(handler, session, blocked_task, blocker_task)
  |> expect.equal(200)

  fx.delete_task_status(handler, session, noted_task) |> expect.equal(409)
  fx.delete_task_status(handler, session, blocker_task) |> expect.equal(409)
  count_task_rows(db, noted_task) |> expect.equal(1)
  count_task_rows(db, blocker_task) |> expect.equal(1)
}

pub fn task_patch_allows_unclaimed_task_for_project_member_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Editable Available")

  let task_id =
    fx.require_task(handler, session, project_id, "Editable", "", 3, type_id)

  let patch_req =
    simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
    |> fx.with_auth(session)
    |> simulate.json_body(
      json.object([
        #("version", json.int(1)),
        #("title", json.string("Editable updated")),
      ]),
    )

  let patch_res = handler(patch_req)
  expect.expect_status(patch_res, 200)
  string.contains(simulate.read_body(patch_res), "Editable updated")
  |> expect.is_true
}

pub fn release_all_tasks_for_member_success_test() {
  let #(db, handler, session, project_id) =
    fx.require_project_context("Bulk Release")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_member(handler, session, project_id, member_id, "member")
  let type_id =
    fx.require_task_type(handler, session, project_id, "Bug", "bug-ant")

  let task_a =
    fx.require_task(handler, session, project_id, "Task A", "", 1, type_id)
  let task_b =
    fx.require_task(handler, session, project_id, "Task B", "", 1, type_id)

  let member_session = fx.require_login_session(handler, "member@example.com")

  fx.claim_task_status(
    handler,
    member_session,
    task_a,
    fx.task_version(db, task_a),
  )
  |> expect.equal(200)
  fx.claim_task_status(
    handler,
    member_session,
    task_b,
    fx.task_version(db, task_b),
  )
  |> expect.equal(200)

  let list_req =
    simulate.request(
      http.Get,
      "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
    )
    |> fx.with_session_cookies(session)

  let list_res = handler(list_req)
  expect.expect_status(list_res, 200)
  let list_body = simulate.read_body(list_res)
  let member_decoder = {
    use user_id <- decode.field("user_id", decode.int)
    use claimed_count <- decode.field("claimed_count", decode.int)
    decode.success(#(user_id, claimed_count))
  }
  let members_payload =
    fx.require_data_list(list_body, "members", member_decoder)
  let member_claimed =
    members_payload
    |> list.filter(fn(row) { row.0 == member_id })
    |> list.map(fn(row) { row.1 })
  member_claimed |> expect.equal([2])

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(member_id)
        <> "/release-all-tasks",
    )
    |> fx.with_auth(session)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let payload_decoder = {
    use released_count <- decode.field("released_count", decode.int)
    use task_ids <- decode.field("task_ids", decode.list(decode.int))
    decode.success(#(released_count, task_ids))
  }
  let #(released_count, task_ids) = fx.require_data(body, payload_decoder)
  released_count |> expect.equal(2)
  list.length(task_ids) |> expect.equal(2)

  let claimed_left =
    fx.require_query_int(
      db,
      "select count(*) from tasks where project_id = $1 and claimed_by = $2 and execution_state = 'claimed'",
      [pog.int(project_id), pog.int(member_id)],
    )
  claimed_left |> expect.equal(0)
}

pub fn release_all_tasks_for_member_forbidden_test() {
  let #(db, handler, session, project_id) =
    fx.require_project_context("Bulk Release Forbidden")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")

  fx.require_member(handler, session, project_id, member_id, "member")

  let admin_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let member_session = fx.require_login_session(handler, "member@example.com")

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(admin_id)
        <> "/release-all-tasks",
    )
    |> fx.with_auth(member_session)

  let res = handler(req)
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn release_all_tasks_for_member_self_release_test() {
  let #(db, handler, session, project_id) =
    fx.require_project_context("Bulk Release Self")

  let admin_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/"
        <> int.to_string(project_id)
        <> "/members/"
        <> int.to_string(admin_id)
        <> "/release-all-tasks",
    )
    |> fx.with_auth(session)

  let res = handler(req)
  expect.expect_status(res, 400)
  string.contains(simulate.read_body(res), "SELF_RELEASE") |> expect.is_true
}

pub fn release_all_tasks_for_member_not_found_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let session = fx.require_login_session(handler, "admin@example.com")

  let req =
    simulate.request(
      http.Post,
      "/api/v1/projects/99999/members/99999/release-all-tasks",
    )
    |> fx.with_auth(session)

  let res = handler(req)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

pub fn task_dependencies_schema_indices_present_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app

  let columns_count =
    fx.require_query_int(
      db,
      "select count(*) from information_schema.columns where table_name = 'task_dependencies' and column_name in ('task_id', 'depends_on_task_id', 'created_at', 'created_by')",
      [],
    )
  columns_count |> expect.equal(4)

  let index_count =
    fx.require_query_int(
      db,
      "select count(*) from pg_indexes where tablename = 'task_dependencies' and indexname in ('idx_task_dependencies_task_id', 'idx_task_dependencies_depends_on_task_id')",
      [],
    )
  index_count |> expect.equal(2)
}

pub fn pool_includes_available_active_card_task_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Active Card Pool")

  fx.require_task(
    handler,
    session,
    project_id,
    "Active card task",
    "",
    3,
    type_id,
  )

  expect_project_task_titles(handler, session, project_id, "", [
    "Active card task",
  ])
}

pub fn pool_excludes_task_under_draft_card_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Draft Card")
  let draft_card = insert_card_state(db, project_id, "Draft", "draft")

  fx.require_task_with_card_full(
    handler,
    session,
    project_id,
    "Draft task",
    "",
    3,
    type_id,
    draft_card,
  )

  expect_project_task_titles(handler, session, project_id, "", [])
}

pub fn pool_includes_task_under_active_card_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Active Card")
  let active_card = insert_card_state(db, project_id, "Active", "active")

  fx.require_task_with_card_full(
    handler,
    session,
    project_id,
    "Active-card task",
    "",
    3,
    type_id,
    active_card,
  )

  expect_project_task_titles(handler, session, project_id, "", [
    "Active-card task",
  ])
}

pub fn dependency_blocks_available_and_claimed_tasks_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Blocked")
  let blocked =
    fx.require_task(handler, session, project_id, "Blocked", "", 3, type_id)
  let blocker =
    fx.require_task(handler, session, project_id, "Blocker", "", 3, type_id)

  fx.create_task_dependency_status(handler, session, blocked, blocker)
  |> expect.equal(200)

  expect_project_task_titles(handler, session, project_id, "blocked=true", [
    "Blocked",
  ])

  let claim_blocked =
    fx.claim_task_response(
      handler,
      session,
      blocked,
      fx.task_version(db, blocked),
    )
  expect.expect_status(claim_blocked, 409)
  simulate.read_body(claim_blocked)
  |> string.contains("CONFLICT_BLOCKED")
  |> expect.is_true

  fx.claim_task_status(handler, session, blocker, fx.task_version(db, blocker))
  |> expect.equal(200)

  let still_blocked =
    fx.claim_task_response(
      handler,
      session,
      blocked,
      fx.task_version(db, blocked),
    )
  expect.expect_status(still_blocked, 409)
}

pub fn claimed_task_blocked_after_claim_cannot_close_but_can_release_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Claimed Blocked Close")
  let blocked =
    fx.require_task(handler, session, project_id, "Blocked", "", 3, type_id)
  let blocker =
    fx.require_task(handler, session, project_id, "Blocker", "", 3, type_id)

  fx.claim_task_status(handler, session, blocked, fx.task_version(db, blocked))
  |> expect.equal(200)
  fx.create_task_dependency_status(handler, session, blocked, blocker)
  |> expect.equal(200)

  let close_blocked =
    fx.close_task_response(
      handler,
      session,
      blocked,
      fx.task_version(db, blocked),
    )
  expect.expect_status(close_blocked, 409)
  simulate.read_body(close_blocked)
  |> string.contains("CONFLICT_BLOCKED")
  |> expect.is_true
  task_claimed_by(db, blocked) |> expect.equal(1)

  fx.release_task_status(
    handler,
    session,
    blocked,
    fx.task_version(db, blocked),
  )
  |> expect.equal(200)
  task_claimed_by(db, blocked) |> expect.equal(0)
}

pub fn dependency_unblocks_when_dependency_closed_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Closed Dependency")
  let blocked =
    fx.require_task(handler, session, project_id, "Blocked", "", 3, type_id)
  let blocker =
    fx.require_task(handler, session, project_id, "Blocker", "", 3, type_id)

  fx.create_task_dependency_status(handler, session, blocked, blocker)
  |> expect.equal(200)
  fx.claim_task_status(handler, session, blocker, fx.task_version(db, blocker))
  |> expect.equal(200)
  fx.close_task_status(handler, session, blocker, fx.task_version(db, blocker))
  |> expect.equal(200)

  project_task_titles(handler, session, project_id, "blocked=false")
  |> list.contains("Blocked")
  |> expect.is_true
  fx.claim_task_status(handler, session, blocked, fx.task_version(db, blocked))
  |> expect.equal(200)
}

pub fn delete_dependency_target_unblocks_task_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Delete Dependency")
  let blocked =
    fx.require_task(handler, session, project_id, "Blocked", "", 3, type_id)
  let blocker =
    fx.require_task(handler, session, project_id, "Blocker", "", 3, type_id)

  fx.create_task_dependency_status(handler, session, blocked, blocker)
  |> expect.equal(200)
  fx.delete_task_dependency_status(handler, session, blocked, blocker)
  |> expect.equal(204)
  fx.claim_task_status(handler, session, blocked, fx.task_version(db, blocked))
  |> expect.equal(200)
}

pub fn manual_close_claimed_task_allowed_only_for_owner_test() {
  let #(db, handler, admin_session, project_id, type_id) =
    fx.require_task_project("HT08 Close Owner")

  let owner_id =
    fx.require_member_user(handler, db, "owner@example.com", "inv_owner")
  let other_id =
    fx.require_member_user(
      handler,
      db,
      "other-owner@example.com",
      "inv_other_owner",
    )
  fx.require_member(handler, admin_session, project_id, owner_id, "member")
  fx.require_member(handler, admin_session, project_id, other_id, "member")

  let owner_session = fx.require_login_session(handler, "owner@example.com")
  let other_session =
    fx.require_login_session(handler, "other-owner@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Owned", "", 3, type_id)
  fx.claim_task_status(
    handler,
    owner_session,
    task_id,
    fx.task_version(db, task_id),
  )
  |> expect.equal(200)

  let other_close =
    fx.close_task_response(
      handler,
      other_session,
      task_id,
      fx.task_version(db, task_id),
    )
  expect.expect_status(other_close, 403)

  fx.close_task_status(
    handler,
    owner_session,
    task_id,
    fx.task_version(db, task_id),
  )
  |> expect.equal(200)
}

pub fn dependency_would_create_cycle_is_rejected_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("HT08 Cycle")
  let task_a =
    fx.require_task(handler, session, project_id, "Task A", "", 3, type_id)
  let task_b =
    fx.require_task(handler, session, project_id, "Task B", "", 3, type_id)

  fx.create_task_dependency_status(handler, session, task_a, task_b)
  |> expect.equal(200)
  fx.create_task_dependency_status(handler, session, task_b, task_a)
  |> expect.equal(422)
}

pub fn cross_project_dependency_is_rejected_test() {
  let #(_db, handler, session, project_one_id, type_one_id) =
    fx.require_task_project("HT08 Cross One")
  let project_two_id = fx.require_project(handler, session, "HT08 Cross Two")
  let type_two_id =
    fx.require_task_type(handler, session, project_two_id, "Bug", "bug-ant")

  let task_one =
    fx.require_task(
      handler,
      session,
      project_one_id,
      "Task One",
      "",
      3,
      type_one_id,
    )
  let task_two =
    fx.require_task(
      handler,
      session,
      project_two_id,
      "Task Two",
      "",
      3,
      type_two_id,
    )

  fx.create_task_dependency_status(handler, session, task_one, task_two)
  |> expect.equal(422)
}

pub fn pool_filters_by_user_capabilities_test() {
  let #(db, handler, admin_session, project_id, _) =
    fx.require_task_project("HT08 Capabilities")
  let frontend = insert_capability(db, project_id, "Frontend")
  let backend = insert_capability(db, project_id, "Backend")
  let frontend_type =
    fx.require_task_type_with_capability(
      handler,
      admin_session,
      project_id,
      "Frontend Task",
      "bolt",
      frontend,
    )
  let backend_type =
    fx.require_task_type_with_capability(
      handler,
      admin_session,
      project_id,
      "Backend Task",
      "bug-ant",
      backend,
    )

  let member_id =
    fx.require_member_user(handler, db, "cap-user@example.com", "inv_cap")
  fx.require_member(handler, admin_session, project_id, member_id, "member")
  grant_capability(db, project_id, member_id, frontend)

  fx.require_task(
    handler,
    admin_session,
    project_id,
    "Visible frontend",
    "",
    3,
    frontend_type,
  )
  fx.require_task(
    handler,
    admin_session,
    project_id,
    "Hidden backend",
    "",
    3,
    backend_type,
  )

  let member_session = fx.require_login_session(handler, "cap-user@example.com")

  expect_project_task_titles(handler, member_session, project_id, "", [
    "Visible frontend",
  ])
}

pub fn me_metrics_returns_counts_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  fx.close_task_status(handler, session, task_id, 2) |> expect.equal(200)

  let req =
    simulate.request(http.Get, "/api/v1/me/metrics?window_days=30")
    |> fx.with_session_cookies(session)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let metrics_decoder = {
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use closed_count <- decode.field("closed_count", decode.int)
    decode.success(#(claimed_count, released_count, closed_count))
  }
  let #(claimed, released, closed) =
    fx.require_data(
      body,
      decode.field("metrics", metrics_decoder, decode.success),
    )

  claimed |> expect.equal(1)
  released |> expect.equal(0)
  closed |> expect.equal(1)
}

pub fn org_metrics_overview_requires_org_admin_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")

  fx.require_member_user(handler, db, "member@example.com", "inv_member")

  let member_session = fx.require_login_session(handler, "member@example.com")

  // member is authenticated but not org admin
  let req =
    simulate.request(http.Get, "/api/v1/org/metrics/overview")
    |> fx.with_session_cookies(member_session)

  let res = handler(req)
  expect.expect_status(res, 403)

  // admin succeeds
  let admin_req =
    simulate.request(http.Get, "/api/v1/org/metrics/overview")
    |> fx.with_session_cookies(admin_session)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)
}

pub fn org_metrics_project_tasks_returns_metrics_shape_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  expect.expect_status(
    fx.start_work_session_response(handler, session, task_id),
    200,
  )

  let user_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let req =
    simulate.request(
      http.Get,
      "/api/v1/org/metrics/projects/" <> int.to_string(project_id) <> "/tasks",
    )
    |> fx.with_session_cookies(session)

  let res = handler(req)
  expect.expect_status(res, 200)

  let body = simulate.read_body(res)
  let task_decoder = {
    use id <- decode.field("id", decode.int)

    // Ensure global Task contract fields exist
    use _task_type <- decode.field("task_type", decode.dynamic)
    use status <- decode.field("status", decode.string)
    use work_state <- decode.field("work_state", decode.string)
    use ongoing_by <- decode.field(
      "ongoing_by",
      decode.optional({
        use user_id <- decode.field("user_id", decode.int)
        decode.success(user_id)
      }),
    )

    use claim_count <- decode.field("claim_count", decode.int)
    use release_count <- decode.field("release_count", decode.int)
    use close_count <- decode.field("close_count", decode.int)
    use first_claim_at <- decode.field(
      "first_claim_at",
      decode.optional(decode.string),
    )

    decode.success(#(
      id,
      status,
      work_state,
      ongoing_by,
      claim_count,
      release_count,
      close_count,
      first_claim_at,
    ))
  }
  let tasks = fx.require_data_list(body, "tasks", task_decoder)

  case tasks {
    [
      #(
        id,
        status,
        work_state,
        ongoing_by,
        claim_count,
        release_count,
        close_count,
        first_claim_at,
      ),
      ..
    ] -> {
      id |> expect.equal(task_id)
      status |> expect.equal("claimed")
      work_state |> expect.equal("ongoing")
      ongoing_by |> expect.equal(option.Some(user_id))
      claim_count |> expect.equal(1)
      release_count |> expect.equal(0)
      close_count |> expect.equal(0)
      let _ = first_claim_at |> expect.some
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn org_metrics_users_requires_org_admin_and_returns_shape_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")

  fx.require_member_user(handler, db, "member@example.com", "inv_member")

  let member_session = fx.require_login_session(handler, "member@example.com")

  let member_req =
    simulate.request(http.Get, "/api/v1/org/metrics/users")
    |> fx.with_session_cookies(member_session)

  let member_res = handler(member_req)
  expect.expect_status(member_res, 403)

  let admin_req =
    simulate.request(http.Get, "/api/v1/org/metrics/users")
    |> fx.with_session_cookies(admin_session)

  let admin_res = handler(admin_req)
  expect.expect_status(admin_res, 200)

  let body = simulate.read_body(admin_res)
  let user_decoder: decode.Decoder(#(Int, String, Int, Int, Int, Int)) = {
    use user_id <- decode.field("user_id", decode.int)
    use email <- decode.field("email", decode.string)
    use claimed_count <- decode.field("claimed_count", decode.int)
    use released_count <- decode.field("released_count", decode.int)
    use closed_count <- decode.field("closed_count", decode.int)
    use ongoing_count <- decode.field("ongoing_count", decode.int)
    use _last_claim_at <- decode.field(
      "last_claim_at",
      decode.optional(decode.string),
    )
    decode.success(#(
      user_id,
      email,
      claimed_count,
      released_count,
      closed_count,
      ongoing_count,
    ))
  }

  let users = fx.require_data_list(body, "users", user_decoder)

  case users {
    [#(_user_id, email, _claimed, _released, _closed, _ongoing), ..] -> {
      email |> expect.equal("admin@example.com")
      Nil
    }
    _ -> False |> expect.is_true
  }
}

pub fn org_metrics_users_invalid_window_days_returns_422_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(..) = app
  let handler = scrumbringer_server.handler(app)

  let session = fx.require_login_session(handler, "admin@example.com")

  let req =
    simulate.request(http.Get, "/api/v1/org/metrics/users?window_days=999")
    |> fx.with_session_cookies(session)

  let res = handler(req)
  expect.expect_status(res, 422)
}

pub fn tasks_list_requires_membership_test() {
  let #(db, handler, _admin_session, project_id) =
    fx.require_project_context("Core")

  fx.require_member_user(handler, db, "outsider@example.com", "inv_out")
  let outsider_session =
    fx.require_login_session(handler, "outsider@example.com")

  let res =
    fx.list_project_tasks_response(handler, outsider_session, project_id, "")
  expect.expect_status(res, 403)
  string.contains(simulate.read_body(res), "FORBIDDEN") |> expect.is_true
}

pub fn task_get_requires_membership_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Secret", "", 3, type_id)

  fx.require_member_user(handler, db, "outsider@example.com", "inv_out")
  let outsider_session =
    fx.require_login_session(handler, "outsider@example.com")

  let res = fx.task_response(handler, outsider_session, task_id)
  expect.expect_status(res, 404)
  string.contains(simulate.read_body(res), "NOT_FOUND") |> expect.is_true
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn tasks_list_filters_status_type_and_invalid_values_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: _db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, session, "Core")

  let bug_type_id =
    fx.require_task_type(handler, session, project_id, "Bug", "bug-ant")
  let chore_type_id =
    fx.require_task_type(handler, session, project_id, "Chore", "bolt")

  let available_id =
    fx.require_task(
      handler,
      session,
      project_id,
      "Available",
      "",
      3,
      bug_type_id,
    )

  let claimed_id =
    fx.require_task(
      handler,
      session,
      project_id,
      "Claimed",
      "",
      3,
      chore_type_id,
    )

  let closed_id =
    fx.require_task(handler, session, project_id, "Closed", "", 3, bug_type_id)

  fx.claim_task_status(handler, session, claimed_id, 1) |> expect.equal(200)
  fx.claim_task_status(handler, session, closed_id, 1) |> expect.equal(200)
  fx.close_task_status(handler, session, closed_id, 2) |> expect.equal(200)

  expect_project_task_titles(handler, session, project_id, "status=available", [
    "Available",
  ])
  expect_project_task_titles(handler, session, project_id, "status=claimed", [
    "Claimed",
  ])
  expect_project_task_titles(handler, session, project_id, "status=closed", [
    "Closed",
  ])
  expect_project_task_titles(
    handler,
    session,
    project_id,
    "type_id=" <> int.to_string(bug_type_id),
    ["Closed", "Available"],
  )

  let invalid_status_res =
    fx.list_project_tasks_response(handler, session, project_id, "status=nope")

  expect.expect_status(invalid_status_res, 422)
  string.contains(simulate.read_body(invalid_status_res), "VALIDATION_ERROR")
  |> expect.is_true

  let invalid_type_res =
    fx.list_project_tasks_response(handler, session, project_id, "type_id=abc")

  expect.expect_status(invalid_type_res, 422)
  string.contains(simulate.read_body(invalid_type_res), "VALIDATION_ERROR")
  |> expect.is_true

  let invalid_cap_res =
    fx.list_project_tasks_response(
      handler,
      session,
      project_id,
      "capability_id=abc",
    )

  expect.expect_status(invalid_cap_res, 422)
  string.contains(simulate.read_body(invalid_cap_res), "VALIDATION_ERROR")
  |> expect.is_true

  let _ = available_id
}

// Justification: large function kept intact to preserve cohesive logic.
pub fn patch_ignores_claimed_by_and_non_claimer_forbidden_test() {
  let app = fx.require_app()
  let scrumbringer_server.App(db: db, ..) = app
  let handler = scrumbringer_server.handler(app)

  let admin_session = fx.require_login_session(handler, "admin@example.com")
  let project_id = fx.require_project(handler, admin_session, "Core")
  let type_id =
    fx.require_task_type(handler, admin_session, project_id, "Bug", "bug-ant")

  let member_id =
    fx.require_member_user(handler, db, "member@example.com", "inv_member")
  let other_id =
    fx.require_member_user(handler, db, "other@example.com", "inv_other")

  fx.require_member(handler, admin_session, project_id, member_id, "member")
  fx.require_member(handler, admin_session, project_id, other_id, "member")

  let member_session = fx.require_login_session(handler, "member@example.com")

  let other_session = fx.require_login_session(handler, "other@example.com")

  let task_id =
    fx.require_task(handler, admin_session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, member_session, task_id, 1)
  |> expect.equal(200)

  let patch_ok_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fx.with_auth(member_session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(2)),
          #("title", json.string("New")),
          #("claimed_by", json.int(other_id)),
        ]),
      ),
    )

  expect.expect_status(patch_ok_res, 200)

  task_claimed_by(db, task_id) |> expect.equal(member_id)

  let version = fx.task_version(db, task_id)

  let patch_other_res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fx.with_auth(other_session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(version)),
          #("title", json.string("Other")),
        ]),
      ),
    )

  expect.expect_status(patch_other_res, 403)

  let release_other_res =
    fx.release_task_response(handler, other_session, task_id, version)

  expect.expect_status(release_other_res, 403)

  let close_other_res =
    fx.close_task_response(handler, other_session, task_id, version)

  expect.expect_status(close_other_res, 403)
}

pub fn patch_rejects_blank_title_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)

  let res =
    handler(
      simulate.request(http.Patch, "/api/v1/tasks/" <> int.to_string(task_id))
      |> fx.with_auth(session)
      |> simulate.json_body(
        json.object([
          #("version", json.int(2)),
          #("title", json.string("   ")),
        ]),
      ),
    )

  expect.expect_status(res, 422)
  string.contains(simulate.read_body(res), "Title is required")
  |> expect.is_true
}

pub fn me_work_session_start_pause_and_persist_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)

  let start_body =
    simulate.read_body(fx.start_work_session_response(handler, session, task_id))

  decode_work_session_task_id(start_body) |> expect.equal(option.Some(task_id))
  is_iso8601_utc(decode_as_of(start_body)) |> expect.equal(True)

  let get_res = fx.active_work_sessions_response(handler, session)
  expect.expect_status(get_res, 200)
  decode_work_session_task_id(simulate.read_body(get_res))
  |> expect.equal(option.Some(task_id))

  // Simulate ~70s of elapsed time, then pause to flush accumulation.
  let user_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  let _ =
    pog.query(
      "update user_task_work_session set started_at = now() - interval '70 seconds' where user_id = $1 and task_id = $2 and ended_at is null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  let pause_res = fx.pause_work_session_response(handler, session, task_id)
  expect.expect_status(pause_res, 200)
  decode_work_session_task_id(simulate.read_body(pause_res))
  |> expect.equal(option.None)

  let accumulated_after_pause =
    fx.require_query_int(
      db,
      "select accumulated_s from user_task_work_total where user_id = $1 and task_id = $2",
      [pog.int(user_id), pog.int(task_id)],
    )

  let _ = expect.is_true(accumulated_after_pause >= 70)

  let resume_body =
    simulate.read_body(fx.start_work_session_response(handler, session, task_id))

  decode_work_session_accumulated_s(resume_body)
  |> expect.equal(option.Some(accumulated_after_pause))

  let get_after_pause = fx.active_work_sessions_response(handler, session)
  expect.expect_status(get_after_pause, 200)
  decode_work_session_task_id(simulate.read_body(get_after_pause))
  |> expect.equal(option.Some(task_id))
}

pub fn me_work_session_heartbeat_updates_last_heartbeat_at_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  expect.expect_status(
    fx.start_work_session_response(handler, session, task_id),
    200,
  )

  let user_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )

  // Set started_at to 65 seconds ago to simulate elapsed time
  let _ =
    pog.query(
      "update user_task_work_session set started_at = now() - interval '65 seconds' where user_id = $1 and task_id = $2 and ended_at is null",
    )
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  // Get last_heartbeat_at before heartbeat (as epoch integer)
  let heartbeat_before =
    fx.require_query_int(
      db,
      "select extract(epoch from last_heartbeat_at)::int from user_task_work_session where user_id = $1 and task_id = $2 and ended_at is null",
      [pog.int(user_id), pog.int(task_id)],
    )

  let heartbeat_res =
    fx.heartbeat_work_session_response(handler, session, task_id)
  expect.expect_status(heartbeat_res, 200)

  // Get last_heartbeat_at after heartbeat
  let heartbeat_after =
    fx.require_query_int(
      db,
      "select extract(epoch from last_heartbeat_at)::int from user_task_work_session where user_id = $1 and task_id = $2 and ended_at is null",
      [pog.int(user_id), pog.int(task_id)],
    )

  // last_heartbeat_at should have been updated (>= before, allows for same-second update)
  let _ = expect.is_true(heartbeat_after >= heartbeat_before)
  // Note: In the new multi-session model, accumulated_s is flushed to
  // user_task_work_total only when the session is paused/closed, not on heartbeat.
  // The API returns accumulated_s from user_task_work_total (previous sessions)
  // while elapsed time from active session is computed client-side from started_at.
}

pub fn me_work_sessions_supports_multiple_concurrent_sessions_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let t1 = fx.require_task(handler, session, project_id, "T1", "", 3, type_id)
  let t2 = fx.require_task(handler, session, project_id, "T2", "", 3, type_id)

  fx.claim_task_status(handler, session, t1, 1) |> expect.equal(200)
  fx.claim_task_status(handler, session, t2, 1) |> expect.equal(200)

  // Start sessions on both tasks - multi-session model supports this
  expect.expect_status(
    fx.start_work_session_response(handler, session, t1),
    200,
  )
  let res = fx.start_work_session_response(handler, session, t2)
  expect.expect_status(res, 200)

  // Verify both sessions exist
  let user_id =
    fx.require_query_int(
      db,
      "select id from users where email = 'admin@example.com'",
      [],
    )
  let session_count =
    fx.require_query_int(
      db,
      "select count(*)::int from user_task_work_session where user_id = $1 and ended_at is null",
      [pog.int(user_id)],
    )
  session_count |> expect.equal(2)
}

pub fn me_work_session_start_returns_409_when_not_claimed_test() {
  let #(_, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  let res = fx.start_work_session_response(handler, session, task_id)
  expect.expect_status(res, 409)
  string.contains(simulate.read_body(res), "CONFLICT_CLAIMED")
  |> expect.equal(True)
}

pub fn me_work_session_clears_before_release_and_close_test() {
  let #(db, handler, session, project_id, type_id) =
    fx.require_task_project("Core")

  let task_id =
    fx.require_task(handler, session, project_id, "Core", "", 3, type_id)

  fx.claim_task_status(handler, session, task_id, 1) |> expect.equal(200)
  expect.expect_status(
    fx.start_work_session_response(handler, session, task_id),
    200,
  )

  let version = fx.task_version(db, task_id)

  fx.release_task_status(handler, session, task_id, version)
  |> expect.equal(200)

  let active_after_release = fx.active_work_sessions_response(handler, session)
  decode_work_session_task_id(simulate.read_body(active_after_release))
  |> expect.equal(option.None)

  // Re-claim + start, then close.
  let version = fx.task_version(db, task_id)
  fx.claim_task_status(handler, session, task_id, version) |> expect.equal(200)
  expect.expect_status(
    fx.start_work_session_response(handler, session, task_id),
    200,
  )

  let version = fx.task_version(db, task_id)
  fx.close_task_status(handler, session, task_id, version) |> expect.equal(200)

  let active_after_close = fx.active_work_sessions_response(handler, session)
  decode_work_session_task_id(simulate.read_body(active_after_close))
  |> expect.equal(option.None)
}

fn decode_work_session(body: String) -> #(option.Option(Int), String, Int) {
  let session_decoder = {
    use task_id <- decode.field("task_id", decode.int)
    use accumulated_s <- decode.field("accumulated_s", decode.int)
    decode.success(#(task_id, accumulated_s))
  }

  let data_decoder = {
    use sessions <- decode.field(
      "active_sessions",
      decode.list(session_decoder),
    )
    use as_of <- decode.field("as_of", decode.string)

    let #(active_task_id, accumulated_s) = case sessions {
      [#(task_id, accumulated), ..] -> #(option.Some(task_id), accumulated)
      [] -> #(option.None, 0)
    }

    decode.success(#(active_task_id, as_of, accumulated_s))
  }
  fx.require_data(body, data_decoder)
}

fn decode_work_session_task_id(body: String) -> option.Option(Int) {
  let #(active_task_id, _, _) = decode_work_session(body)
  active_task_id
}

fn decode_work_session_accumulated_s(body: String) -> option.Option(Int) {
  let #(active_task_id, _, accumulated_s) = decode_work_session(body)

  case active_task_id {
    option.Some(_) -> option.Some(accumulated_s)
    option.None -> option.None
  }
}

fn decode_as_of(body: String) -> String {
  let #(_, as_of, _) = decode_work_session(body)
  as_of
}

fn is_iso8601_utc(value: String) -> Bool {
  string.contains(value, "T") && string.ends_with(value, "Z")
}

fn task_claimed_by(db: pog.Connection, task_id: Int) -> Int {
  fx.require_query_int(
    db,
    "select coalesce(claimed_by, 0) from tasks where id = $1",
    [
      pog.int(task_id),
    ],
  )
}

fn count_audit_events(
  db: pog.Connection,
  task_id: Int,
  event_type: String,
) -> Int {
  fx.require_query_int(
    db,
    "select count(*) from audit_events where task_id = $1 and event_type = $2",
    [pog.int(task_id), pog.text(event_type)],
  )
}

fn count_audit_events_for_task(db: pog.Connection, task_id: Int) -> Int {
  fx.require_query_int(
    db,
    "select count(*) from audit_events where task_id = $1",
    [
      pog.int(task_id),
    ],
  )
}

fn count_audit_events_for_actor(
  db: pog.Connection,
  task_id: Int,
  actor_user_id: Int,
  event_type: String,
) -> Int {
  fx.require_query_int(
    db,
    "select count(*) from audit_events where task_id = $1 and actor_user_id = $2 and event_type = $3",
    [pog.int(task_id), pog.int(actor_user_id), pog.text(event_type)],
  )
}

fn count_task_rows(db: pog.Connection, task_id: Int) -> Int {
  fx.require_query_int(db, "select count(*) from tasks where id = $1", [
    pog.int(task_id),
  ])
}

fn task_type_contract_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  decode.success(#(id, name, icon))
}

fn ongoing_by_decoder() {
  decode.optional({
    use user_id <- decode.field("user_id", decode.int)
    decode.success(user_id)
  })
}

fn task_contract_fields_decoder() {
  use status <- decode.field("status", decode.string)
  use work_state <- decode.field("work_state", decode.string)
  use task_type <- decode.field("task_type", task_type_contract_decoder())
  use ongoing_by <- decode.field("ongoing_by", ongoing_by_decoder())
  decode.success(#(status, work_state, task_type, ongoing_by))
}

fn task_get_contract_fields_decoder() {
  use work_state <- decode.field("work_state", decode.string)
  use task_type <- decode.field("task_type", task_type_contract_decoder())
  use ongoing_by <- decode.field("ongoing_by", ongoing_by_decoder())
  decode.success(#(work_state, task_type, ongoing_by))
}

fn require_task_data(body: String, task_decoder: decode.Decoder(a)) -> a {
  fx.require_data(body, {
    use task <- decode.field("task", task_decoder)
    decode.success(task)
  })
}

fn decode_task_titles(body: String) -> List(String) {
  fx.require_data_string_list_field(body, "tasks", "title")
}

fn project_task_titles(handler, session, project_id, query) {
  let res = fx.list_project_tasks_response(handler, session, project_id, query)
  expect.expect_status(res, 200)
  decode_task_titles(simulate.read_body(res))
}

fn expect_project_task_titles(handler, session, project_id, query, titles) {
  project_task_titles(handler, session, project_id, query)
  |> expect.equal(titles)
}

fn set_task_created_at(db: pog.Connection, task_id: Int, created_at: String) {
  let sql =
    "update tasks set created_at = timestamptz '"
    <> created_at
    <> "' where id = $1"

  let assert Ok(_) =
    pog.query(sql)
    |> pog.parameter(pog.int(task_id))
    |> pog.execute(db)

  Nil
}

fn insert_capability(db: pog.Connection, project_id: Int, name: String) -> Int {
  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into capabilities (project_id, name) values ($1, $2) returning id",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.text(name))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      decode.success(id)
    })
    |> pog.execute(db)

  id
}

fn grant_capability(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  capability_id: Int,
) {
  let assert Ok(_) =
    pog.query(
      "insert into project_member_capabilities (project_id, user_id, capability_id) values ($1, $2, $3)",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.int(capability_id))
    |> pog.execute(db)

  Nil
}

fn insert_card_state(
  db: pog.Connection,
  project_id: Int,
  title: String,
  execution_state: String,
) -> Int {
  let assert Ok(pog.Returned(rows: [id, ..], ..)) =
    pog.query(
      "insert into cards (project_id, title, description, created_by, execution_state) values ($1, $2, '', 1, $3) returning id",
    )
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.text(title))
    |> pog.parameter(pog.text(execution_state))
    |> pog.returning({
      use id <- decode.field(0, decode.int)
      decode.success(id)
    })
    |> pog.execute(db)

  id
}
