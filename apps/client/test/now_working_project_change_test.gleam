import gleam/option
import scrumbringer_client/client_update

pub fn pauses_active_task_on_project_change_in_member_app_test() {
  let assert True =
    client_update.should_pause_active_task_on_project_change(
      True,
      option.Some(1),
      option.Some(2),
    )
}

pub fn does_not_pause_when_project_unchanged_test() {
  let assert False =
    client_update.should_pause_active_task_on_project_change(
      True,
      option.Some(1),
      option.Some(1),
    )
}

pub fn does_not_pause_outside_member_app_test() {
  let assert False =
    client_update.should_pause_active_task_on_project_change(
      False,
      option.Some(1),
      option.Some(2),
    )
}
