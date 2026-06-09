import domain/field_update
import scrumbringer_server/http/tasks/validators
import support/assertions as expect

pub fn validate_task_title_rejects_empty_test() {
  case validators.validate_task_title("   ") {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn validate_task_title_rejects_too_long_test() {
  let long = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  case validators.validate_task_title(long) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn validate_priority_rejects_out_of_range_test() {
  case validators.validate_priority(0) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}

pub fn validate_optional_priority_rejects_invalid_value_test() {
  case validators.validate_optional_priority(field_update.set(0)) {
    Ok(_) -> expect.fail()
    Error(resp) -> expect.expect_status(resp, 422)
  }
}
