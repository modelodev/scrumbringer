//// Database operations for user card views.

import gleam/result
import pog
import scrumbringer_server/sql

/// A user-card view record.
pub type UserCardView {
  UserCardView(user_id: Int, card_id: Int, last_viewed_at: String)
}

/// Updates last_viewed_at for a user and card.
pub fn touch_card_view(
  db: pog.Connection,
  user_id: Int,
  card_id: Int,
) -> Result(UserCardView, pog.QueryError) {
  use returned <- result.try(sql.user_card_views_upsert(db, user_id, card_id))

  case returned.rows {
    [row, ..] ->
      Ok(UserCardView(
        user_id: row.user_id,
        card_id: row.card_id,
        last_viewed_at: row.last_viewed_at,
      ))
    _ -> Error(pog.UnexpectedArgumentCount(1, 0))
  }
}
