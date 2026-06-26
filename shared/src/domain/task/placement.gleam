//// Task placement in the card hierarchy execution model.

import domain/card/id.{type CardId}

pub type TaskPlacement {
  UnderCard(CardId)
}
