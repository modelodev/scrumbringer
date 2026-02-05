import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/remote.{Loaded, NotAsked}
import domain/task.{Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import gleam/option.{None}
import gleeunit/should
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/options as helpers_options

pub fn empty_to_opt_trims_whitespace_test() {
  helpers_options.empty_to_opt("   ")
  |> should.equal(None)
}

pub fn empty_to_int_opt_rejects_non_int_test() {
  helpers_options.empty_to_int_opt("abc")
  |> should.equal(None)
}

pub fn find_task_by_id_returns_none_when_not_loaded_test() {
  helpers_lookup.find_task_by_id(NotAsked, 1)
  |> should.equal(None)
}

pub fn find_task_by_id_returns_none_when_missing_test() {
  let state = task_state.Available
  let tasks = [
    Task(
      id: 1,
      project_id: 1,
      type_id: 1,
      task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
      ongoing_by: None,
      title: "T",
      description: None,
      priority: 3,
      state: state,
      status: task_state.to_status(state),
      work_state: task_state.to_work_state(state),
      created_by: 1,
      created_at: "2026-01-01T00:00:00Z",
      version: 1,
      card_id: None,
      card_title: None,
      card_color: None,
      has_new_notes: False,
      blocked_count: 0,
      dependencies: [],
    ),
  ]

  helpers_lookup.find_task_by_id(Loaded(tasks), 99)
  |> should.equal(None)
}

pub fn resolve_org_user_returns_none_when_not_loaded_test() {
  helpers_lookup.resolve_org_user(NotAsked, 1)
  |> should.equal(None)
}

pub fn resolve_org_user_returns_none_when_missing_test() {
  let users = [
    OrgUser(
      id: 1,
      email: "admin@example.com",
      org_role: Admin,
      created_at: "2026-01-01T00:00:00Z",
    ),
  ]

  helpers_lookup.resolve_org_user(Loaded(users), 99)
  |> should.equal(None)
}
