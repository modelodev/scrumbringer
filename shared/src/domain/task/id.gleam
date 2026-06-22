//// Typed task identifiers for shared domain contracts.

pub opaque type TaskId {
  TaskId(Int)
}

pub fn new(value: Int) -> TaskId {
  TaskId(value)
}

pub fn to_int(id: TaskId) -> Int {
  let TaskId(value) = id
  value
}
