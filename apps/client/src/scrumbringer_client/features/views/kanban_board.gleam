//// KanbanBoard - Cards displayed in kanban columns
////
//// Mission: Display cards organized in three columns by state
//// (Draft, En Curso, Closed) with progress indicators.
////
//// Responsibilities:
//// - Organize cards by state into columns
//// - Display card progress (closed/total tasks)
//// - Show context menu for PM/Admin (edit, delete)
//// - Handle card selection
////
//// Non-responsibilities:
//// - Card CRUD operations (handled by parent)
//// - Task Show surfaces (handled by other views)

import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html.{div, h4, span, text}
import lustre/element/keyed

import domain/card.{type Card, Active, Closed, Draft}
import domain/org.{type OrgUser}
import domain/task as domain_task
import domain/task/state as task_execution_state
import domain/task_type.{type TaskType}
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/features/work_filters
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_with_tasks_surface
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone
import scrumbringer_client/utils/card_queries

// =============================================================================
// Types
// =============================================================================

pub type KanbanPurpose {
  ExecutionKanban
  PlanKanban
}

/// Configuration for the kanban board
pub type KanbanConfig(msg) {
  KanbanConfig(
    locale: Locale,
    theme: Theme,
    surface_title: String,
    surface_purpose: String,
    purpose: KanbanPurpose,
    cards: List(Card),
    tasks: List(domain_task.Task),
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
    // Story 4.8 UX: domain_task.Task interaction handlers for consistency with Lista view
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    // Story 4.12 AC8-AC9: Create task in card
    on_create_task_in_card: fn(Int) -> msg,
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: option.Option(Int),
    selected_card_id: option.Option(Int),
    card_query: String,
    show_closed: option.Option(Bool),
    plan_mode: member_pool.PlanMode,
    on_plan_mode_change: fn(String) -> msg,
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
    on_closed_toggled: fn(Bool) -> msg,
  )
}

/// Card with computed progress and task list
type CardWithProgress {
  CardWithProgress(
    card: Card,
    closed: Int,
    total: Int,
    tasks: List(domain_task.Task),
  )
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

type KanbanColumn {
  PendingColumn
  InProgressColumn
  ClosedColumn
}

// =============================================================================
// View
// =============================================================================

/// Renders the kanban board with 3 columns
pub fn view(config: KanbanConfig(msg)) -> element.Element(msg) {
  case config.purpose, config.scope_kind, config.selected_card_id {
    PlanKanban, member_pool.PlanScopeCard, option.None ->
      view_empty_card_scope_surface(config)
    _, _, _ -> view_scoped_board(config)
  }
}

fn view_scoped_board(config: KanbanConfig(msg)) -> element.Element(msg) {
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

  let scoped_cards = cards_in_scope(config)
  let include_closed = show_closed(config, scoped_cards, filtered_tasks)
  let cards_with_progress =
    compute_progress(scoped_cards, filtered_tasks, config.cards)

  let visible_cards =
    cards_with_progress
    |> list.filter(fn(cwp) {
      card_visible_for_purpose(config, cwp.card, include_closed)
    })

  let pendiente =
    list.filter(visible_cards, fn(cwp) {
      cwp.card.state != Closed && !has_work_in_progress(cwp.tasks)
    })
  let en_curso =
    list.filter(visible_cards, fn(cwp) {
      cwp.card.state != Closed && has_work_in_progress(cwp.tasks)
    })
  let cerrada = list.filter(visible_cards, fn(cwp) { cwp.card.state == Closed })

  let board =
    div([attribute.class("kanban-board")], [
      view_column(
        config,
        pending_column_title(config),
        "pendiente",
        PendingColumn,
        pendiente,
      ),
      view_column(
        config,
        i18n.t(config.locale, i18n_text.CardPhaseActive),
        "en-curso",
        InProgressColumn,
        en_curso,
      ),
      case include_closed {
        True ->
          view_column(
            config,
            i18n.t(config.locale, i18n_text.CardPhaseClosed),
            "cerrada",
            ClosedColumn,
            cerrada,
          )
        False -> element.none()
      },
    ])

  work_surface.new_surface(view_surface_header(
    config,
    board_summary(visible_cards),
  ))
  |> work_surface.with_filters(view_scope_bar(config, include_closed))
  |> work_surface.with_content(board)
  |> work_surface.surface_with_class("kanban-view")
  |> work_surface.surface
}

fn view_empty_card_scope_surface(
  config: KanbanConfig(msg),
) -> element.Element(msg) {
  work_surface.new_surface(view_surface_header(
    config,
    BoardSummary(cards: 0, available: 0, claimed: 0, ongoing: 0, blocked: 0),
  ))
  |> work_surface.with_filters(view_scope_bar(config, False))
  |> work_surface.with_content(
    div(
      [
        attribute.class("plan-structure-empty"),
        attribute.attribute("data-testid", "kanban-empty-card-scope"),
      ],
      [
        h4([], [text(i18n.t(config.locale, i18n_text.PlanScopeSelectCard))]),
        span([], [text(i18n.t(config.locale, i18n_text.PlanEmptyCardScopeBody))]),
      ],
    ),
  )
  |> work_surface.surface_with_class("kanban-view")
  |> work_surface.surface
}

fn view_surface_header(
  config: KanbanConfig(msg),
  summary: BoardSummary,
) -> element.Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: config.surface_title,
    purpose: config.surface_purpose,
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryCards),
        int.to_string(summary.cards),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(summary.available),
        tone.Available,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsClaimed),
        int.to_string(summary.claimed),
        tone.Claimed,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryOngoing),
        int.to_string(summary.ongoing),
        tone.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(summary.blocked),
        tone.Blocked,
      ),
    ],
    actions: [],
    extra_class: option.Some("kanban-surface-header"),
    testid: option.Some("kanban-surface-header"),
  ))
}

