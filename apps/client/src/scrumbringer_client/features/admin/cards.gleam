//// Admin cards (fichas) update handlers.
////
//// ## Mission
////
//// Handles card CRUD operations in the admin panel: list, create, edit, delete.
////
//// ## Responsibilities
////
//// - Card form field changes
//// - Create card submission and result handling
//// - Edit card dialog open/close and submission
//// - Delete card confirmation and result handling
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **view.gleam**: Renders the cards UI using model state

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/card.{type Card}
import scrumbringer_client/client_state.{
  type Model, type Msg, CardCreated, CardDeleted, CardUpdated, Failed, Loaded,
  Loading, Model,
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

fn validate_card_title(model: Model, title: String) -> Result(String, String) {
  case title {
    "" -> Error(update_helpers.i18n_t(model, i18n_text.TitleRequired))
    _ -> Ok(title)
  }
}

// =============================================================================
// Dialog Handlers
// =============================================================================

/// Handle card create dialog open.
pub fn handle_card_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_create_dialog_open: True), effect.none())
}

/// Handle card create dialog close.
pub fn handle_card_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cards_create_dialog_open: False,
      cards_create_title: "",
      cards_create_description: "",
      cards_create_color: opt.None,
      cards_create_color_open: False,
      cards_create_error: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Create Handlers
// =============================================================================

/// Handle card create title change.
pub fn handle_card_create_title_changed(
  model: Model,
  title: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_create_title: title), effect.none())
}

/// Handle card create description change.
pub fn handle_card_create_description_changed(
  model: Model,
  description: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_create_description: description), effect.none())
}

/// Handle card create color change.
pub fn handle_card_create_color_changed(
  model: Model,
  color: opt.Option(String),
) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, cards_create_color: color, cards_create_color_open: False),
    effect.none(),
  )
}

/// Handle card create color toggle.
pub fn handle_card_create_color_toggle(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, cards_create_color_open: !model.cards_create_color_open),
    effect.none(),
  )
}

/// Handle card create form submission.
pub fn handle_card_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.cards_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.selected_project_id {
        opt.Some(project_id) -> {
          case validate_card_title(model, model.cards_create_title) {
            Error(error_msg) -> #(
              Model(..model, cards_create_error: opt.Some(error_msg)),
              effect.none(),
            )
            Ok(title) -> {
              let model =
                Model(
                  ..model,
                  cards_create_in_flight: True,
                  cards_create_error: opt.None,
                )
              #(
                model,
                api_cards.create_card(
                  project_id,
                  title,
                  model.cards_create_description,
                  model.cards_create_color,
                  CardCreated,
                ),
              )
            }
          }
        }
        opt.None -> #(
          Model(
            ..model,
            cards_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.SelectProjectFirst,
            )),
          ),
          effect.none(),
        )
      }
    }
  }
}

/// Handle card created success.
pub fn handle_card_created_ok(model: Model, card: Card) -> #(Model, Effect(Msg)) {
  let cards = case model.cards {
    Loaded(existing) -> Loaded([card, ..existing])
    _ -> Loaded([card])
  }
  #(
    Model(
      ..model,
      cards: cards,
      cards_create_dialog_open: False,
      cards_create_title: "",
      cards_create_description: "",
      cards_create_color: opt.None,
      cards_create_color_open: False,
      cards_create_in_flight: False,
      cards_create_error: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardCreated)),
    ),
    effect.none(),
  )
}

/// Handle card created error.
pub fn handle_card_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        cards_create_in_flight: False,
        cards_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Edit Handlers
// =============================================================================

/// Handle card edit button clicked.
pub fn handle_card_edit_clicked(
  model: Model,
  card: Card,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cards_edit_id: opt.Some(card.id),
      cards_edit_title: card.title,
      cards_edit_description: card.description,
      cards_edit_color: card.color,
      cards_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle card edit title change.
pub fn handle_card_edit_title_changed(
  model: Model,
  title: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_edit_title: title), effect.none())
}

