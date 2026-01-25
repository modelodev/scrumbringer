//// Admin cards (fichas) update handlers.
////
//// ## Mission
////
//// Handles card list loading and dialog mode management for the admin panel.
//// CRUD operations are handled by the card-crud-dialog Lustre component.
////
//// ## Responsibilities
////
//// - Cards list fetch and error handling
//// - Dialog mode state management (open/close)
//// - Processing component events (card created/updated/deleted)
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the cards UI and card-crud-dialog component
//// - **components/card_crud_dialog.gleam**: Lustre component handling CRUD

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/card.{type Card}
import scrumbringer_client/client_state.{
  type CardDialogMode, type Model, type Msg, CardsFetched, Failed, Loaded,
  Loading, Model, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

import scrumbringer_client/api/cards as api_cards

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle cards fetch success.
pub fn handle_cards_fetched_ok(
  model: Model,
  cards: List(Card),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards: Loaded(cards)), effect.none())
}

/// Handle cards fetch error.
pub fn handle_cards_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, cards: Failed(err)), effect.none())
  }
}

// =============================================================================
// Dialog Mode Handlers
// =============================================================================

/// Handle opening a card dialog (create, edit, or delete).
pub fn handle_open_card_dialog(
  model: Model,
  mode: CardDialogMode,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_dialog_mode: opt.Some(mode)), effect.none())
}

/// Handle closing any open card dialog.
pub fn handle_close_card_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_dialog_mode: opt.None), effect.none())
}

// =============================================================================
// Component Event Handlers
// =============================================================================

/// Handle card created event from component.
/// Adds the new card to the list and shows a toast.
pub fn handle_card_crud_created(
  model: Model,
  card: Card,
) -> #(Model, Effect(Msg)) {
  let cards = case model.cards {
    Loaded(existing) -> Loaded([card, ..existing])
    _ -> Loaded([card])
  }
  #(
    Model(
      ..model,
      cards: cards,
      cards_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardCreated)),
    ),
    effect.none(),
  )
}

/// Handle card updated event from component.
/// Updates the card in the list and shows a toast.
pub fn handle_card_crud_updated(
  model: Model,
  updated_card: Card,
) -> #(Model, Effect(Msg)) {
  let cards = case model.cards {
    Loaded(existing) ->
      Loaded(
        list.map(existing, fn(c) {
          case c.id == updated_card.id {
            True -> updated_card
            False -> c
          }
        }),
      )
    other -> other
  }
  #(
    Model(
      ..model,
      cards: cards,
      cards_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardUpdated)),
    ),
    effect.none(),
  )
}

/// Handle card deleted event from component.
/// Removes the card from the list and shows a toast.
pub fn handle_card_crud_deleted(
  model: Model,
  card_id: Int,
) -> #(Model, Effect(Msg)) {
  let cards = case model.cards {
    Loaded(existing) -> Loaded(list.filter(existing, fn(c) { c.id != card_id }))
    other -> other
  }
  #(
    Model(
      ..model,
      cards: cards,
      cards_dialog_mode: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardDeleted)),
    ),
    effect.none(),
  )
}

// =============================================================================
// Fetch Helper
// =============================================================================

/// Fetch cards for the selected project.
pub fn fetch_cards_for_project(model: Model) -> #(Model, Effect(Msg)) {
  case model.selected_project_id {
    opt.Some(project_id) -> {
      let model =
        Model(..model, cards: Loading, cards_project_id: opt.Some(project_id))
      #(
        model,
        api_cards.list_cards(project_id, fn(result) -> Msg {
          pool_msg(CardsFetched(result))
        }),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

// =============================================================================
// Helpers for View
// =============================================================================

/// Find a card by ID in the loaded cards list.
pub fn find_card(model: Model, card_id: Int) -> opt.Option(Card) {
  case model.cards {
    Loaded(cards) ->
      list.find(cards, fn(c) { c.id == card_id })
      |> opt.from_result
    _ -> opt.None
  }
}
