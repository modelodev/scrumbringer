import gleam/option.{type Option, None, Some}

pub type CapabilityScope {
  AllCapabilities
  MyCapabilities
}

pub fn default() -> CapabilityScope {
  AllCapabilities
}

pub fn from_string(raw: String) -> CapabilityScope {
  case raw {
    "mine" -> MyCapabilities
    _ -> AllCapabilities
  }
}

pub fn from_string_option(raw: String) -> Option(CapabilityScope) {
  case raw {
    "all" -> Some(AllCapabilities)
    "mine" -> Some(MyCapabilities)
    _ -> None
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
