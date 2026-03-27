import domain/api_error.{type ApiError}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/remote.{type Remote, Failed, Loaded}
import domain/task.{type Task, claimed_by}
import domain/task_status.{Available, Claimed, Completed, Ongoing, Taken}
import domain/task_type.{type TaskType}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, h4, p, section, span, text}
import lustre/element/keyed

import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/features/work_filters
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/utils/card_queries

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    tasks: Remote(List(Task)),
    task_types: Remote(List(TaskType)),
    capabilities: Remote(List(Capability)),
    cards: List(Card),
    org_users: List(OrgUser),
    capability_scope: CapabilityScope,
    my_capability_ids: List(Int),
    type_filter: Option(Int),
    search_query: String,
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
  )
}

type CapabilityRow {
  CapabilityRow(
    id: String,
    name: String,
    pending: List(Task),
    claimed: List(Task),
    ongoing: List(Task),
    is_unassigned: Bool,
  )
}

type ViewState {
  LoadingState
  ErrorState(message: String)
  EmptyState
  NoResultsState
  ReadyState(rows: List(CapabilityRow))
}

type LaneState {
  PendingLane
  ClaimedLane
  OngoingLane
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let content = case derive_state(config) {
    LoadingState ->
      view_state_message(
        "capability-board-state capability-board-loading",
        i18n.t(config.locale, i18n_text.CapabilityBoardLoading),
      )
    ErrorState(message) ->
      view_state_message(
        "capability-board-state capability-board-error",
        message,
      )
    EmptyState ->
      view_state_message(
        "capability-board-state capability-board-empty",
        i18n.t(config.locale, i18n_text.CapabilityBoardEmpty),
      )
    NoResultsState ->
      view_state_message(
        "capability-board-state capability-board-no-results",
        i18n.t(config.locale, i18n_text.CapabilityBoardNoResults),
      )
    ReadyState(rows) -> view_rows(config, rows)
  }

  section(
    [
      attribute.class("capability-board"),
      attribute.attribute("data-testid", "capability-board"),
    ],
    [
      h3([attribute.class("capability-board-title")], [
        text(i18n.t(config.locale, i18n_text.CapabilitiesBoard)),
      ]),
      content,
    ],
  )
}

fn derive_state(config: Config(msg)) -> ViewState {
  case config.tasks, config.task_types, config.capabilities {
    Failed(err), _, _ -> ErrorState(capability_board_error(config.locale, err))
    _, Failed(err), _ -> ErrorState(capability_board_error(config.locale, err))
    _, _, Failed(err) -> ErrorState(capability_board_error(config.locale, err))
    Loaded(tasks), Loaded(task_types), Loaded(capabilities) -> {
      let active_tasks = list.filter(tasks, is_active_task)

      case active_tasks {
        [] -> EmptyState
        _ -> {
          let filtered_tasks =
            active_tasks |> list.filter(matches_active_filters(_, config))

          case filtered_tasks {
            [] -> NoResultsState
            _ -> {
              let rows =
                build_rows(filtered_tasks, task_types, capabilities, config)
              case rows {
                [] -> NoResultsState
                _ -> ReadyState(rows)
              }
            }
          }
        }
      }
    }
    _, _, _ -> LoadingState
  }
}

fn capability_board_error(locale: Locale, err: ApiError) -> String {
  let base = i18n.t(locale, i18n_text.CapabilityBoardLoadError)
  case err.message {
    "" -> base
    message -> base <> ": " <> message
  }
}

fn is_active_task(task: Task) -> Bool {
  task.status != Completed
}

fn matches_active_filters(task: Task, config: Config(msg)) -> Bool {
  work_filters.matches(
    work_filters.Filters(
      type_filter: config.type_filter,
      capability_filter: None,
      search_query: config.search_query,
      capability_scope: config.capability_scope,
      my_capability_ids: config.my_capability_ids,
      task_types: case config.task_types {
        Loaded(task_types) -> task_types
        _ -> []
      },
    ),
    task,
  )
}

