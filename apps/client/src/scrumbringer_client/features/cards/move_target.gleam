//// Explicit destinations for moving a card in the Plan structure.

import gleam/option.{type Option, None, Some}

pub type MoveTarget {
  ProjectRoot
  InsideCard(Int)
}

pub fn parent_card_id(target: MoveTarget) -> Option(Int) {
  case target {
    ProjectRoot -> None
    InsideCard(card_id) -> Some(card_id)
  }
}