/// Handle card edit description change.
pub fn handle_card_edit_description_changed(
  model: Model,
  description: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, cards_edit_description: description), effect.none())
}

/// Handle card edit color change.
pub fn handle_card_edit_color_changed(
  model: Model,
  color: opt.Option(String),
) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, cards_edit_color: color, cards_edit_color_open: False),
    effect.none(),
  )
}

/// Handle card edit color toggle.
pub fn handle_card_edit_color_toggle(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, cards_edit_color_open: !model.cards_edit_color_open),
    effect.none(),
  )
}

/// Handle card edit form submission.
pub fn handle_card_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.cards_edit_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.cards_edit_id {
        opt.Some(card_id) -> {
          case validate_card_title(model, model.cards_edit_title) {
            Error(error_msg) -> #(
              Model(..model, cards_edit_error: opt.Some(error_msg)),
              effect.none(),
            )
            Ok(title) -> {
              let model =
                Model(
                  ..model,
                  cards_edit_in_flight: True,
                  cards_edit_error: opt.None,
                )
              #(
                model,
                api_cards.update_card(
                  card_id,
                  title,
                  model.cards_edit_description,
                  model.cards_edit_color,
                  CardUpdated,
                ),
              )
            }
          }
        }
        opt.None -> #(model, effect.none())
      }
    }
  }
}

/// Handle card edit cancelled.
pub fn handle_card_edit_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cards_edit_id: opt.None,
      cards_edit_title: "",
      cards_edit_description: "",
      cards_edit_color: opt.None,
      cards_edit_color_open: False,
      cards_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle card updated success.
pub fn handle_card_updated_ok(
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
      cards_edit_id: opt.None,
      cards_edit_title: "",
      cards_edit_description: "",
      cards_edit_color: opt.None,
      cards_edit_color_open: False,
      cards_edit_in_flight: False,
      cards_edit_error: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardUpdated)),
    ),
    effect.none(),
  )
}

/// Handle card updated error.
pub fn handle_card_updated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        cards_edit_in_flight: False,
        cards_edit_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Delete Handlers
// =============================================================================

/// Handle card delete button clicked.
pub fn handle_card_delete_clicked(
  model: Model,
  card: Card,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      cards_delete_confirm: opt.Some(card),
      cards_delete_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle card delete cancelled.
pub fn handle_card_delete_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, cards_delete_confirm: opt.None, cards_delete_error: opt.None),
    effect.none(),
  )
}

/// Handle card delete confirmed.
pub fn handle_card_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.cards_delete_in_flight {
    True -> #(model, effect.none())
    False -> {
      case model.cards_delete_confirm {
        opt.Some(card) -> {
          let model =
            Model(
              ..model,
              cards_delete_in_flight: True,
              cards_delete_error: opt.None,
            )
          #(model, api_cards.delete_card(card.id, CardDeleted))
        }
        opt.None -> #(model, effect.none())
      }
    }
  }
}

/// Handle card deleted success.
pub fn handle_card_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let deleted_id = case model.cards_delete_confirm {
    opt.Some(card) -> opt.Some(card.id)
    opt.None -> opt.None
  }
  let cards = case model.cards, deleted_id {
    Loaded(existing), opt.Some(id) ->
      Loaded(list.filter(existing, fn(c) { c.id != id }))
    other, _ -> other
  }
  #(
    Model(
      ..model,
      cards: cards,
      cards_delete_confirm: opt.None,
      cards_delete_in_flight: False,
      cards_delete_error: opt.None,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.CardDeleted)),
    ),
    effect.none(),
  )
}

/// Handle card deleted error.
pub fn handle_card_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    409 ->
      // CONFLICT_HAS_TASKS
      #(
        Model(
          ..model,
          cards_delete_in_flight: False,
          cards_delete_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.CardDeleteBlocked,
          )),
        ),
        effect.none(),
      )
    _ -> #(
      Model(
        ..model,
        cards_delete_in_flight: False,
        cards_delete_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
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
      #(model, api_cards.list_cards(project_id, client_state.CardsFetched))
    }
    opt.None -> #(model, effect.none())
  }
}
