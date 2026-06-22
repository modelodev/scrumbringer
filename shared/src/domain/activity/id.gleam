//// Typed activity event identifiers for shared domain contracts.

pub opaque type ActivityId {
  ActivityId(Int)
}

pub fn new(value: Int) -> ActivityId {
  ActivityId(value)
}

pub fn to_int(id: ActivityId) -> Int {
  let ActivityId(value) = id
  value
}
