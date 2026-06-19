//// Card execution state for the card tree model.

import domain/card/id as card_id
import domain/user/id as user_id

pub type CardExecutionState {
  Draft
  Active(
    activated_at: String,
    activated_by: user_id.UserId,
    source: ActivationSource,
  )
  Closed(reason: CardClosedReason, closed_at: String, closed_by: user_id.UserId)
}

pub type ActivationSource {
  DirectActivation
  ActivatedByAncestor(card_id.CardId)
}

pub type CardClosedReason {
  Rollup
  ManuallyClosed
}
