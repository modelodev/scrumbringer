import support/domain_fixtures

import domain/remote.{Loaded, NotAsked}
import domain/task_type.{TaskType}
import scrumbringer_client/features/layout/center_panel_data

pub fn from_remotes_uses_loaded_values_test() {
  let task_type =
    TaskType(
      ..domain_fixtures.task_type(1, "Feature"),
      icon: "sparkles",
      tasks_count: 2,
    )
  let capability = domain_fixtures.capability(3, "Backend")
  let org_user = domain_fixtures.org_user(7, "member@example.test")

  let data =
    center_panel_data.from_remotes(
      Loaded([]),
      Loaded([task_type]),
      Loaded([capability]),
      Loaded([org_user]),
      Loaded([3]),
    )

  let assert [] = data.tasks
  let assert [loaded_task_type] = data.task_types
  let assert 1 = loaded_task_type.id
  let assert [loaded_capability] = data.capabilities
  let assert "Backend" = loaded_capability.name
  let assert [loaded_org_user] = data.org_users
  let assert 7 = loaded_org_user.id
  let assert [3] = data.my_capability_ids
}

pub fn from_remotes_defaults_non_loaded_values_to_empty_lists_test() {
  let data =
    center_panel_data.from_remotes(
      NotAsked,
      NotAsked,
      NotAsked,
      NotAsked,
      NotAsked,
    )

  let assert [] = data.tasks
  let assert [] = data.task_types
  let assert [] = data.capabilities
  let assert [] = data.org_users
  let assert [] = data.my_capability_ids
}
