import gleam/option
import gleeunit/should
import scrumbringer_client

pub fn pauses_active_task_on_project_change_in_member_app_test() {
  scrumbringer_client.should_pause_active_task_on_project_change(
    True,
    option.Some(1),
    option.Some(2),
  )
  |> should.equal(True)
}

pub fn does_not_pause_when_project_unchanged_test() {
  scrumbringer_client.should_pause_active_task_on_project_change(
    True,
    option.Some(1),
    option.Some(1),
  )
  |> should.equal(False)
}

pub fn does_not_pause_outside_member_app_test() {
  scrumbringer_client.should_pause_active_task_on_project_change(
    False,
    option.Some(1),
    option.Some(2),
  )
  |> should.equal(False)
}
