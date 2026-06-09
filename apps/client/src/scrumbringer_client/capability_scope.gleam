pub type CapabilityScope {
  AllCapabilities
  MyCapabilities
}

pub fn default() -> CapabilityScope {
  AllCapabilities
}

pub fn parse(raw: String) -> Result(CapabilityScope, Nil) {
  case raw {
    "all" -> Ok(AllCapabilities)
    "mine" -> Ok(MyCapabilities)
    _ -> Error(Nil)
  }
}

pub fn to_string(scope: CapabilityScope) -> String {
  case scope {
    AllCapabilities -> "all"
    MyCapabilities -> "mine"
  }
}

pub fn is_default(scope: CapabilityScope) -> Bool {
  scope == default()
}
