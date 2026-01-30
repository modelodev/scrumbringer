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
import lustre/element/html.{button, div, input, label, span, text, ul}
import lustre/event

import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/task.{type Task}
import domain/task_status.{Available, Claimed, Completed, Ongoing, Taken}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/expand_toggle
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state
import scrumbringer_client/ui/task_type_icon

// =============================================================================
// Types
// =============================================================================

/// Configuration for the grouped list view
pub type GroupedListConfig(msg) {
  GroupedListConfig(
    locale: Locale,
    theme: Theme,
    tasks: List(Task),
    cards: List(Card),
    org_users: List(OrgUser),
    expanded_cards: Dict(Int, Bool),
    hide_completed: Bool,
    on_toggle_card: fn(Int) -> msg,
    on_toggle_hide_completed: msg,
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
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
  // Filter out completed tasks if hide_completed is true
  let filtered_tasks = case config.hide_completed {
    True -> list.filter(config.tasks, fn(t) { t.status != Completed })
    False -> config.tasks
  }

  let groups = group_tasks_by_card(filtered_tasks, config.cards)

  case groups {
    [] ->
      div([attribute.class("grouped-list-empty")], [
        text(i18n.t(config.locale, i18n_text.NoAvailableTasksRightNow)),
      ])
    _ ->
      div([attribute.class("grouped-list")], [
        // Task groups
        div(
          [attribute.class("grouped-list-content")],
          list.map(groups, fn(group) { view_card_group(config, group) }),
        ),
        // Hide completed checkbox (AC35)
        div([attribute.class("grouped-list-footer")], [
          label([attribute.class("checkbox-label")], [
            input([
              attribute.type_("checkbox"),
              attribute.checked(config.hide_completed),
              event.on_click(config.on_toggle_hide_completed),
            ]),
            text(i18n.t(config.locale, i18n_text.HideCompletedTasks)),
          ]),
        ]),
      ])
  }
}

// Justification: nested case improves clarity for branching logic.
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

  let card_border_class = case group.card {
    Some(c) -> task_color.card_border_class(c.color)
    None -> ""
  }

  let title_elements = case group.card {
    Some(c) ->
      card_title_meta.elements(
        span([attribute.class("card-title")], [text(title)]),
        c.color,
        None,
        c.has_new_notes,
        i18n.t(config.locale, i18n_text.NewNotesTooltip),
        card_title_meta.TitleNotesColor,
      )
    None -> [span([attribute.class("card-title")], [text(title)])]
  }

  let header_children =
    list.append(
      [expand_toggle.view(is_expanded)],
      list.append(title_elements, [
        // Progress bar (AC34)
        card_progress.view(group.completed, group.total, card_progress.Default),
      ]),
    )

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
        header_children,
      ),
      // Task list (collapsible)
      case is_expanded {
        True -> view_task_list(config, group.tasks, card_border_class)
        False -> element.none()
      },
    ],
  )
}

fn view_task_list(
  config: GroupedListConfig(msg),
  tasks: List(Task),
  card_border_class: String,
) -> Element(msg) {
  ul(
    [attribute.class("card-task-list")],
    list.map(tasks, fn(task) { view_task_item(config, task, card_border_class) }),
  )
}

fn view_task_item(
  config: GroupedListConfig(msg),
  task: Task,
  card_border_class: String,
) -> Element(msg) {
  // AC7: Show claimed by user when task is Claimed (based on status, not claimed_by)
  let status_display = case task.status {
    Claimed(_) -> {
      // Task is claimed - try to find who claimed it
      let claimed_email = case task.claimed_by {
        Some(user_id) ->
          list.find(config.org_users, fn(u) { u.id == user_id })
          |> option.from_result
          |> option.map(fn(u) { u.email })
          |> option.unwrap(i18n.t(config.locale, i18n_text.UnknownUser))
        None -> i18n.t(config.locale, i18n_text.UnknownUser)
      }
      let status_icon = case task.status {
        Claimed(Ongoing) -> icons.Play
        Claimed(Taken) -> icons.Pause
        _ -> icons.Pause
      }
      span([attribute.class("task-claimed-by")], [
        text(i18n.t(config.locale, i18n_text.ClaimedBy) <> " " <> claimed_email),
        span([attribute.class("task-claimed-icon")], [
          icons.nav_icon(status_icon, icons.XSmall),
        ]),
      ])
    }
    Available ->
      span([attribute.class("task-status-muted")], [
        text(task_state.label(config.locale, task.status)),
      ])
    Completed ->
      // Completed - show status label
      span([attribute.class("task-status")], [
        text(task_state.label(config.locale, task.status)),
      ])
    // Available tasks: no label needed (claim icon is sufficient indicator)
  }

  let type_icon = task.task_type.icon

  let actions = case task.status {
    Available ->
      task_item.single_action(task_actions.claim_icon(
        i18n.t(config.locale, i18n_text.ClaimThisTask),
        config.on_task_claim(task.id, task.version),
        action_buttons.SizeXs,
        False,
        "btn-claim",
        None,
        Some("task-claim-btn"),
      ))
    _ -> task_item.no_actions()
  }

  task_item.view(
    task_item.Config(
      container_class: "task-item " <> card_border_class,
      content_class: "task-item-content",
      on_click: Some(config.on_task_click(task.id)),
      icon: Some(task_type_icon.view(type_icon, 14, config.theme)),
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: status_display,
      actions: actions,
      testid: Some("task-card"),
    ),
    task_item.ListItem,
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn group_tasks_by_card(tasks: List(Task), cards: List(Card)) -> List(CardGroup) {
  // Create a dict of card_id -> card
  let card_map =
    list.fold(cards, dict.new(), fn(acc, card) {
      dict.insert(acc, card.id, card)
    })

  // Group tasks by card_id, consolidating tasks with invalid/missing cards to key 0
  // AC24: All tasks without a valid card should be in ONE "Sin ficha" section
  let grouped =
    list.fold(tasks, dict.new(), fn(acc, task) {
      // Use card_id if it exists AND is valid (exists in card_map), otherwise 0
      let key = case task.card_id {
        Some(cid) ->
          case dict.has_key(card_map, cid) {
            True -> cid
            False -> 0
            // Invalid card_id -> consolidate to "Sin ficha"
          }
        None -> 0
      }
      let existing =
        dict.get(acc, key) |> option.from_result |> option.unwrap([])
      dict.insert(acc, key, [task, ..existing])
    })

  // Convert to CardGroup list
  dict.to_list(grouped)
  |> list.map(fn(pair) {
    let #(card_id, card_tasks) = pair
    let card = dict.get(card_map, card_id) |> option.from_result
    let completed = list.count(card_tasks, fn(t) { t.status == Completed })
    let total = list.length(card_tasks)
    CardGroup(
      card: card,
      tasks: list.reverse(card_tasks),
      completed: completed,
      total: total,
    )
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

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}

import gleam/order
