//// Admin cards update handlers.
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

import domain/api_error.{type ApiError, type ApiResult}
import domain/card.{type Card, Card, parse_state}
import domain/remote.{Failed, Loaded, Loading}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/api/cards as api_cards

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_cards_fetched: fn(ApiResult(List(Card))) -> parent_msg,
  )
}

pub type CrudFeedbackContext(parent_msg) {
  CrudFeedbackContext(
    card_created: String,
    card_updated: String,
    card_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type FocusPolicy {
  NoFocusAfterUpdate
  FocusAfterClose
}

pub type Update(parent_msg) {
  Update(admin_cards.Model, Effect(parent_msg), AuthPolicy, FocusPolicy)
}

pub fn try_update(
  model: admin_cards.Model,
  inner: pool_messages.Msg,
  feedback_context: CrudFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.CardsFetched(Ok(cards)) ->
      handle_cards_fetched_ok(model, cards)
      |> without_policies

    pool_messages.CardsFetched(Error(err)) ->
      handle_cards_fetched_error(model, err)
      |> with_policies(CheckAuth(err), NoFocusAfterUpdate)

    pool_messages.OpenCardDialog(mode) ->
      handle_open_card_dialog(model, mode)
      |> without_policies

    pool_messages.CloseCardDialog ->
      handle_close_card_dialog(model)
      |> with_policies(NoAuthCheck, FocusAfterClose)

    pool_messages.CardCrudCreated(card) ->
      handle_card_crud_created(model, card, feedback_context)
      |> without_policies

    pool_messages.CardCrudUpdated(card) ->
      handle_card_crud_updated(model, card, feedback_context)
      |> without_policies

    pool_messages.CardCrudDeleted(card_id) ->
      handle_card_crud_deleted(model, card_id, feedback_context)
      |> without_policies

    pool_messages.CardsShowEmptyToggled ->
      handle_show_empty_toggled(model)
      |> without_policies

    pool_messages.CardsShowClosedToggled ->
      handle_show_closed_toggled(model)
      |> without_policies

    pool_messages.CardsStateFilterChanged(state) ->
      handle_state_filter_changed(model, state)
      |> without_policies

    pool_messages.CardsSearchChanged(query) ->
      handle_search_changed(model, query)
      |> without_policies

    _ -> opt.None
  }
}

fn without_policies(
  result: #(admin_cards.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, NoAuthCheck, NoFocusAfterUpdate)
}

fn with_policies(
  result: #(admin_cards.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  focus_policy: FocusPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, focus_policy))
}

// =============================================================================
// Fetch Handlers
// =============================================================================

/// Handle cards fetch success.
fn handle_cards_fetched_ok(
  model: admin_cards.Model,
  cards: List(Card),
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(admin_cards.Model(..model, cards: Loaded(cards)), effect.none())
}

/// Handle cards fetch error.
fn handle_cards_fetched_error(
  model: admin_cards.Model,
  err: ApiError,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(admin_cards.Model(..model, cards: Failed(err)), effect.none())
}

// =============================================================================
// Dialog Mode Handlers
// =============================================================================

/// Handle opening a card dialog (create, edit, or delete).
fn handle_open_card_dialog(
  model: admin_cards.Model,
  mode: admin_cards.CardDialogMode,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(
    admin_cards.Model(..model, cards_dialog_mode: opt.Some(mode)),
    effect.none(),
  )
}

/// Handle closing any open card dialog.
fn handle_close_card_dialog(
  model: admin_cards.Model,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(admin_cards.Model(..model, cards_dialog_mode: opt.None), effect.none())
}

// =============================================================================
// Component Event Handlers
// =============================================================================

/// Handle card created event from component.
/// Adds the new card to the list and shows a toast.
fn handle_card_crud_created(
  model: admin_cards.Model,
  card: Card,
  context: CrudFeedbackContext(parent_msg),
) -> #(admin_cards.Model, Effect(parent_msg)) {
  let cards = case model.cards {
    Loaded(existing) -> Loaded([card, ..existing])
    _ -> Loaded([card])
  }
  #(
    admin_cards.Model(..model, cards: cards, cards_dialog_mode: opt.None),
    context.on_success_toast(context.card_created),
  )
}

/// Handle card updated event from component.
/// Updates the card in the list and shows a toast.
fn handle_card_crud_updated(
  model: admin_cards.Model,
  updated_card: Card,
  context: CrudFeedbackContext(parent_msg),
) -> #(admin_cards.Model, Effect(parent_msg)) {
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
    admin_cards.Model(..model, cards: cards, cards_dialog_mode: opt.None),
    context.on_success_toast(context.card_updated),
  )
}

/// Handle card deleted event from component.
/// Removes the card from the list and shows a toast.
fn handle_card_crud_deleted(
  model: admin_cards.Model,
  card_id: Int,
  context: CrudFeedbackContext(parent_msg),
) -> #(admin_cards.Model, Effect(parent_msg)) {
  let cards = case model.cards {
    Loaded(existing) -> Loaded(list.filter(existing, fn(c) { c.id != card_id }))
    other -> other
  }
  #(
    admin_cards.Model(..model, cards: cards, cards_dialog_mode: opt.None),
    context.on_success_toast(context.card_deleted),
  )
}

pub fn handle_card_viewed(
  model: admin_cards.Model,
  card_id: Int,
) -> admin_cards.Model {
  let cards = case model.cards {
    Loaded(existing) ->
      Loaded(
        list.map(existing, fn(card) {
          case card.id == card_id {
            True -> Card(..card, has_new_notes: False)
            False -> card
          }
        }),
      )
    other -> other
  }

  admin_cards.Model(..model, cards: cards)
}

fn handle_show_empty_toggled(
  model: admin_cards.Model,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(
    admin_cards.Model(..model, cards_show_empty: !model.cards_show_empty),
    effect.none(),
  )
}

fn handle_show_closed_toggled(
  model: admin_cards.Model,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(
    admin_cards.Model(..model, cards_show_closed: !model.cards_show_closed),
    effect.none(),
  )
}

fn handle_state_filter_changed(
  model: admin_cards.Model,
  state_str: String,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  let filter = case state_str {
    "" -> opt.None
    _ ->
      case parse_state(state_str) {
        Ok(state) -> opt.Some(state)
        Error(_) -> opt.None
      }
  }

  #(admin_cards.Model(..model, cards_state_filter: filter), effect.none())
}

fn handle_search_changed(
  model: admin_cards.Model,
  query: String,
) -> #(admin_cards.Model, Effect(parent_msg)) {
  #(admin_cards.Model(..model, cards_search: query), effect.none())
}

// =============================================================================
// Fetch Helper
// =============================================================================

/// Fetch cards for the selected project.
pub fn fetch_cards_for_project(
  model: admin_cards.Model,
  context: Context(parent_msg),
) -> #(admin_cards.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> {
      let model =
        admin_cards.Model(
          ..model,
          cards: Loading,
          cards_project_id: opt.Some(project_id),
        )
      #(model, api_cards.list_cards(project_id, context.on_cards_fetched))
    }
    opt.None -> #(model, effect.none())
  }
}
