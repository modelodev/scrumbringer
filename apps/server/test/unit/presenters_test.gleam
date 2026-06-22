//// Unit tests for JSON presenter functions.
////
//// Tests shared optional JSON helpers and presenter-specific fallback logic.

import domain/note/entity.{Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project.{ProjectDepthName}
import domain/project/id as project_id
import domain/project_role
import domain/task.{Task}
import domain/task/id as task_id
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import domain/user/id as user_id
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleeunit
import helpers/json as json_helpers
import scrumbringer_server/http/metrics_presenters
import scrumbringer_server/http/projects/presenters as project_presenters
import scrumbringer_server/http/task_notes/presenters as task_note_presenters
import scrumbringer_server/http/tasks/presenters as task_presenters
import scrumbringer_server/use_case/projects_db
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

// =============================================================================
// AC1: option_int_json returns null for None
// =============================================================================

pub fn option_int_json_returns_null_for_none_test() {
  // Given: None value for optional Int
  let value = None

  // When: Convert to JSON
  let result = json_helpers.option_int_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> expect.equal("null")
}

// =============================================================================
// AC2: option_int_json returns int for Some
// =============================================================================

pub fn option_int_json_returns_int_for_some_test() {
  // Given: Some(42) value
  let value = Some(42)

  // When: Convert to JSON
  let result = json_helpers.option_int_json(value)

  // Then: Returns json.int(42)
  result
  |> json.to_string()
  |> expect.equal("42")
}

// =============================================================================
// AC3: option_string_json returns null for None
// =============================================================================

pub fn option_string_json_returns_null_for_none_test() {
  // Given: None value for optional String
  let value = None

  // When: Convert to JSON
  let result = json_helpers.option_string_json(value)

  // Then: Returns json.null()
  result
  |> json.to_string()
  |> expect.equal("null")
}

// =============================================================================
// AC4: option_string_json returns string for Some
// =============================================================================

pub fn option_string_json_returns_string_for_some_test() {
  // Given: Some("hello") value
  let value = Some("hello")

  // When: Convert to JSON
  let result = json_helpers.option_string_json(value)

  // Then: Returns json.string("hello")
  result
  |> json.to_string()
  |> expect.equal("\"hello\"")
}

pub fn workflow_name_or_default_preserves_existing_name_test() {
  metrics_presenters.workflow_name_or_default(Some("Review flow"))
  |> expect.equal("Review flow")
}

pub fn workflow_name_or_default_uses_api_fallback_test() {
  metrics_presenters.workflow_name_or_default(None)
  |> expect.equal("sin_workflow")
}

pub fn project_json_does_not_expose_internal_org_id_test() {
  let project =
    projects_db.ProjectRecord(
      id: 7,
      org_id: 99,
      name: "Core",
      created_at: "2026-06-15T09:00:00Z",
      my_role: project_role.Manager,
      members_count: 3,
      card_depth_names: [],
      healthy_pool_limit: 20,
    )

  let body =
    project
    |> project_presenters.project
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let assert Ok("Core") =
    decode.run(dynamic, decode.field("name", decode.string, decode.success))
  let assert Error(_) =
    decode.run(dynamic, decode.field("org_id", decode.int, decode.success))
}

pub fn project_json_includes_card_depth_names_test() {
  let project =
    projects_db.ProjectRecord(
      id: 7,
      org_id: 99,
      name: "Core",
      created_at: "2026-06-15T09:00:00Z",
      my_role: project_role.Manager,
      members_count: 3,
      card_depth_names: [
        ProjectDepthName(depth: 1, singular_name: "Epic", plural_name: "Epics"),
        ProjectDepthName(
          depth: 2,
          singular_name: "Story",
          plural_name: "Stories",
        ),
      ],
      healthy_pool_limit: 18,
    )

  let body =
    project
    |> project_presenters.project
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)

  let depth_name_decoder = {
    use depth <- decode.field("depth", decode.int)
    use singular_name <- decode.field("singular_name", decode.string)
    use plural_name <- decode.field("plural_name", decode.string)
    decode.success(#(depth, singular_name, plural_name))
  }
  let assert Ok(depth_names) =
    decode.run(
      dynamic,
      decode.field(
        "card_depth_names",
        decode.list(depth_name_decoder),
        decode.success,
      ),
    )

  depth_names
  |> expect.equal([#(1, "Epic", "Epics"), #(2, "Story", "Stories")])
}

pub fn project_json_includes_healthy_pool_limit_test() {
  let project =
    projects_db.ProjectRecord(
      id: 7,
      org_id: 99,
      name: "Core",
      created_at: "2026-06-15T09:00:00Z",
      my_role: project_role.Manager,
      members_count: 3,
      card_depth_names: [],
      healthy_pool_limit: 14,
    )

  let body =
    project
    |> project_presenters.project
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let assert Ok(14) =
    decode.run(
      dynamic,
      decode.field("healthy_pool_limit", decode.int, decode.success),
    )
}

pub fn project_member_json_does_not_expose_internal_project_id_test() {
  let member =
    projects_db.ProjectMemberRecord(
      project_id: 7,
      user_id: 42,
      role: project_role.Member,
      created_at: "2026-06-15T09:00:00Z",
      claimed_count: 5,
    )

  let body =
    member
    |> project_presenters.member
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let assert Ok(42) =
    decode.run(dynamic, decode.field("user_id", decode.int, decode.success))
  let assert Error(_) =
    decode.run(dynamic, decode.field("project_id", decode.int, decode.success))
}

pub fn task_json_derives_status_and_work_state_from_task_state_test() {
  let task =
    Task(
      id: 1,
      project_id: 2,
      type_id: 3,
      task_type: TaskTypeInline(id: 3, name: "Bug", icon: "bug-ant"),
      ongoing_by: None,
      title: "Fix login",
      description: None,
      priority: 2,
      state: task_state.Claimed(
        claimed_by: 42,
        claimed_at: "2026-06-15T10:00:00Z",
        mode: task_status.Ongoing,
      ),
      created_by: 7,
      created_at: "2026-06-15T09:00:00Z",
      due_date: None,
      version: 1,
      parent_card_id: None,
      card_id: None,
      card_title: None,
      card_color: None,
      has_new_notes: False,
      blocked_count: 0,
      dependencies: [],
      automation_origin: None,
    )

  let body =
    task
    |> task_presenters.task_json
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let assert Ok(#(status, work_state, claimed_by, claimed_at)) =
    decode.run(dynamic, task_lifecycle_decoder())

  status |> expect.equal("claimed")
  work_state |> expect.equal("ongoing")
  claimed_by |> expect.equal(42)
  claimed_at |> expect.equal("2026-06-15T10:00:00Z")
}

pub fn task_note_presenter_uses_common_note_contract_test() {
  let note =
    Note(
      id: note_id.new(5),
      project_id: project_id.new(8),
      subject: TaskNoteSubject(task_id.new(13)),
      user_id: user_id.new(21),
      content: "Use the rollout checklist",
      url: Some("https://example.com/checklist"),
      pinned: True,
      created_at: "2026-06-22T09:00:00Z",
      updated_at: "2026-06-22T09:10:00Z",
      author_email: "ana@example.com",
      author_project_role: Some(project_role.Manager),
      author_org_role: org_role.Member,
    )

  let body =
    note
    |> task_note_presenters.note
    |> json.to_string

  let assert Ok(dynamic) = json.parse(body, decode.dynamic)
  let assert Ok("task") =
    decode.run(
      dynamic,
      decode.field("subject_type", decode.string, decode.success),
    )
  let assert Ok(13) =
    decode.run(dynamic, decode.field("subject_id", decode.int, decode.success))
  let assert Ok(8) =
    decode.run(dynamic, decode.field("project_id", decode.int, decode.success))
  let assert Error(_) =
    decode.run(dynamic, decode.field("task_id", decode.int, decode.success))
}

fn task_lifecycle_decoder() -> decode.Decoder(#(String, String, Int, String)) {
  use status <- decode.field("status", decode.string)
  use work_state <- decode.field("work_state", decode.string)
  use claimed_by <- decode.field("claimed_by", decode.int)
  use claimed_at <- decode.field("claimed_at", decode.string)
  decode.success(#(status, work_state, claimed_by, claimed_at))
}
