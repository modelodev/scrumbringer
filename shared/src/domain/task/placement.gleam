//// Task placement in the card tree execution model.

import domain/card/id.{type CardId}

pub type TaskPlacement {
  RootPool
  UnderCard(CardId)
}
