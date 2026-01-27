import domain/org.{OrgUser}
import domain/task.{Task}
import domain/task_status
import domain/task_type.{TaskTypeInline}
import gleam/option.{None}
import gleeunit/should
import scrumbringer_client/client_state.{Loaded, NotAsked}
import scrumbringer_client/update_helpers

pub fn empty_to_opt_trims_whitespace_test() {
  update_helpers.empty_to_opt("   ")
  |> should.equal(None)
}

pub fn empty_to_int_opt_rejects_non_int_test() {
  update_helpers.empty_to_int_opt("abc")
  |> should.equal(None)
}

pub fn find_task_by_id_returns_none_when_not_loaded_test() {
  update_helpers.find_task_by_id(NotAsked, 1)
  |> should.equal(None)
}

pub fn find_task_by_id_returns_none_when_missing_test() {
  let tasks =
    [Task(
      id: 1,
      project_id: 1,
      type_id: 1,
      task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
      ongoing_by: None,
      title: "T",
      description: None,
      priority: 3,
      status: task_status.Available,
      work_state: task_status.WorkAvailable,
      created_by: 1,
      claimed_by: None,
      claimed_at: None,
      completed_at: None,
      created_at: "2026-01-01T00:00:00Z",
      version: 1,
      card_id: None,
      card_title: None,
      card_color: None,
    )]

  update_helpers.find_task_by_id(Loaded(tasks), 99)
  |> should.equal(None)
}

pub fn resolve_org_user_returns_none_when_not_loaded_test() {
  update_helpers.resolve_org_user(NotAsked, 1)
  |> should.equal(None)
}

pub fn resolve_org_user_returns_none_when_missing_test() {
  let users =
    [OrgUser(
      id: 1,
      email: "admin@example.com",
      org_role: "admin",
      created_at: "2026-01-01T00:00:00Z",
    )]

  update_helpers.resolve_org_user(Loaded(users), 99)
  |> should.equal(None)
}
