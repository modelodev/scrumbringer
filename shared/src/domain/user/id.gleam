//// Typed user identifiers for shared domain contracts.

pub opaque type UserId {
  UserId(Int)
}

pub fn new(value: Int) -> UserId {
  UserId(value)
}

pub fn to_int(id: UserId) -> Int {
  let UserId(value) = id
  value
}