fn view_scope_bar(
  config: KanbanConfig(msg),
  include_closed: Bool,
) -> element.Element(msg) {
  scope_bar.view(scope_bar.Config(
    locale: config.locale,
    cards: config.cards,
    depth_names: config.depth_names,
    scope_kind: config.scope_kind,
    selected_depth: config.selected_depth,
    selected_card_id: config.selected_card_id,
    card_query: config.card_query,
    show_closed: include_closed,
    id_prefix: "kanban-plan",
    mode_controls: [],
    refinement_controls: [],
    show_closed_control: True,
    on_scope_kind_change: config.on_scope_kind_change,
    on_scope_depth_change: config.on_scope_depth_change,
    on_scope_card_change: config.on_scope_card_change,
    on_scope_card_search_change: config.on_scope_card_search_change,
    on_closed_toggled: config.on_closed_toggled,
  ))
}

fn pending_column_title(config: KanbanConfig(msg)) -> String {
  case config.purpose {
    PlanKanban -> i18n.t(config.locale, i18n_text.KanbanColumnPending)
    ExecutionKanban -> i18n.t(config.locale, i18n_text.CardPhaseDraft)
  }
}

fn view_column(
  config: KanbanConfig(msg),
  title: String,
  column_class: String,
  column_state: KanbanColumn,
  cards: List(CardWithProgress),
) -> element.Element(msg) {
  let header_icon = case column_state {
    PendingColumn -> icons.Pause
    InProgressColumn -> icons.Play
    ClosedColumn -> icons.CheckCircle
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
  column_state: KanbanColumn,
) -> element.Element(msg) {
  // AC12: Different empty state text per column
  let empty_text = case column_state {
    PendingColumn -> i18n.t(config.locale, i18n_text.KanbanEmptyDraft)
    InProgressColumn -> i18n.t(config.locale, i18n_text.KanbanEmptyActive)
    ClosedColumn -> i18n.t(config.locale, i18n_text.KanbanEmptyClosed)
  }

  // AC12: Different icon per column state
  let empty_icon = case column_state {
    PendingColumn -> icons.InboxEmpty
    InProgressColumn -> icons.Pause
    ClosedColumn -> icons.CheckCircle
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

fn view_card(
  config: KanbanConfig(msg),
  cwp: CardWithProgress,
) -> element.Element(msg) {
  let health = task_health(cwp.tasks)
  let preview_tasks = case config.purpose {
    ExecutionKanban -> next_relevant_tasks(cwp.tasks)
    PlanKanban -> []
  }
  let task_testid = case config.purpose {
    ExecutionKanban -> option.Some("kanban-task-item")
    PlanKanban -> option.None
  }

  card_with_tasks_surface.view(card_with_tasks_surface.Config(
    locale: config.locale,
    theme: config.theme,
    card: cwp.card,
    tasks: preview_tasks,
    org_users: config.org_users,
    preview_limit: 3,
    progress_closed: cwp.closed,
    progress_total: cwp.total,
    project_today: client_ffi.date_today(),
    description: option.Some(cwp.card.description),
    status_items: view_health_items(config, health),
    on_card_click: option.Some(config.on_card_click(cwp.card.id)),
    on_task_click: config.on_task_click,
    on_task_claim: task_claim_handler(config),
    header_actions: header_actions(config, cwp.card),
    footer_actions: [],
    root_attributes: [
      attribute.attribute("data-testid", "card-item"),
      attribute.attribute("data-card-id", int.to_string(cwp.card.id)),
    ],
    task_item_testid: task_testid,
  ))
}

fn task_claim_handler(config: KanbanConfig(msg)) -> fn(Int, Int) -> msg {
  case config.purpose {
    ExecutionKanban -> config.on_task_claim
    PlanKanban -> fn(_task_id, _version) { config.on_card_click(0) }
  }
}

fn view_health_items(
  config: KanbanConfig(msg),
  health: TaskHealth,
) -> List(element.Element(msg)) {
  let core_items = [
    view_health_chip(
      i18n.t(config.locale, i18n_text.MetricsAvailable),
      health.available,
      tone.Available,
    ),
    view_health_chip(
      i18n.t(config.locale, i18n_text.MetricsClaimed),
      health.claimed,
      tone.Claimed,
    ),
    view_health_chip(
      i18n.t(config.locale, i18n_text.KanbanSummaryOngoing),
      health.ongoing,
      tone.Ongoing,
    ),
  ]

  case health.blocked > 0 {
    True ->
      list.append(core_items, [
        view_health_chip(
          i18n.t(config.locale, i18n_text.Blocked),
          health.blocked,
          tone.Blocked,
        ),
      ])
    False -> core_items
  }
}

fn view_health_chip(
  label: String,
  value: Int,
  tone_value: tone.Tone,
) -> element.Element(msg) {
  signal_chip.metric_int(label, value, tone_value)
  |> signal_chip.with_class("kanban-health-chip")
  |> signal_chip.with_parts("kanban-health-value", "kanban-health-label")
  |> signal_chip.with_testid("kanban-health-chip")
  |> signal_chip.with_title(label <> ": " <> int.to_string(value))
  |> signal_chip.view
}

fn header_actions(
  config: KanbanConfig(msg),
  card: Card,
) -> List(element.Element(msg)) {
  let create_task_actions = case can_create_task_in_card(config, card) {
    True -> [
      action_buttons.create_task_in_card_button(
        i18n.t(config.locale, i18n_text.NewTaskInCard(card.title)),
        config.on_create_task_in_card(card.id),
      ),
    ]
    False -> []
  }

  case config.purpose, config.is_pm_or_admin {
    PlanKanban, _ -> create_task_actions
    ExecutionKanban, True ->
      list.append(create_task_actions, [
        action_buttons.edit_button_with_size(
          i18n.t(config.locale, i18n_text.EditCardTooltip),
          config.on_card_edit(card.id),
          action_buttons.SizeXs,
        ),
        delete_card_action(config, card),
      ])
    ExecutionKanban, False -> create_task_actions
  }
}

fn can_create_task_in_card(config: KanbanConfig(msg), card: Card) -> Bool {
  card_queries.direct_child_cards(card.id, config.cards) == []
}

fn delete_card_action(
  config: KanbanConfig(msg),
  card: Card,
) -> element.Element(msg) {
  action_buttons.delete_button_with_availability_and_testid(
    i18n.t(config.locale, i18n_text.DeleteCardTooltip),
    config.on_card_delete(card.id),
    card_delete_availability(config, card),
    "kanban-card-delete-action",
  )
}

fn card_delete_availability(
  config: KanbanConfig(msg),
  card: Card,
) -> action_buttons.Availability {
  case card.task_count > 0 {
    True ->
      action_buttons.Blocked(i18n.t(config.locale, i18n_text.CardDeleteBlocked))
    False -> action_buttons.Available
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn compute_progress(
  cards: List(Card),
  tasks: List(domain_task.Task),
  all_cards: List(Card),
) -> List(CardWithProgress) {
  list.map(cards, fn(card) {
    let card_tasks =
      list.filter(tasks, fn(task) {
        card_queries.task_in_card_subtree(task, card.id, all_cards)
      })
    let closed = list.count(card_tasks, is_closed_task)
    let total = list.length(card_tasks)
    CardWithProgress(
      card: card,
      closed: closed,
      total: total,
      tasks: card_tasks,
    )
  })
}

fn cards_in_scope(config: KanbanConfig(msg)) -> List(Card) {
  card_queries.cards_for_scope(
    config.cards,
    config.scope_kind,
    config.selected_depth,
    config.selected_card_id,
  )
}

fn card_visible_for_purpose(
  config: KanbanConfig(msg),
  card: Card,
  include_closed: Bool,
) -> Bool {
  case config.purpose, card.state {
    PlanKanban, Active -> True
    PlanKanban, Closed -> include_closed
    PlanKanban, Draft -> False
    ExecutionKanban, Closed -> include_closed
    ExecutionKanban, _ -> True
  }
}

fn show_closed(
  config: KanbanConfig(msg),
  scoped_cards: List(Card),
  tasks: List(domain_task.Task),
) -> Bool {
  case config.show_closed {
    option.Some(value) -> value
    option.None ->
      card_queries.closed_default_for_scope(
        scoped_cards,
        tasks,
        config.scope_kind,
        config.selected_card_id,
      )
  }
}

fn has_work_in_progress(tasks: List(domain_task.Task)) -> Bool {
  list.any(tasks, fn(task) {
    case task.state {
      task_execution_state.Claimed(..) -> True
      _ -> False
    }
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

fn task_health(tasks: List(domain_task.Task)) -> TaskHealth {
  TaskHealth(
    available: list.count(tasks, is_available_task),
    claimed: list.count(tasks, is_taken_task),
    ongoing: list.count(tasks, is_ongoing_task),
    blocked: list.count(tasks, fn(task) { task.blocked_count > 0 }),
  )
}

fn is_available_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Available -> True
    _ -> False
  }
}

fn is_taken_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Taken, ..) -> True
    _ -> False
  }
}

fn is_ongoing_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Claimed(mode: task_execution_state.Ongoing, ..) -> True
    _ -> False
  }
}

fn is_closed_task(task: domain_task.Task) -> Bool {
  case task.state {
    task_execution_state.Closed(..) -> True
    _ -> False
  }
}

fn next_relevant_tasks(tasks: List(domain_task.Task)) -> List(domain_task.Task) {
  let active =
    tasks
    |> list.filter(fn(task) { !is_closed_task(task) })
    |> list.sort(by: compare_relevant_tasks)

  case active {
    [] -> list.sort(tasks, by: compare_relevant_tasks)
    _ -> active
  }
}

fn compare_relevant_tasks(
  a: domain_task.Task,
  b: domain_task.Task,
) -> order.Order {
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

fn task_rank(task: domain_task.Task) -> Int {
  case task.blocked_count > 0, task.state {
    True, _ -> 0
    False, task_execution_state.Available -> 1
    False, task_execution_state.Claimed(mode: task_execution_state.Ongoing, ..) ->
      2
    False, task_execution_state.Claimed(mode: task_execution_state.Taken, ..) ->
      3
    False, task_execution_state.Closed(..) -> 4
  }
}
