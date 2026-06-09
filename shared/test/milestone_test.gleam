import domain/milestone

pub fn state_to_string_test() {
  let assert "ready" = milestone.state_to_string(milestone.Ready)
  let assert "active" = milestone.state_to_string(milestone.Active)
  let assert "completed" = milestone.state_to_string(milestone.Completed)
}

pub fn parse_state_test() {
  let assert Ok(milestone.Ready) = milestone.parse_state("ready")
  let assert Ok(milestone.Active) = milestone.parse_state("active")
  let assert Ok(milestone.Completed) = milestone.parse_state("completed")
}

pub fn parse_state_rejects_unknown_values_test() {
  let assert Error(milestone.UnknownMilestoneState("invalid")) =
    milestone.parse_state("invalid")
  let assert Error(milestone.UnknownMilestoneState("")) =
    milestone.parse_state("")
}

pub fn state_from_string_rejects_unknown_values_test() {
  let assert Error(milestone.UnknownMilestoneState("invalid")) =
    milestone.state_from_string("invalid")
  let assert Error(milestone.UnknownMilestoneState("")) =
    milestone.state_from_string("")
}
