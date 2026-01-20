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

import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/task as domain_task
import domain/task_status as domain_task_status
import domain/task_type as domain_task_type
import scrumbringer_client/client_state.{
  type Model, type Msg, CloseCardDetail, Loaded, Loading, OpenCardDetail,
}
import scrumbringer_client/i18n/locale
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
    // Render card detail modal when a card is open
    view_card_detail_modal(model),
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
      event.on_click(OpenCardDetail(card.id)),
      attribute.attribute("role", "button"),
      attribute.attribute("tabindex", "0"),
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

// =============================================================================
// Card Detail Modal Component Integration
// =============================================================================

/// Render the card-detail-modal custom element when a card is open.
fn view_card_detail_modal(model: Model) -> Element(Msg) {
  case model.card_detail_open {
    option.None -> element.none()
    option.Some(card_id) -> {
      // Find the card data
      let card_opt = find_card(model, card_id)

      case card_opt {
        option.None -> element.none()
        option.Some(card) -> {
          // Get task types for this project
          let task_types =
            dict.get(model.member_task_types_by_project, card.project_id)
            |> option.from_result
            |> option.unwrap([])

          // Get tasks for this card (filter from member_tasks if available)
          let tasks = get_card_tasks(model, card_id)

          element.element(
            "card-detail-modal",
            [
              // Attributes (strings)
              attribute.attribute("card-id", int.to_string(card_id)),
              attribute.attribute("locale", locale.serialize(model.locale)),
              attribute.attribute("project-id", int.to_string(card.project_id)),
              // Properties (JSON)
              attribute.property("card", card_to_json(card)),
              attribute.property("task-types", task_types_to_json(task_types)),
              attribute.property("tasks", tasks_to_json(tasks)),
              // Event listeners - use decoder for custom events
              event.on("task-created", decode_close_detail_event()),
              event.on("close-requested", decode_close_detail_event()),
            ],
            [],
          )
        }
      }
    }
  }
}

/// Decoder for custom events that just returns CloseCardDetail.
/// When task-created fires, we close the modal and let normal refresh handle data.
fn decode_close_detail_event() -> decode.Decoder(Msg) {
  decode.success(CloseCardDetail)
}

fn find_card(model: Model, card_id: Int) -> option.Option(Card) {
  case model.cards {
    Loaded(cards) ->
      list.find(cards, fn(c) { c.id == card_id })
      |> option.from_result
    _ -> option.None
  }
}

fn get_card_tasks(model: Model, card_id: Int) -> List(domain_task.Task) {
  // Filter tasks from member_tasks that belong to this card
  case model.member_tasks {
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

fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.int(card.id)),
    #("project_id", json.int(card.project_id)),
    #("title", json.string(card.title)),
    #("description", json.string(card.description)),
    #("color", case card.color {
      option.Some(c) -> json.string(c)
      option.None -> json.null()
    }),
    #("state", json.string(card_state_to_string(card.state))),
    #("task_count", json.int(card.task_count)),
    #("completed_count", json.int(card.completed_count)),
    #("created_by", json.int(card.created_by)),
    #("created_at", json.string(card.created_at)),
  ])
}

fn card_state_to_string(state: CardState) -> String {
  case state {
    Pendiente -> "pendiente"
    EnCurso -> "en_curso"
    Cerrada -> "cerrada"
  }
}

fn task_types_to_json(
  task_types: List(domain_task_type.TaskType),
) -> json.Json {
  json.array(task_types, fn(tt) {
    json.object([
      #("id", json.int(tt.id)),
      #("name", json.string(tt.name)),
      #("icon", json.string(tt.icon)),
      #("capability_id", case tt.capability_id {
        option.Some(id) -> json.int(id)
        option.None -> json.null()
      }),
    ])
  })
}

fn tasks_to_json(tasks: List(domain_task.Task)) -> json.Json {
  json.array(tasks, task_to_json)
}

fn task_to_json(task: domain_task.Task) -> json.Json {
  json.object([
    #("id", json.int(task.id)),
    #("project_id", json.int(task.project_id)),
    #("type_id", json.int(task.type_id)),
    #("task_type", json.object([
      #("id", json.int(task.task_type.id)),
      #("name", json.string(task.task_type.name)),
      #("icon", json.string(task.task_type.icon)),
    ])),
    #("ongoing_by", case task.ongoing_by {
      option.Some(ob) -> json.object([#("user_id", json.int(ob.user_id))])
      option.None -> json.null()
    }),
    #("title", json.string(task.title)),
    #("description", case task.description {
      option.Some(d) -> json.string(d)
      option.None -> json.null()
    }),
    #("priority", json.int(task.priority)),
    #("status", json.string(domain_task_status.task_status_to_string(task.status))),
    #("work_state", json.string(work_state_to_string(task.work_state))),
    #("created_by", json.int(task.created_by)),
    #("claimed_by", case task.claimed_by {
      option.Some(id) -> json.int(id)
      option.None -> json.null()
    }),
    #("claimed_at", case task.claimed_at {
      option.Some(at) -> json.string(at)
      option.None -> json.null()
    }),
    #("completed_at", case task.completed_at {
      option.Some(at) -> json.string(at)
      option.None -> json.null()
    }),
    #("created_at", json.string(task.created_at)),
    #("version", json.int(task.version)),
    #("card_id", case task.card_id {
      option.Some(id) -> json.int(id)
      option.None -> json.null()
    }),
    #("card_title", case task.card_title {
      option.Some(t) -> json.string(t)
      option.None -> json.null()
    }),
    #("card_color", case task.card_color {
      option.Some(c) -> json.string(c)
      option.None -> json.null()
    }),
  ])
}

fn work_state_to_string(state: domain_task_status.WorkState) -> String {
  case state {
    domain_task_status.WorkAvailable -> "available"
    domain_task_status.WorkClaimed -> "claimed"
    domain_task_status.WorkOngoing -> "ongoing"
    domain_task_status.WorkCompleted -> "completed"
  }
}
