import gleam/string

/// Pool-specific visibility selector for open work.
pub type PoolVisibility {
  AllOpen
  ReadyToClaim
  Blocked
}

/// The default Pool visibility keeps blockers visible.
pub fn default() -> PoolVisibility {
  AllOpen
}

pub fn parse(value: String) -> Result(PoolVisibility, Nil) {
  case string.trim(value) {
    "all-open" -> Ok(AllOpen)
    "ready-to-claim" -> Ok(ReadyToClaim)
    "blocked" -> Ok(Blocked)
    _ -> Error(Nil)
  }
}

pub fn to_string(visibility: PoolVisibility) -> String {
  case visibility {
    AllOpen -> "all-open"
    ReadyToClaim -> "ready-to-claim"
    Blocked -> "blocked"
  }
}

pub fn label(visibility: PoolVisibility) -> String {
  case visibility {
    AllOpen -> "Abiertas"
    ReadyToClaim -> "Reclamables"
    Blocked -> "Bloqueadas"
  }
}

pub fn allows_blocked(visibility: PoolVisibility) -> Bool {
  case visibility {
    AllOpen | Blocked -> True
    ReadyToClaim -> False
  }
}

pub fn matches(visibility: PoolVisibility, blocked_count: Int) -> Bool {
  case visibility {
    AllOpen -> True
    ReadyToClaim -> blocked_count == 0
    Blocked -> blocked_count > 0
  }
}
