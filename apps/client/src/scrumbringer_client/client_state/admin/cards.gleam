//// Card admin state.

import gleam/option.{type Option}

import domain/card.{type Card, type CardState}
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/types as state_types

/// Represents card admin state.
pub type Model {
  Model(
    cards: Remote(List(Card)),
    cards_project_id: Option(Int),
    cards_dialog_mode: Option(state_types.CardDialogMode),
    cards_create_milestone_id: Option(Int),
    cards_show_empty: Bool,
    cards_show_completed: Bool,
    cards_state_filter: Option(CardState),
    cards_search: String,
  )
}

/// Provides default card admin state.
pub fn default_model() -> Model {
  Model(
    cards: NotAsked,
    cards_project_id: option.None,
    cards_dialog_mode: option.None,
    cards_create_milestone_id: option.None,
    cards_show_empty: False,
    cards_show_completed: False,
    cards_state_filter: option.None,
    cards_search: "",
  )
}