fn build_rows(
  tasks: List(Task),
  task_types: List(TaskType),
  capabilities: List(Capability),
  config: Config(msg),
) -> List(CapabilityRow) {
  let assigned_rows =
    capabilities
    |> list.filter_map(fn(capability) {
      let row_tasks =
        tasks
        |> list.filter(fn(task) {
          work_filters.task_capability_id(task, task_types)
          == Some(capability.id)
        })

      row_from_tasks(
        id: "capability-" <> int.to_string(capability.id),
        name: capability.name,
        tasks: row_tasks,
        is_unassigned: False,
      )
    })
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

  let unassigned_tasks =
    tasks
    |> list.filter(fn(task) {
      case work_filters.task_capability_id(task, task_types) {
        Some(capability_id) -> !has_capability(capabilities, capability_id)
        None -> True
      }
    })

  case
    row_from_tasks(
      id: "capability-unassigned",
      name: i18n.t(config.locale, i18n_text.NoCapability),
      tasks: unassigned_tasks,
      is_unassigned: True,
    )
  {
    Error(Nil) -> assigned_rows
    Ok(unassigned_row) -> list.append(assigned_rows, [unassigned_row])
  }
}

fn row_from_tasks(
  id id: String,
  name name: String,
  tasks tasks: List(Task),
  is_unassigned is_unassigned: Bool,
) -> Result(CapabilityRow, Nil) {
  let pending = filter_lane(tasks, PendingLane)
  let claimed = filter_lane(tasks, ClaimedLane)
  let ongoing = filter_lane(tasks, OngoingLane)

  case pending, claimed, ongoing {
    [], [], [] -> Error(Nil)
    _, _, _ ->
      Ok(CapabilityRow(
        id: id,
        name: name,
        pending: pending,
        claimed: claimed,
        ongoing: ongoing,
        is_unassigned: is_unassigned,
      ))
  }
}

fn filter_lane(tasks: List(Task), lane: LaneState) -> List(Task) {
  tasks
  |> list.filter(fn(task) { lane_matches(task, lane) })
  |> sort_tasks
}

fn lane_matches(task: Task, lane: LaneState) -> Bool {
  case lane, task.status {
    PendingLane, Available -> True
    ClaimedLane, Claimed(Taken) -> True
    OngoingLane, Claimed(Ongoing) -> True
    _, _ -> False
  }
}

fn has_capability(capabilities: List(Capability), capability_id: Int) -> Bool {
  list.any(capabilities, fn(capability) { capability.id == capability_id })
}

fn sort_tasks(tasks: List(Task)) -> List(Task) {
  list.sort(tasks, compare_tasks)
}

fn compare_tasks(a: Task, b: Task) -> order.Order {
  case string.compare(a.title, b.title) {
    order.Eq -> int.compare(a.id, b.id)
    other -> other
  }
}

