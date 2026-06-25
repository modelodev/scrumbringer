import domain/task/state as task_state
import gleam/option.{None, Some}
import scrumbringer_server/http/tasks/filters
import support/assertions as expect

pub fn parse_filters_accepts_available_status_test() {
  case filters.parse_task_filters([#("status", "available")]) {
    Ok(task_filters) ->
      task_filters.status |> expect.equal(Some(task_state.FilterAvailable))
    Error(_) -> expect.fail()
  }
}

pub fn parse_filters_accepts_claimed_status_test() {
  case filters.parse_task_filters([#("status", "claimed")]) {
    Ok(task_filters) ->
      task_filters.status |> expect.equal(Some(task_state.FilterClaimed))
    Error(_) -> expect.fail()
  }
}

pub fn parse_filters_accepts_completed_status_as_closed_filter_test() {
  case filters.parse_task_filters([#("status", "completed")]) {
    Ok(task_filters) ->
      task_filters.status |> expect.equal(Some(task_state.FilterClosed))
    Error(_) -> expect.fail()
  }
}

pub fn parse_filters_rejects_invalid_status_test() {
  case filters.parse_task_filters([#("status", "unknown")]) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_rejects_duplicate_status_test() {
  case
    filters.parse_task_filters([
      #("status", "available"),
      #("status", "claimed"),
    ])
  {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_rejects_invalid_type_id_test() {
  case filters.parse_task_filters([#("type_id", "abc")]) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_rejects_capability_id_with_commas_test() {
  case filters.parse_task_filters([#("capability_id", "1,2")]) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_rejects_duplicate_q_values_test() {
  case filters.parse_task_filters([#("q", "one"), #("q", "two")]) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_treats_empty_q_as_none_test() {
  case filters.parse_task_filters([#("q", "")]) {
    Ok(task_filters) -> task_filters.q |> expect.equal(None)
    Error(_) -> expect.fail()
  }
}

pub fn parse_filters_rejects_invalid_blocked_test() {
  case filters.parse_task_filters([#("blocked", "maybe")]) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn parse_filters_accepts_blocked_true_test() {
  case filters.parse_task_filters([#("blocked", "true")]) {
    Ok(task_filters) -> task_filters.blocked |> expect.equal(Some(True))
    Error(_) -> expect.fail()
  }
}

pub fn parse_filters_accepts_blocked_false_test() {
  case filters.parse_task_filters([#("blocked", "false")]) {
    Ok(task_filters) -> task_filters.blocked |> expect.equal(Some(False))
    Error(_) -> expect.fail()
  }
}

pub fn single_query_value_public_wrapper_rejects_duplicates_test() {
  let assert Error(Nil) =
    filters.single_query_value([#("q", "one"), #("q", "two")], "q")
}
