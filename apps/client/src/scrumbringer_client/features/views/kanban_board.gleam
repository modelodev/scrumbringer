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
import gleam/option
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h4, span, text}
import lustre/element/keyed

import domain/card.{type Card, type CardState, Cerrada, EnCurso, Pendiente}
import domain/org.{type OrgUser}
import domain/task.{type Task}
import domain/task_status.{Available, Claimed, Completed, Ongoing, Taken}
import domain/task_type.{type TaskType}
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/work_filters
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_with_tasks_surface
import scrumbringer_client/ui/icons

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
    task_types: List(TaskType),
    type_filter: option.Option(Int),
    capability_filter: option.Option(Int),
    search_query: String,
    capability_scope: CapabilityScope,
    my_capability_ids: List(Int),
    // Story 4.8 UX: Added org_users for task claimed_by display
    org_users: List(OrgUser),
    is_pm_or_admin: Bool,
    on_card_click: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
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

type TaskHealth {
  TaskHealth(available: Int, claimed: Int, ongoing: Int, blocked: Int)
}

type BoardSummary {
  BoardSummary(
    cards: Int,
    available: Int,
    claimed: Int,
    ongoing: Int,
    blocked: Int,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the kanban board with 3 columns
pub fn view(config: KanbanConfig(msg)) -> Element(msg) {
  let filtered_tasks =
    list.filter(config.tasks, fn(task) {
      work_filters.matches(
        work_filters.Filters(
          type_filter: config.type_filter,
          capability_filter: config.capability_filter,
          search_query: config.search_query,
          capability_scope: config.capability_scope,
          my_capability_ids: config.my_capability_ids,
          task_types: config.task_types,
        ),
        task,
      )
    })

  let cards_with_progress = compute_progress(config.cards, filtered_tasks)

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

  div([attribute.class("kanban-view")], [
    view_surface_header(config, board_summary(non_empty_cards)),
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
    ]),
  ])
}

fn view_surface_header(
  config: KanbanConfig(msg),
  summary: BoardSummary,
) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(config.locale, i18n_text.Kanban),
    purpose: i18n.t(config.locale, i18n_text.KanbanSurfacePurpose),
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryCards),
        int.to_string(summary.cards),
        work_surface.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(summary.available),
        work_surface.Available,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsClaimed),
        int.to_string(summary.claimed),
        work_surface.Claimed,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryOngoing),
        int.to_string(summary.ongoing),
        work_surface.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(summary.blocked),
        work_surface.Blocked,
      ),
    ],
    actions: [],
    extra_class: option.Some("kanban-surface-header"),
    testid: option.Some("kanban-surface-header"),
  ))
}

