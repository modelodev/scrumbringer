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
//// - Render card detail modal component when card is selected
////
//// ## Relations
////
//// - **client_view.gleam**: Imports and renders this component
//// - **client_state.gleam**: Provides Model, Msg types
//// - **api/cards.gleam**: Handles card data fetching
//// - **components/card_detail_modal.gleam**: Card detail component

import gleam/dynamic/decode
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card.{type Card}
import scrumbringer_client/client_state.{type Model, type Msg, pool_msg}
import scrumbringer_client/features/cards/detail_modal_entry
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/state/normalized_store
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/section_header
import scrumbringer_client/ui/task_color
import scrumbringer_client/utils/card_queries

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
    // Render card detail modal when a card is open
    view_card_detail_modal(model),
  ])
}

fn view_fichas_header(model: Model) -> Element(Msg) {
  section_header.view(
    icons.Cards,
    helpers_i18n.i18n_t(model, i18n_text.MemberFichas),
  )
}

// Justification: nested case improves clarity for branching logic.
fn view_fichas_content(model: Model) -> Element(Msg) {
  let cards = card_queries.get_project_cards(model)
  let pending = normalized_store.pending(model.member.pool.member_cards_store)

  case list.is_empty(cards) {
    True ->
      case pending > 0 {
        True ->
          loading.loading(helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis))
        False -> view_empty_state(model)
      }
    False -> view_cards_list(model, cards)
  }
}

fn view_empty_state(model: Model) -> Element(Msg) {
  empty_state.new(
    icons.Clipboard,
    helpers_i18n.i18n_t(model, i18n_text.MemberFichasEmpty),
    helpers_i18n.i18n_t(model, i18n_text.MemberFichasEmptyHint),
  )
  |> empty_state.view
}

fn view_cards_list(model: Model, cards: List(Card)) -> Element(Msg) {
  div(
    [attribute.class("fichas-list")],
    list.map(cards, fn(c) { view_card_item(model, c) }),
  )
}

fn view_card_item(model: Model, card: Card) -> Element(Msg) {
  let border_class = task_color.card_border_class(card.color)
  let state_label = card_state.label(model.ui.locale, card.state)

  let header_title_elements =
    card_title_meta.elements(
      span([attribute.class("ficha-title")], [text(card.title)]),
      option.None,
      option.None,
      card.has_new_notes,
      helpers_i18n.i18n_t(model, i18n_text.NewNotesTooltip),
      card_title_meta.TitleNotesColor,
    )

  let header_children =
    list.append(header_title_elements, [
      card_state_badge.view(card.state, state_label, card_state_badge.Ficha),
    ])

  div(
    [
      attribute.class("ficha-card " <> border_class),
      event.on_click(pool_msg(pool_messages.OpenCardDetail(card.id))),
      attribute.attribute("role", "button"),
      attribute.attribute("tabindex", "0"),
    ],
    [
      div([attribute.class("ficha-header")], header_children),
      case card.description {
        "" -> element.none()
        desc -> div([attribute.class("ficha-description")], [text(desc)])
      },
      div([attribute.class("ficha-meta")], [
        card_progress.view(
          card.completed_count,
          card.task_count,
          card_progress.Compact,
        ),
      ]),
    ],
  )
}

// =============================================================================
// Card Detail Modal Component Integration
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Render the card-detail-modal custom element when a card is open.
/// Made public for use in client_view.gleam (Story 5.3: Pool/Kanban card detail)
pub fn view_card_detail_modal(model: Model) -> Element(Msg) {
  let is_org_admin = case model.core.user {
    option.Some(user) -> permissions.is_org_admin(user.org_role)
    option.None -> False
  }
  let is_manager = case helpers_selection.selected_project(model) {
    option.Some(project) -> permissions.is_project_manager(project)
    option.None -> False
  }

  detail_modal_entry.view(
    model,
    detail_modal_entry.Config(
      can_manage_notes: is_org_admin || is_manager,
      on_create_task: decode_create_task_event(),
      on_close: decode_close_detail_event(),
    ),
  )
}

/// Decoder for create-task-requested event.
/// Opens the main task creation dialog with card_id pre-filled.
fn decode_create_task_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("card_id", decode.int, decode.success),
    fn(card_id) {
      decode.success(
        pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(card_id)),
      )
    },
  )
}

/// Decoder for close-requested event.
fn decode_close_detail_event() -> decode.Decoder(Msg) {
  event_decoders.message(pool_msg(pool_messages.CloseCardDetail))
}
