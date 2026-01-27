import gleeunit/should
import scrumbringer_server/http/tasks/validators
import scrumbringer_server/services/workflows/types as workflow_types

pub fn validate_task_title_rejects_empty_test() {
  case validators.validate_task_title("   ") {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn validate_task_title_rejects_too_long_test() {
  let long =
    "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  case validators.validate_task_title(long) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn validate_priority_rejects_out_of_range_test() {
  case validators.validate_priority(0) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}

pub fn validate_optional_priority_rejects_invalid_value_test() {
  case validators.validate_optional_priority(workflow_types.Set(0)) {
    Ok(_) -> should.fail()
    Error(resp) -> resp.status |> should.equal(422)
  }
}
