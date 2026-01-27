import gleeunit/should
import scrumbringer_server/services/rules_target

pub fn from_strings_rejects_invalid_resource_type_test() {
  case rules_target.from_strings("nope", 0, "ready") {
    Ok(_) -> should.fail()
    Error(rules_target.InvalidResourceType) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn from_strings_rejects_task_type_for_card_test() {
  case rules_target.from_strings("card", 3, "archived") {
    Ok(_) -> should.fail()
    Error(rules_target.TaskTypeNotAllowedForCard) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn from_strings_accepts_task_with_type_test() {
  case rules_target.from_strings("task", 7, "claimed") {
    Ok(target) ->
      rules_target.resource_type(target) |> should.equal("task")
    Error(_) -> should.fail()
  }
}

pub fn to_db_values_encodes_task_rule_test() {
  let assert Ok(target) = rules_target.from_strings("task", 2, "done")

  rules_target.to_db_values(target)
  |> should.equal(#("task", 2, "done"))
}

pub fn to_db_values_encodes_card_rule_test() {
  let assert Ok(target) = rules_target.from_strings("card", 0, "closed")

  rules_target.to_db_values(target)
  |> should.equal(#("card", 0, "closed"))
}
