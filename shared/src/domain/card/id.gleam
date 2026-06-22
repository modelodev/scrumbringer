//// Typed card identifiers for shared domain contracts.

pub opaque type CardId {
  CardId(Int)
}

pub fn new(value: Int) -> CardId {
  CardId(value)
}

pub fn to_int(id: CardId) -> Int {
  let CardId(value) = id
  value
}
