import scrumbringer_client/capability_scope

pub fn parse_all_test() {
  let assert Ok(capability_scope.AllCapabilities) =
    capability_scope.parse("all")
}

pub fn parse_mine_test() {
  let assert Ok(capability_scope.MyCapabilities) =
    capability_scope.parse("mine")
}

pub fn parse_rejects_unknown_test() {
  let assert Error(Nil) = capability_scope.parse("unknown")
}
