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
import domain/remote.{Failed, Loaded, Loading}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle cards fetch success.
pub fn handle_cards_fetched_ok(
  model: client_state.Model,
  cards: List(Card),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(..cards_state, cards: Loaded(cards))
      })
    }),
    effect.none(),
  )
}

/// Handle cards fetch error.
pub fn handle_cards_fetched_error(
  model: client_state.Model,
  err: ApiError,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_cards(admin, fn(cards_state) {
          admin_cards.Model(..cards_state, cards: Failed(err))
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Dialog Mode Handlers
// =============================================================================

/// Handle opening a card dialog (create, edit, or delete).
pub fn handle_open_card_dialog(
  model: client_state.Model,
  mode: client_state.CardDialogMode,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(..cards_state, cards_dialog_mode: opt.Some(mode))
      })
    }),
    effect.none(),
  )
}

/// Handle closing any open card dialog.
pub fn handle_close_card_dialog(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(..cards_state, cards_dialog_mode: opt.None)
      })
    }),
    effect.none(),
  )
}

// =============================================================================
// Component Event Handlers
// =============================================================================

/// Handle card created event from component.
/// Adds the new card to the list and shows a toast.
pub fn handle_card_crud_created(
  model: client_state.Model,
  card: Card,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let cards = case model.admin.cards.cards {
    Loaded(existing) -> Loaded([card, ..existing])
    _ -> Loaded([card])
  }
  let model =
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(
          ..cards_state,
          cards: cards,
          cards_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.CardCreated,
    ))
  #(model, toast_fx)
}

/// Handle card updated event from component.
/// Updates the card in the list and shows a toast.
pub fn handle_card_crud_updated(
  model: client_state.Model,
  updated_card: Card,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let cards = case model.admin.cards.cards {
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
  let model =
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(
          ..cards_state,
          cards: cards,
          cards_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.CardUpdated,
    ))
  #(model, toast_fx)
}

/// Handle card deleted event from component.
/// Removes the card from the list and shows a toast.
pub fn handle_card_crud_deleted(
  model: client_state.Model,
  card_id: Int,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let cards = case model.admin.cards.cards {
    Loaded(existing) -> Loaded(list.filter(existing, fn(c) { c.id != card_id }))
    other -> other
  }
  let model =
    client_state.update_admin(model, fn(admin) {
      update_cards(admin, fn(cards_state) {
        admin_cards.Model(
          ..cards_state,
          cards: cards,
          cards_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.CardDeleted,
    ))
  #(model, toast_fx)
}

// =============================================================================
// Fetch Helper
// =============================================================================

/// Fetch cards for the selected project.
pub fn fetch_cards_for_project(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          update_cards(admin, fn(cards_state) {
            admin_cards.Model(
              ..cards_state,
              cards: Loading,
              cards_project_id: opt.Some(project_id),
            )
          })
        })
      #(
        model,
        api_cards.list_cards(project_id, fn(result) -> client_state.Msg {
          client_state.pool_msg(pool_messages.CardsFetched(result))
        }),
      )
    }
    opt.None -> #(model, effect.none())
  }
}

fn update_cards(
  admin: admin_state.AdminModel,
  f: fn(admin_cards.Model) -> admin_cards.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, cards: f(admin.cards))
}