fn view_rows(config: Config(msg), rows: List(CapabilityRow)) -> Element(msg) {
  keyed.div(
    [attribute.class("capability-board-rows")],
    list.map(rows, fn(row) { #(row.id, view_row(config, row)) }),
  )
}

fn view_row(config: Config(msg), row: CapabilityRow) -> Element(msg) {
  let heading_id = row.id <> "-heading"
  let row_class = case row.is_unassigned {
    True -> "capability-board-row capability-board-row-unassigned"
    False -> "capability-board-row"
  }

  section(
    [
      attribute.class(row_class),
      attribute.attribute("aria-labelledby", heading_id),
      attribute.attribute("data-testid", "capability-row"),
    ],
    [
      h4(
        [
          attribute.class("capability-board-row-title"),
          attribute.attribute("id", heading_id),
        ],
        [text(row.name)],
      ),
      div([attribute.class("capability-board-row-grid")], [
        view_lane_column(config, PendingLane, row.pending),
        view_lane_column(config, ClaimedLane, row.claimed),
        view_lane_column(config, OngoingLane, row.ongoing),
      ]),
    ],
  )
}

fn view_lane_column(
  config: Config(msg),
  lane: LaneState,
  tasks: List(Task),
) -> Element(msg) {
  let #(title, column_class, icon_name, state_name, empty_text) =
    lane_metadata(config.locale, lane)

  div(
    [
      attribute.class("kanban-column " <> column_class),
      attribute.attribute("data-testid", "capability-status-column"),
      attribute.attribute("data-column-state", state_name),
    ],
    [
      div([attribute.class("kanban-column-header")], [
        div([attribute.class("kanban-column-title")], [
          span(
            [
              attribute.class("kanban-column-icon"),
              attribute.attribute("aria-hidden", "true"),
            ],
            [icons.nav_icon(icon_name, icons.Small)],
          ),
          h4([], [text(title)]),
        ]),
        span([attribute.class("column-count")], [
          text(int.to_string(list.length(tasks))),
        ]),
      ]),
      case tasks {
        [] -> view_empty_column(empty_text)
        _ ->
          keyed.ul(
            [
              attribute.class(
                "kanban-column-content capability-board-column-content",
              ),
            ],
            list.map(tasks, fn(task) {
              #(int.to_string(task.id), view_task_item(config, task))
            }),
          )
      },
    ],
  )
}

fn lane_metadata(
  locale: Locale,
  lane: LaneState,
) -> #(String, String, icons.NavIcon, String, String) {
  case lane {
    PendingLane -> #(
      i18n.t(locale, i18n_text.CardStatePendiente),
      "pendiente",
      icons.Pause,
      "pending",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyPending),
    )
    ClaimedLane -> #(
      i18n.t(locale, i18n_text.TaskStateClaimed),
      "claimed",
      icons.Pause,
      "claimed",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyClaimed),
    )
    OngoingLane -> #(
      i18n.t(locale, i18n_text.NowWorking),
      "en-curso",
      icons.Play,
      "ongoing",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyOngoing),
    )
  }
}

fn view_empty_column(message: String) -> Element(msg) {
  div(
    [
      attribute.class("kanban-empty-column"),
      attribute.attribute("data-testid", "kanban-empty-column"),
    ],
    [span([attribute.class("empty-text")], [text(message)])],
  )
}

fn view_task_item(config: Config(msg), task: Task) -> Element(msg) {
  let status_display = case task.status {
    Claimed(_) -> {
      let claimed_label = case claimed_by(task) {
        Some(user_id) ->
          case list.find(config.org_users, fn(user) { user.id == user_id }) {
            Ok(user) -> user.email
            Error(_) -> i18n.t(config.locale, i18n_text.UnknownUser)
          }
        None -> i18n.t(config.locale, i18n_text.UnknownUser)
      }

      let status_icon = task_status_utils.claimed_icon(task.status)
      span([attribute.class("task-claimed-by")], [
        text(i18n.t(config.locale, i18n_text.ClaimedBy) <> " " <> claimed_label),
        span([attribute.class("task-claimed-icon")], [
          icons.nav_icon(status_icon, icons.XSmall),
        ]),
      ])
    }
    Available ->
      span([attribute.class("task-status-muted")], [
        text(task_status_utils.label(config.locale, task.status)),
      ])
    Completed -> task_item.empty_secondary()
  }

  let #(_card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info_from_cards(config.cards, task)
  let border_class = task_color.card_border_class(resolved_color)
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

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

  let secondary =
    div([attribute.class("task-item-meta")], [
      status_display,
      task_blocked_badge.view(config.locale, task, "task-blocked-inline"),
    ])

  task_item.view(
    task_item.Config(
      container_class: "task-item " <> border_class <> blocked_class,
      content_class: "task-item-content",
      on_click: Some(config.on_task_click(task.id)),
      icon: Some(task_type_icon.view(task.task_type.icon, 14, config.theme)),
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: secondary,
      actions: actions,
      reserve_actions_slot: True,
      action_slot_class: None,
      testid: Some("capability-task-item"),
    ),
    task_item.ListItem,
  )
}

fn view_state_message(class_name: String, message: String) -> Element(msg) {
  p([attribute.class(class_name)], [text(message)])
}
