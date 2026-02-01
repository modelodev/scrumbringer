import gleam/option.{None, Some}
import gleeunit/should
import scrumbringer_server/http/tasks/filters

pub fn parse_filters_rejects_invalid_status_test() {
  case filters.parse_task_filters([#("status", "unknown")]) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_rejects_duplicate_status_test() {
  case
    filters.parse_task_filters([
      #("status", "available"),
      #("status", "claimed"),
    ])
  {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_rejects_invalid_type_id_test() {
  case filters.parse_task_filters([#("type_id", "abc")]) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_rejects_capability_id_with_commas_test() {
  case filters.parse_task_filters([#("capability_id", "1,2")]) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_rejects_duplicate_q_values_test() {
  case filters.parse_task_filters([#("q", "one"), #("q", "two")]) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_treats_empty_q_as_none_test() {
  case filters.parse_task_filters([#("q", "")]) {
    Ok(task_filters) -> task_filters.q |> should.equal(None)
    Error(_) -> should.fail()
  }
}

pub fn parse_filters_rejects_invalid_blocked_test() {
  case filters.parse_task_filters([#("blocked", "maybe")]) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn parse_filters_accepts_blocked_true_test() {
  case filters.parse_task_filters([#("blocked", "true")]) {
    Ok(task_filters) -> task_filters.blocked |> should.equal(Some(True))
    Error(_) -> should.fail()
  }
}

pub fn parse_filters_accepts_blocked_false_test() {
  case filters.parse_task_filters([#("blocked", "false")]) {
    Ok(task_filters) -> task_filters.blocked |> should.equal(Some(False))
    Error(_) -> should.fail()
  }
}