fn view_column(
  config: KanbanConfig(msg),
  title: String,
  column_class: String,
  column_state: CardState,
  cards: List(CardWithProgress),
) -> Element(msg) {
  let header_icon = case column_state {
    Pendiente -> icons.Pause
    EnCurso -> icons.Play
    Cerrada -> icons.CheckCircle
  }

  div([attribute.class("kanban-column " <> column_class)], [
    div([attribute.class("kanban-column-header")], [
      div([attribute.class("kanban-column-title")], [
        span(
          [
            attribute.class("kanban-column-icon"),
            attribute.attribute("aria-hidden", "true"),
          ],
          [icons.nav_icon(header_icon, icons.Small)],
        ),
        h4([], [text(title)]),
      ]),
      span([attribute.class("column-count")], [
        text(int.to_string(list.length(cards))),
      ]),
    ]),
    keyed.div([attribute.class("kanban-column-content")], case cards {
      [] -> [#("empty", view_empty_column(config, column_state))]
      _ ->
        list.map(cards, fn(cwp) {
          #(int.to_string(cwp.card.id), view_card(config, cwp))
        })
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
  let health = task_health(cwp.tasks)

  card_with_tasks_surface.view(card_with_tasks_surface.Config(
    locale: config.locale,
    theme: config.theme,
    card: cwp.card,
    tasks: next_relevant_tasks(cwp.tasks),
    org_users: config.org_users,
    preview_limit: 3,
    progress_completed: cwp.completed,
    progress_total: cwp.total,
    description: option.Some(cwp.card.description),
    status_items: view_health_items(config, health),
    on_card_click: option.Some(config.on_card_click(cwp.card.id)),
    on_task_click: config.on_task_click,
    on_task_claim: config.on_task_claim,
    header_actions: header_actions(config, cwp.card.id, cwp.card.title),
    footer_actions: [],
    root_attributes: [
      attribute.attribute("data-testid", "card-item"),
      attribute.attribute("data-card-id", int.to_string(cwp.card.id)),
    ],
    task_item_testid: option.Some("kanban-task-item"),
  ))
}

fn view_health_items(
  config: KanbanConfig(msg),
  health: TaskHealth,
) -> List(Element(msg)) {
  let core_items = [
    view_health_chip(
      i18n.t(config.locale, i18n_text.MetricsAvailable),
      health.available,
      "available",
    ),
    view_health_chip(
      i18n.t(config.locale, i18n_text.MetricsClaimed),
      health.claimed,
      "claimed",
    ),
    view_health_chip(
      i18n.t(config.locale, i18n_text.KanbanSummaryOngoing),
      health.ongoing,
      "ongoing",
    ),
  ]

  case health.blocked > 0 {
    True ->
      list.append(core_items, [
        view_health_chip(
          i18n.t(config.locale, i18n_text.Blocked),
          health.blocked,
          "blocked",
        ),
      ])
    False -> core_items
  }
}

fn view_health_chip(label: String, value: Int, tone: String) -> Element(msg) {
  span(
    [
      attribute.class("kanban-health-chip " <> tone),
      attribute.attribute("data-testid", "kanban-health-chip"),
      attribute.attribute("title", label <> ": " <> int.to_string(value)),
    ],
    [
      span([attribute.class("kanban-health-value")], [
        text(int.to_string(value)),
      ]),
      span([attribute.class("kanban-health-label")], [text(label)]),
    ],
  )
}

fn header_actions(
  config: KanbanConfig(msg),
  card_id: Int,
  card_title: String,
) -> List(Element(msg)) {
  let create_task_action =
    action_buttons.create_task_in_card_button(
      i18n.t(config.locale, i18n_text.NewTaskInCard(card_title)),
      config.on_create_task_in_card(card_id),
    )

  case config.is_pm_or_admin {
    True -> [
      create_task_action,
      action_buttons.edit_button_with_size(
        i18n.t(config.locale, i18n_text.EditCardTooltip),
        config.on_card_edit(card_id),
        action_buttons.SizeXs,
      ),
      action_buttons.delete_button_with_size(
        i18n.t(config.locale, i18n_text.DeleteCardTooltip),
        config.on_card_delete(card_id),
        action_buttons.SizeXs,
      ),
    ]
    False -> [create_task_action]
  }
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
      list.filter(tasks, fn(t) { t.card_id == option.Some(card.id) })
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

fn board_summary(cards: List(CardWithProgress)) -> BoardSummary {
  let tasks = list.flat_map(cards, fn(cwp) { cwp.tasks })
  let health = task_health(tasks)

  BoardSummary(
    cards: list.length(cards),
    available: health.available,
    claimed: health.claimed,
    ongoing: health.ongoing,
    blocked: health.blocked,
  )
}

fn task_health(tasks: List(Task)) -> TaskHealth {
  TaskHealth(
    available: list.count(tasks, fn(task) { task.status == Available }),
    claimed: list.count(tasks, fn(task) { task.status == Claimed(Taken) }),
    ongoing: list.count(tasks, fn(task) { task.status == Claimed(Ongoing) }),
    blocked: list.count(tasks, fn(task) { task.blocked_count > 0 }),
  )
}

fn next_relevant_tasks(tasks: List(Task)) -> List(Task) {
  let active =
    tasks
    |> list.filter(fn(task) { task.status != Completed })
    |> list.sort(by: compare_relevant_tasks)

  case active {
    [] -> list.sort(tasks, by: compare_relevant_tasks)
    _ -> active
  }
}

fn compare_relevant_tasks(a: Task, b: Task) -> order.Order {
  case int.compare(task_rank(a), task_rank(b)) {
    order.Eq ->
      case int.compare(b.priority, a.priority) {
        order.Eq ->
          case string.compare(a.created_at, b.created_at) {
            order.Eq -> int.compare(a.id, b.id)
            other -> other
          }
        other -> other
      }
    other -> other
  }
}

fn task_rank(task: Task) -> Int {
  case task.blocked_count > 0, task.status {
    True, _ -> 0
    False, Available -> 1
    False, Claimed(Ongoing) -> 2
    False, Claimed(Taken) -> 3
    False, Completed -> 4
  }
}
