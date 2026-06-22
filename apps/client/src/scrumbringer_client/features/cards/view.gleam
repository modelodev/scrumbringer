//// Member cards view component.
////
//// ## Mission
////
//// Render the cards list for members to view and interact with.
////
//// ## Responsibilities
////
//// - Display cards list with state badges and color indicators
//// - Handle card selection for Card Show
//// - Show empty state when no cards
//// - Render Card Show when a card is selected
////
//// ## Relations
////
//// - **client_view.gleam**: Imports and renders this component
//// - **features/cards/view_config.gleam**: Builds configs from root state
//// - **api/cards.gleam**: Handles card data fetching
//// - **components/card_show.gleam**: Card Show component

import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/components/card_show
import scrumbringer_client/features/cards/list_view
import scrumbringer_client/features/cards/show_entry
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    pending_count: Int,
    show_model: card_show.Model,
    show_card: Option(Card),
    show_tasks: List(Task),
    current_user_id: Option(Int),
    can_manage_notes: Bool,
    can_manage_structure: Bool,
    can_execute_work: Bool,
    on_card_opened: fn(Int) -> msg,
    on_card_show_msg: fn(card_show.Msg) -> msg,
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
    view_card_show(config),
  ])
}

fn view_cards_header(config: Config(msg)) -> Element(msg) {
  section_header.view(icons.Cards, i18n.t(config.locale, i18n_text.MemberCards))
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
// Card Show Component Integration
// =============================================================================

/// Render Card Show when a card is open.
/// Made public for use in client_view.gleam (Story 5.3: Pool/Kanban Card Show)
pub fn view_card_show(config: Config(msg)) -> Element(msg) {
  show_entry.view(show_entry.Config(
    model: config.show_model,
    card: config.show_card,
    cards: config.cards,
    tasks: config.show_tasks,
    locale: config.locale,
    current_user_id: config.current_user_id,
    can_manage_notes: config.can_manage_notes,
    can_manage_structure: config.can_manage_structure,
    can_execute_work: config.can_execute_work,
    on_card_show_msg: config.on_card_show_msg,
  ))
}
