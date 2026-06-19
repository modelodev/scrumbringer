//// Typed project identifiers for shared domain contracts.

pub opaque type ProjectId {
  ProjectId(Int)
}

pub fn new(value: Int) -> ProjectId {
  ProjectId(value)
}

pub fn to_int(id: ProjectId) -> Int {
  let ProjectId(value) = id
  value
}
