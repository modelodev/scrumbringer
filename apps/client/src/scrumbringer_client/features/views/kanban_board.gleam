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
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, span, text}
import lustre/event

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/org.{type OrgUser}
import domain/task.{type Task}
import domain/task_status.{Available, Claimed, Completed}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/utils/text as text_utils

// =============================================================================
// Types
// =============================================================================

/// Configuration for the kanban board
pub type KanbanConfig(msg) {
  KanbanConfig(
    locale: Locale,
    theme: Theme,
    cards: List(Card),
    tasks: List(Task),
    // Story 4.8 UX: Added org_users for task claimed_by display
    org_users: List(OrgUser),
    is_pm_or_admin: Bool,
    on_card_click: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
    on_new_card: msg,
    // Story 4.8 UX: Task interaction handlers for consistency with Lista view
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    // Story 4.12 AC8-AC9: Create task in card
    on_create_task_in_card: fn(Int) -> msg,
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
    list.filter(non_empty_cards, fn(cwp) { cwp.card.state == Pendiente })
  let en_curso =
    list.filter(non_empty_cards, fn(cwp) { cwp.card.state == EnCurso })
  let cerrada =
    list.filter(non_empty_cards, fn(cwp) { cwp.card.state == Cerrada })

  div([attribute.class("kanban-board")], [
    view_column(
      config,
      i18n.t(config.locale, i18n_text.CardStatePendiente),
      "pendiente",
      Pendiente,
      pendiente,
    ),
    view_column(
      config,
      i18n.t(config.locale, i18n_text.CardStateEnCurso),
      "en-curso",
      EnCurso,
      en_curso,
    ),
    view_column(
      config,
      i18n.t(config.locale, i18n_text.CardStateCerrada),
      "cerrada",
      Cerrada,
      cerrada,
    ),
  ])
}

fn view_column(
  config: KanbanConfig(msg),
  title: String,
  column_class: String,
  column_state: CardState,
  cards: List(CardWithProgress),
) -> Element(msg) {
  div([attribute.class("kanban-column " <> column_class)], [
    div([attribute.class("kanban-column-header")], [
      h4([], [text(title)]),
      span([attribute.class("column-count")], [
        text(int.to_string(list.length(cards))),
      ]),
    ]),
    div([attribute.class("kanban-column-content")], case cards {
      [] -> [view_empty_column(config, column_state)]
      _ -> list.map(cards, fn(cwp) { view_card(config, cwp) })
    }),
  ])
}

/// Renders an empty state for kanban columns (AC12: different per column)
fn view_empty_column(
  config: KanbanConfig(msg),
  column_state: CardState,
) -> Element(msg) {
  // AC12: Different empty state text per column
  let empty_text = case column_state {
    Pendiente -> i18n.t(config.locale, i18n_text.KanbanEmptyPendiente)
    EnCurso -> i18n.t(config.locale, i18n_text.KanbanEmptyEnCurso)
    Cerrada -> i18n.t(config.locale, i18n_text.KanbanEmptyCerrada)
  }

  // AC12: Different icon per column state
  let empty_icon = case column_state {
    Pendiente -> icons.InboxEmpty
    EnCurso -> icons.Pause
    Cerrada -> icons.CheckCircle
  }

  div(
    [
      attribute.class("kanban-empty-column"),
      attribute.attribute("data-testid", "kanban-empty-column"),
    ],
    [
      span([attribute.class("empty-icon")], [
        icons.nav_icon(empty_icon, icons.Medium),
      ]),
      span([attribute.class("empty-text")], [text(empty_text)]),
    ],
  )
}

fn view_card(config: KanbanConfig(msg), cwp: CardWithProgress) -> Element(msg) {
  div(
    [
      attribute.class("kanban-card"),
      attribute.attribute("data-testid", "card-item"),
      attribute.attribute("data-card-id", int.to_string(cwp.card.id)),
    ],
    [
      // Card header with title and context menu
      div([attribute.class("kanban-card-header")], [
        button(
          [
            attribute.class("kanban-card-title"),
            attribute.attribute("data-testid", "card-title"),
            event.on_click(config.on_card_click(cwp.card.id)),
          ],
          card_title_meta.elements(
            text(cwp.card.title),
            cwp.card.color,
            None,
            cwp.card.has_new_notes,
            i18n.t(config.locale, i18n_text.NewNotesTooltip),
            card_title_meta.ColorTitleNotes,
          ),
        ),
        // Context menu for PM/Admin
        case config.is_pm_or_admin {
          True -> view_context_menu(config, cwp.card.id)
          False -> element.none()
        },
      ]),
      // Description (truncated)
      case cwp.card.description {
        "" -> element.none()
        desc ->
          div([attribute.class("kanban-card-desc")], [
            text(text_utils.truncate(desc, 80)),
          ])
      },
      // Progress bar
      div([attribute.class("kanban-card-progress")], [
        card_progress.view(cwp.completed, cwp.total, card_progress.Default),
      ]),
      // Task list (Story 4.5 AC29, Story 4.8 UX: improved styling)
      view_task_list(config, cwp.tasks),
      // Story 4.12 AC8-AC9: [+] Nueva tarea button
      div([attribute.class("kanban-card-footer")], [
        action_buttons.create_task_in_card_button(
          i18n.t(config.locale, i18n_text.NewTaskInCard(cwp.card.title)),
          config.on_create_task_in_card(cwp.card.id),
        ),
      ]),
    ],
  )
}

/// Renders a compact list of tasks within the card (AC29, Story 4.8 UX)
/// Now uses consistent styling with Vista Lista: status icons, claimed info, claim button
fn view_task_list(config: KanbanConfig(msg), tasks: List(Task)) -> Element(msg) {
  case list.length(tasks) {
    0 -> element.none()
    _ ->
      div(
        [
          attribute.class("kanban-card-tasks"),
          attribute.attribute("data-testid", "card-tasks"),
        ],
        list.map(list.take(tasks, 5), fn(t) { view_task_item(config, t) }),
      )
  }
}

/// Renders a single task item with status icon, title, and actions
/// Story 4.8 UX: Consistent with grouped_list task rendering
fn view_task_item(config: KanbanConfig(msg), task: Task) -> Element(msg) {
  // Secondary info: claimed by for taken/ongoing tasks
  let secondary_info = case task.status {
    Claimed(_) -> {
      let claimed_name = case task.claimed_by {
        Some(user_id) ->
          list.find(config.org_users, fn(u) { u.id == user_id })
          |> option.from_result
          |> option.map(fn(u) { truncate_email(u.email) })
          |> option.unwrap("?")
        None -> "?"
      }
      span([attribute.class("task-claimed-by")], [text(claimed_name)])
    }
    _ -> element.none()
  }

  let type_icon = task.task_type.icon
  let border_class = task_color.card_border_class(task.card_color)

  let actions = case task.status {
    Available ->
      task_item.single_action(task_actions.claim_icon_with_class(
        i18n.t(config.locale, i18n_text.Claim),
        config.on_task_claim(task.id, task.version),
        icons.XSmall,
        False,
        "btn-claim-mini",
        None,
        None,
      ))
    _ -> task_item.no_actions()
  }

  task_item.view(
    task_item.Config(
      container_class: "kanban-task-item " <> border_class,
      content_class: "kanban-task-content",
      on_click: Some(config.on_task_click(task.id)),
      icon: Some(task_type_icon.view(type_icon, 14, config.theme)),
      icon_class: None,
      title: text_utils.truncate(task.title, 25),
      title_class: None,
      secondary: secondary_info,
      actions: actions,
      testid: Some("kanban-task-item"),
    ),
    task_item.Div,
  )
}

/// Truncates email to show only the local part (before @)
fn truncate_email(email: String) -> String {
  case string.split(email, "@") {
    [local, ..] -> text_utils.truncate(local, 10)
    _ -> text_utils.truncate(email, 10)
  }
}

fn view_context_menu(config: KanbanConfig(msg), card_id: Int) -> Element(msg) {
  // Story 4.8 UX: Only edit button in Kanban view (delete via card detail)
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
    let card_tasks = list.filter(tasks, fn(t) { t.card_id == Some(card.id) })
    let completed = list.count(card_tasks, fn(t) { t.status == Completed })
    let total = list.length(card_tasks)
    CardWithProgress(
      card: card,
      completed: completed,
      total: total,
      tasks: card_tasks,
    )
  })
}
