//// KanbanBoard - Cards displayed in kanban columns
////
//// Mission: Display cards organized in three columns by state
//// (Pendiente, En Curso, Cerrada) with progress indicators.
////
//// Responsibilities:
//// - Organize cards by state into columns
//// - Display card progress (completed/total tasks)
//// - Show context menu for PM/Admin (edit, delete)
//// - Handle card selection
////
//// Non-responsibilities:
//// - Card CRUD operations (handled by parent)
//// - Task details (handled by other views)

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, span, text}
import lustre/event

import domain/card.{type Card, Cerrada, EnCurso, Pendiente}
import domain/task.{type Task}
import domain/task_status
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/utils/text as text_utils

// =============================================================================
// Types
// =============================================================================

/// Configuration for the kanban board
pub type KanbanConfig(msg) {
  KanbanConfig(
    locale: Locale,
    cards: List(Card),
    tasks: List(Task),
    is_pm_or_admin: Bool,
    on_card_click: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
    on_new_card: msg,
  )
}

/// Card with computed progress and task list
type CardWithProgress {
  CardWithProgress(card: Card, completed: Int, total: Int, tasks: List(Task))
}

// =============================================================================
// View
// =============================================================================

/// Renders the kanban board with 3 columns
pub fn view(config: KanbanConfig(msg)) -> Element(msg) {
  let cards_with_progress = compute_progress(config.cards, config.tasks)

  // AC42: Filter out empty cards (cards with 0 tasks)
  // Empty cards are only visible in /config/cards management view
  let non_empty_cards =
    list.filter(cards_with_progress, fn(cwp) { cwp.total > 0 })

  // Group by state
  let pendiente =
    list.filter(non_empty_cards, fn(cwp) {
      cwp.card.state == Pendiente
    })
  let en_curso =
    list.filter(non_empty_cards, fn(cwp) { cwp.card.state == EnCurso })
  let cerrada =
    list.filter(non_empty_cards, fn(cwp) { cwp.card.state == Cerrada })

  div(
    [attribute.class("kanban-board")],
    [
      view_column(
        config,
        i18n.t(config.locale, i18n_text.CardStatePendiente),
        "pendiente",
        pendiente,
      ),
      view_column(
        config,
        i18n.t(config.locale, i18n_text.CardStateEnCurso),
        "en-curso",
        en_curso,
      ),
      view_column(
        config,
        i18n.t(config.locale, i18n_text.CardStateCerrada),
        "cerrada",
        cerrada,
      ),
    ],
  )
}

fn view_column(
  config: KanbanConfig(msg),
  title: String,
  column_class: String,
  cards: List(CardWithProgress),
) -> Element(msg) {
  div(
    [attribute.class("kanban-column " <> column_class)],
    [
      div(
        [attribute.class("kanban-column-header")],
        [
          h4([], [text(title)]),
          span([attribute.class("column-count")], [
            text(int.to_string(list.length(cards))),
          ]),
        ],
      ),
      div(
        [attribute.class("kanban-column-content")],
        case cards {
          [] -> [view_empty_column(config)]
          _ -> list.map(cards, fn(cwp) { view_card(config, cwp) })
        },
      ),
    ],
  )
}

/// Renders an empty state for kanban columns (AC27)
fn view_empty_column(config: KanbanConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("kanban-empty-column"),
      attribute.attribute("data-testid", "kanban-empty-column"),
    ],
    [
      span([attribute.class("empty-icon")], [icons.nav_icon(icons.ClipboardDoc, icons.Medium)]),
      span([attribute.class("empty-text")], [
        text(i18n.t(config.locale, i18n_text.KanbanEmptyColumn)),
      ]),
    ],
  )
}

