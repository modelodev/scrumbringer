//// Typed note identifiers for shared domain contracts.

pub opaque type NoteId {
  NoteId(Int)
}

pub fn new(value: Int) -> NoteId {
  NoteId(value)
}

pub fn to_int(id: NoteId) -> Int {
  let NoteId(value) = id
  value
}
