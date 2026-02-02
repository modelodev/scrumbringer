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
import domain/task as domain_task
import scrumbringer_client/client_state.{
  type Model, type Msg, CloseCardDetail, Loaded,
  MemberCreateDialogOpenedWithCard, OpenCardDetail, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/state/normalized_store
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/card_detail_host
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/card_queries

// =============================================================================
// View Functions
// =============================================================================

/// Main entry point for the fichas view.
pub fn view_fichas(model: Model) -> Element(Msg) {
  div([attribute.class("content")], [
    div([attrs.section()], [
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
    update_helpers.i18n_t(model, i18n_text.MemberFichas),
  )
}

// Justification: nested case improves clarity for branching logic.
fn view_fichas_content(model: Model) -> Element(Msg) {
  let cards = card_queries.get_project_cards(model)
  let pending = normalized_store.pending(model.member.member_cards_store)

  case list.is_empty(cards) {
    True ->
      case pending > 0 {
        True ->
          loading.loading(update_helpers.i18n_t(
            model,
            i18n_text.LoadingEllipsis,
          ))
        False -> view_empty_state(model)
      }
    False -> view_cards_list(model, cards)
  }
}

fn view_empty_state(model: Model) -> Element(Msg) {
  empty_state.new(
    icons.Clipboard,
    update_helpers.i18n_t(model, i18n_text.MemberFichasEmpty),
    update_helpers.i18n_t(model, i18n_text.MemberFichasEmptyHint),
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
  let color_opt = color_from_string(card.color)
  let border_class = color_picker.border_class(color_opt)
  let state_label = card_state.label(model.ui.locale, card.state)

  let header_title_elements =
    card_title_meta.elements(
      span([attribute.class("ficha-title")], [text(card.title)]),
      option.None,
      option.None,
      card.has_new_notes,
      update_helpers.i18n_t(model, i18n_text.NewNotesTooltip),
      card_title_meta.TitleNotesColor,
    )

  let header_children =
    list.append(header_title_elements, [
      card_state_badge.view(card.state, state_label, card_state_badge.Ficha),
    ])

  div(
    [
      attribute.class("ficha-card " <> border_class),
      event.on_click(pool_msg(OpenCardDetail(card.id))),
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

/// Convert string color from Card to color_picker.CardColor option.
fn color_from_string(
  color: option.Option(String),
) -> option.Option(color_picker.CardColor) {
  case color {
    option.None -> option.None
    option.Some(c) -> color_picker.string_to_color(c)
  }
}

// =============================================================================
// Card Detail Modal Component Integration
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Render the card-detail-modal custom element when a card is open.
/// Made public for use in client_view.gleam (Story 5.3: Pool/Kanban card detail)
pub fn view_card_detail_modal(model: Model) -> Element(Msg) {
  case model.member.card_detail_open {
    option.None -> element.none()
    option.Some(card_id) -> {
      // Find the card data
      let card_opt = card_queries.find_card(model, card_id)

      case card_opt {
        option.None -> element.none()
        option.Some(card) -> {
          // Get tasks for this card (filter from member_tasks if available)
          let tasks = get_card_tasks(model, card_id)
          let current_user_id = case model.core.user {
            option.Some(user) -> user.id
            option.None -> 0
          }
          let is_org_admin = case model.core.user {
            option.Some(user) -> permissions.is_org_admin(user.org_role)
            option.None -> False
          }
          let is_manager = case update_helpers.selected_project(model) {
            option.Some(project) -> permissions.is_project_manager(project)
            option.None -> False
          }
          let can_manage_notes = is_org_admin || is_manager

          card_detail_host.view(card_detail_host.Config(
            card: card,
            tasks: tasks,
            locale: model.ui.locale,
            current_user_id: current_user_id,
            can_manage_notes: can_manage_notes,
            on_create_task: decode_create_task_event(card_id),
            on_close: decode_close_detail_event(),
          ))
        }
      }
    }
  }
}

/// Decoder for create-task-requested event.
/// Opens the main task creation dialog with card_id pre-filled.
fn decode_create_task_event(card_id: Int) -> decode.Decoder(Msg) {
  decode.success(pool_msg(MemberCreateDialogOpenedWithCard(card_id)))
}

/// Decoder for close-requested event.
fn decode_close_detail_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(CloseCardDetail))
}

// Justification: nested case improves clarity for branching logic.
fn get_card_tasks(model: Model, card_id: Int) -> List(domain_task.Task) {
  // Filter tasks from member_tasks that belong to this card
  case model.member.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(t) {
        case t.card_id {
          option.Some(cid) -> cid == card_id
          option.None -> False
        }
      })
    _ -> []
  }
}
