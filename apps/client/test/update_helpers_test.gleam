import domain/org.{OrgUser}
import domain/org_role.{Admin}
import domain/remote.{Loaded, NotAsked}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import gleam/dict
import gleam/option.{None, Some}
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/options as helpers_options

pub fn empty_to_opt_trims_whitespace_test() {
  let assert None = helpers_options.empty_to_opt("   ")
}

pub fn empty_to_int_opt_rejects_non_int_test() {
  let assert None = helpers_options.empty_to_int_opt("abc")
}

pub fn find_task_by_id_returns_none_when_not_loaded_test() {
  let assert None = helpers_lookup.find_task_by_id(NotAsked, 1)
}

pub fn find_task_by_id_returns_none_when_missing_test() {
  let state = task_state.Available
  let tasks = [task_with_state(1, state)]

  let assert None = helpers_lookup.find_task_by_id(Loaded(tasks), 99)
}

pub fn find_task_by_id_in_cache_falls_back_to_project_cache_test() {
  let state = task_state.Available
  let cached_task = task_with_state(42, state)
  let tasks_by_project = dict.from_list([#(7, [cached_task])])

  let assert Some(found) =
    helpers_lookup.find_task_by_id_in_cache(NotAsked, tasks_by_project, 42)
  let assert 42 = found.id
}

fn task_with_state(id: Int, state: task_state.TaskState) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
    ongoing_by: None,
    title: "T",
    description: None,
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
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
}

pub fn resolve_org_user_returns_none_when_not_loaded_test() {
  let assert None = helpers_lookup.resolve_org_user(NotAsked, 1)
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

  let assert None = helpers_lookup.resolve_org_user(Loaded(users), 99)
}