fn view_card(config: KanbanConfig(msg), cwp: CardWithProgress) -> Element(msg) {
  let progress_text =
    int.to_string(cwp.completed) <> "/" <> int.to_string(cwp.total)

  let progress_percent = case cwp.total {
    0 -> 0
    _ -> cwp.completed * 100 / cwp.total
  }

  div(
    [
      attribute.class("kanban-card"),
      attribute.attribute("data-testid", "card-item"),
      attribute.attribute("data-card-id", int.to_string(cwp.card.id)),
    ],
    [
      // Card header with title and context menu
      div(
        [attribute.class("kanban-card-header")],
        [
          button(
            [
              attribute.class("kanban-card-title"),
              attribute.attribute("data-testid", "card-title"),
              event.on_click(config.on_card_click(cwp.card.id)),
            ],
            [
              // Color dot
              case cwp.card.color {
                Some(color) ->
                  span(
                    [
                      attribute.class("card-color-dot"),
                      attribute.style("background-color", color),
                    ],
                    [],
                  )
                None -> element.none()
              },
              text(cwp.card.title),
            ],
          ),
          // Context menu for PM/Admin
          case config.is_pm_or_admin {
            True -> view_context_menu(config, cwp.card.id)
            False -> element.none()
          },
        ],
      ),
      // Description (truncated)
      case cwp.card.description {
        "" -> element.none()
        desc ->
          div([attribute.class("kanban-card-desc")], [
            text(text_utils.truncate(desc, 80)),
          ])
      },
      // Progress bar
      div(
        [attribute.class("kanban-card-progress")],
        [
          div(
            [attribute.class("progress-bar")],
            [
              div(
                [
                  attribute.class("progress-fill"),
                  attribute.style("width", int.to_string(progress_percent) <> "%"),
                ],
                [],
              ),
            ],
          ),
          span([attribute.class("progress-text")], [text(progress_text)]),
        ],
      ),
      // Task list (Story 4.5 AC29)
      view_task_list(cwp.tasks),
    ],
  )
}

/// Renders a compact list of tasks within the card (AC29)
fn view_task_list(tasks: List(Task)) -> Element(msg) {
  case list.length(tasks) {
    0 -> element.none()
    _ ->
      div(
        [
          attribute.class("kanban-card-tasks"),
          attribute.attribute("data-testid", "card-tasks"),
        ],
        list.map(list.take(tasks, 5), fn(t) {
          let is_completed = t.status == task_status.Completed
          let status_class = case is_completed {
            True -> " completed"
            False -> ""
          }
          let icon = case is_completed {
            True -> "✓"
            False -> "•"
          }
          div(
            [attribute.class("kanban-task-item" <> status_class)],
            [
              span([attribute.class("task-status-icon")], [text(icon)]),
              span([attribute.class("task-title")], [text(text_utils.truncate(t.title, 30))]),
            ],
          )
        }),
      )
  }
}

fn view_context_menu(config: KanbanConfig(msg), card_id: Int) -> Element(msg) {
  div(
    [
      attribute.class("kanban-card-menu"),
      attribute.attribute("data-testid", "card-context-menu"),
    ],
    [
      button(
        [
          attribute.class("btn-icon btn-xs"),
          attribute.attribute("data-testid", "card-edit-btn"),
          attribute.attribute("aria-label", "Edit card"),
          event.on_click(config.on_card_edit(card_id)),
        ],
        [icons.nav_icon(icons.Pencil, icons.Small)],
      ),
      button(
        [
          attribute.class("btn-icon btn-xs btn-danger"),
          attribute.attribute("data-testid", "card-delete-btn"),
          attribute.attribute("aria-label", "Delete card"),
          event.on_click(config.on_card_delete(card_id)),
        ],
        [icons.nav_icon(icons.Trash, icons.Small)],
      ),
    ],
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn compute_progress(
  cards: List(Card),
  tasks: List(Task),
) -> List(CardWithProgress) {
  list.map(cards, fn(card) {
    let card_tasks =
      list.filter(tasks, fn(t) { t.card_id == Some(card.id) })
    let completed =
      list.count(card_tasks, fn(t) { t.status == task_status.Completed })
    let total = list.length(card_tasks)
    CardWithProgress(
      card: card,
      completed: completed,
      total: total,
      tasks: card_tasks,
    )
  })
}
