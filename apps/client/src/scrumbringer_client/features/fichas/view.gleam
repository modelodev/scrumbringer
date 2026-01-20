//// Member Fichas (Cards) view component.
////
//// ## Mission
////
//// Render the fichas (cards) list for members to view and interact with.
////
//// ## Responsibilities
////
//// - Display cards list with state badges and color indicators
//// - Handle card selection for detail modal
//// - Show empty state when no cards
////
//// ## Relations
////
//// - **client_view.gleam**: Imports and renders this component
//// - **client_state.gleam**: Provides Model, Msg types
//// - **api/cards.gleam**: Handles card data fetching

import gleam/int
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import scrumbringer_client/client_state.{type Model, type Msg, Loaded, Loading}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/color_picker
import scrumbringer_client/update_helpers

// =============================================================================
// View Functions
// =============================================================================

/// Main entry point for the fichas view.
pub fn view_fichas(model: Model) -> Element(Msg) {
  div([attribute.class("content")], [
    div([attribute.class("section")], [
      view_fichas_header(model),
      view_fichas_content(model),
    ]),
  ])
}

fn view_fichas_header(model: Model) -> Element(Msg) {
  div(
    [
      attribute.attribute("style", "margin-bottom: 16px;"),
    ],
    [
      span(
        [
          attribute.attribute(
            "style",
            "font-size: 14px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.03em; color: var(--sb-muted);",
          ),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.MemberFichas))],
      ),
    ],
  )
}

fn view_fichas_content(model: Model) -> Element(Msg) {
  // Use the existing model.cards (admin cards data)
  // In future, we may have member-specific card filtering
  case model.cards {
    Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Loaded(cards) ->
      case list.is_empty(cards) {
        True -> view_empty_state(model)
        False -> view_cards_list(model, cards)
      }

    _ -> view_empty_state(model)
  }
}

fn view_empty_state(model: Model) -> Element(Msg) {
  div([attribute.class("empty-state")], [
    div(
      [attribute.class("empty-state-icon")],
      [text("📋")],
    ),
    div([attribute.class("empty-state-title")], [
      text(update_helpers.i18n_t(model, i18n_text.MemberFichasEmpty)),
    ]),
    div([attribute.class("empty-state-description")], [
      text(update_helpers.i18n_t(model, i18n_text.MemberFichasEmptyHint)),
    ]),
  ])
}

fn view_cards_list(model: Model, cards: List(Card)) -> Element(Msg) {
  div(
    [attribute.class("fichas-list")],
    list.map(cards, fn(c) { view_card_item(model, c) }),
  )
}

fn view_card_item(model: Model, card: Card) -> Element(Msg) {
  let color_opt = color_from_string(card.color)
  let border_class = color_picker.border_class(color_opt)
  let state_class = state_to_class(card.state)
  let state_label = state_to_label(model, card.state)

  let progress_text =
    int.to_string(card.completed_count)
    <> "/"
    <> int.to_string(card.task_count)

  div(
    [
      attribute.class("ficha-card " <> border_class),
      // In full implementation: event.on_click(SelectCard(card.id))
    ],
    [
      div([attribute.class("ficha-header")], [
        span([attribute.class("ficha-title")], [text(card.title)]),
        span([attribute.class("ficha-state-badge " <> state_class)], [
          text(state_label),
        ]),
      ]),
      case card.description {
        "" -> element.none()
        desc ->
          div([attribute.class("ficha-description")], [text(desc)])
      },
      div([attribute.class("ficha-meta")], [
        span([], [text(progress_text)]),
      ]),
    ],
  )
}

fn state_to_class(state: CardState) -> String {
  case state {
    Pendiente -> "ficha-state-pendiente"
    EnCurso -> "ficha-state-en_curso"
    Cerrada -> "ficha-state-cerrada"
  }
}

fn state_to_label(model: Model, state: CardState) -> String {
  case state {
    Pendiente -> update_helpers.i18n_t(model, i18n_text.CardStatePendiente)
    EnCurso -> update_helpers.i18n_t(model, i18n_text.CardStateEnCurso)
    Cerrada -> update_helpers.i18n_t(model, i18n_text.CardStateCerrada)
  }
}

/// Convert string color from Card to color_picker.CardColor option.
fn color_from_string(
  color: option.Option(String),
) -> option.Option(color_picker.CardColor) {
  case color {
    option.None -> option.None
    option.Some(c) -> color_picker.string_to_color(c)
  }
}
