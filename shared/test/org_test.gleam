import domain/org

pub fn invite_link_state_to_string_test() {
  let assert "active" = org.invite_link_state_to_string(org.Active)
  let assert "used" = org.invite_link_state_to_string(org.Used)
  let assert "invalidated" = org.invite_link_state_to_string(org.Invalidated)
}

pub fn parse_invite_link_state_test() {
  let assert Ok(org.Active) = org.parse_invite_link_state("active")
  let assert Ok(org.Used) = org.parse_invite_link_state("used")
  let assert Ok(org.Invalidated) = org.parse_invite_link_state("invalidated")
}

pub fn parse_invite_link_state_accepts_expired_alias_test() {
  let assert Ok(org.Invalidated) = org.parse_invite_link_state("expired")
}

pub fn parse_invite_link_state_rejects_unknown_values_test() {
  let assert Error(org.UnknownInviteLinkState("pending")) =
    org.parse_invite_link_state("pending")
  let assert Error(org.UnknownInviteLinkState("")) =
    org.parse_invite_link_state("")
}

pub fn invite_link_state_from_string_rejects_unknown_values_test() {
  let assert Error(org.UnknownInviteLinkState("pending")) =
    org.invite_link_state_from_string("pending")
  let assert Error(org.UnknownInviteLinkState("")) =
    org.invite_link_state_from_string("")
}
