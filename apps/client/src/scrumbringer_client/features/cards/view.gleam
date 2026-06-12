//// Member cards view component.
////
//// ## Mission
////
//// Render the cards list for members to view and interact with.
////
//// ## Responsibilities
////
//// - Display cards list with state badges and color indicators
//// - Handle card selection for detail modal
//// - Show empty state when no cards
//// - Render card detail modal component when card is selected
////
//// ## Relations
////
//// - **client_view.gleam**: Imports and renders this component
//// - **features/cards/view_config.gleam**: Builds configs from root state
//// - **api/cards.gleam**: Handles card data fetching
//// - **components/card_detail_modal.gleam**: Card detail component

import gleam/dynamic/decode
import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/features/cards/detail_modal_entry
import scrumbringer_client/features/cards/list_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    pending_count: Int,
    detail_card: Option(Card),
    detail_tasks: List(Task),
    current_user_id: Option(Int),
    can_manage_notes: Bool,
    on_card_opened: fn(Int) -> msg,
    on_create_task_in_card: fn(Int) -> msg,
    on_detail_closed: msg,
  )
}

// =============================================================================
// View Functions
// =============================================================================

/// Main entry point for the cards view.
pub fn view_cards(config: Config(msg)) -> Element(msg) {
  div([attribute.class("content")], [
    div([attribute.class("section")], [
      view_cards_header(config),
      view_cards_content(config),
    ]),
    view_card_detail_modal(config),
  ])
}

fn view_cards_header(config: Config(msg)) -> Element(msg) {
  section_header.view(
    icons.Cards,
    i18n.t(config.locale, i18n_text.MemberCards),
  )
}

fn view_cards_content(config: Config(msg)) -> Element(msg) {
  list_view.Config(
    locale: config.locale,
    cards: config.cards,
    pending_count: config.pending_count,
    on_card_opened: config.on_card_opened,
  )
  |> list_view.view
}

// =============================================================================
// Card Detail Modal Component Integration
// =============================================================================

/// Render the card-detail-modal custom element when a card is open.
/// Made public for use in client_view.gleam (Story 5.3: Pool/Kanban card detail)
pub fn view_card_detail_modal(config: Config(msg)) -> Element(msg) {
  detail_modal_entry.view(detail_modal_entry.Config(
    card: config.detail_card,
    tasks: config.detail_tasks,
    locale: config.locale,
    current_user_id: config.current_user_id,
    can_manage_notes: config.can_manage_notes,
    on_create_task: decode_create_task_event(config),
    on_close: decode_close_detail_event(config),
  ))
}

/// Decoder for create-task-requested event.
/// Opens the main task creation dialog with card_id pre-filled.
fn decode_create_task_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("card_id", decode.int, decode.success),
    fn(card_id) { decode.success(config.on_create_task_in_card(card_id)) },
  )
}

/// Decoder for close-requested event.
fn decode_close_detail_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.message(config.on_detail_closed)
}
