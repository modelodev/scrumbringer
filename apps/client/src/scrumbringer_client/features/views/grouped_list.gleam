//// GroupedList - Tasks grouped by card with collapsible sections
////
//// Mission: Display tasks organized by their parent card, with each card
//// as a collapsible section showing progress and contained tasks.
////
//// Responsibilities:
//// - Group tasks by card
//// - Render collapsible card sections
//// - Show progress per card (completed/total)
//// - Handle ungrouped tasks (tasks without a card)
////
//// Non-responsibilities:
//// - Task CRUD operations (handled by parent)
//// - Card state management (handled by parent)

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, li, span, text, ul}
import lustre/event

import domain/card.{type Card}
import domain/task.{type Task}
import domain/task_status.{Available, Claimed, Completed, Ongoing, Taken}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Types
// =============================================================================

/// Configuration for the grouped list view
pub type GroupedListConfig(msg) {
  GroupedListConfig(
    locale: Locale,
    tasks: List(Task),
    cards: List(Card),
    expanded_cards: Dict(Int, Bool),
    on_toggle_card: fn(Int) -> msg,
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int) -> msg,
  )
}

/// Internal type for grouped data
type CardGroup {
  CardGroup(card: Option(Card), tasks: List(Task), completed: Int, total: Int)
}

// =============================================================================
// View
// =============================================================================

/// Renders tasks grouped by card
pub fn view(config: GroupedListConfig(msg)) -> Element(msg) {
  let groups = group_tasks_by_card(config.tasks, config.cards)

  case groups {
    [] ->
      div([attribute.class("grouped-list-empty")], [
        text(i18n.t(config.locale, i18n_text.NoAvailableTasksRightNow)),
      ])
    _ ->
      div(
        [attribute.class("grouped-list")],
        list.map(groups, fn(group) { view_card_group(config, group) }),
      )
  }
}

fn view_card_group(
  config: GroupedListConfig(msg),
  group: CardGroup,
) -> Element(msg) {
  let card_id = case group.card {
    Some(c) -> c.id
    None -> 0
  }

  let is_expanded =
    dict.get(config.expanded_cards, card_id)
    |> option.from_result
    |> option.unwrap(True)

  let title = case group.card {
    Some(c) -> c.title
    None -> i18n.t(config.locale, i18n_text.UngroupedTasks)
  }

  let progress_text =
    int.to_string(group.completed) <> "/" <> int.to_string(group.total)

  div(
    [
      attribute.class("card-group"),
      attribute.attribute("data-card-id", int.to_string(card_id)),
    ],
    [
      // Card header (clickable to expand/collapse)
      button(
        [
          attribute.class("card-group-header"),
          attribute.attribute("aria-expanded", bool_to_string(is_expanded)),
          event.on_click(config.on_toggle_card(card_id)),
        ],
        [
          span([attribute.class("expand-icon")], [
            text(case is_expanded {
              True -> "▼"
              False -> "▶"
            }),
          ]),
          span([attribute.class("card-title")], [text(title)]),
          span([attribute.class("card-progress")], [text(progress_text)]),
          // Color indicator if card has color
          case group.card {
            Some(c) ->
              case c.color {
                Some(color) ->
                  span(
                    [
                      attribute.class("card-color-dot"),
                      attribute.style("background-color", color),
                    ],
                    [],
                  )
                None -> element.none()
              }
            None -> element.none()
          },
        ],
      ),
      // Task list (collapsible)
      case is_expanded {
        True -> view_task_list(config, group.tasks)
        False -> element.none()
      },
    ],
  )
}

fn view_task_list(
  config: GroupedListConfig(msg),
  tasks: List(Task),
) -> Element(msg) {
  ul(
    [attribute.class("card-task-list")],
    list.map(tasks, fn(task) { view_task_item(config, task) }),
  )
}

fn view_task_item(config: GroupedListConfig(msg), task: Task) -> Element(msg) {
  let status_class = case task.status {
    Available -> "status-available"
    Claimed(Taken) -> "status-taken"
    Claimed(Ongoing) -> "status-ongoing"
    Completed -> "status-completed"
  }

  li(
    [
      attribute.class("task-item " <> status_class),
      attribute.attribute("data-testid", "task-card"),
    ],
    [
      button(
        [
          attribute.class("task-item-content"),
          event.on_click(config.on_task_click(task.id)),
        ],
        [
          span([attribute.class("task-title")], [text(task.title)]),
          span([attribute.class("task-status")], [
            text(task_status_label(config.locale, task.status)),
          ]),
        ],
      ),
      // Claim button for available tasks
      case task.status {
        task_status.Available ->
          button(
            [
              attribute.class("btn-xs btn-claim"),
              attribute.attribute("data-testid", "task-claim-btn"),
              event.on_click(config.on_task_claim(task.id)),
            ],
            [text(i18n.t(config.locale, i18n_text.Claim))],
          )
        _ -> element.none()
      },
    ],
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn group_tasks_by_card(tasks: List(Task), cards: List(Card)) -> List(CardGroup) {
  // Create a dict of card_id -> card
  let card_map =
    list.fold(cards, dict.new(), fn(acc, card) { dict.insert(acc, card.id, card) })

  // Group tasks by card_id
  let grouped =
    list.fold(tasks, dict.new(), fn(acc, task) {
      let key = option.unwrap(task.card_id, 0)
      let existing = dict.get(acc, key) |> option.from_result |> option.unwrap([])
      dict.insert(acc, key, [task, ..existing])
    })

  // Convert to CardGroup list
  dict.to_list(grouped)
  |> list.map(fn(pair) {
    let #(card_id, card_tasks) = pair
    let card = dict.get(card_map, card_id) |> option.from_result
    let completed =
      list.count(card_tasks, fn(t) { t.status == Completed })
    let total = list.length(card_tasks)
    CardGroup(card: card, tasks: list.reverse(card_tasks), completed: completed, total: total)
  })
  |> list.sort(fn(a, b) {
    // Sort: cards with Some first, then by card id
    case a.card, b.card {
      Some(ca), Some(cb) -> int.compare(ca.id, cb.id)
      Some(_), None -> order.Lt
      None, Some(_) -> order.Gt
      None, None -> order.Eq
    }
  })
}

fn task_status_label(locale: Locale, status: task_status.TaskStatus) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskStateAvailable)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskStateClaimed)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.NowWorking)
    Completed -> i18n.t(locale, i18n_text.TaskStateCompleted)
  }
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

import gleam/order
