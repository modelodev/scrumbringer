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
import lustre/element/html.{div, h4, section, span, text}
import lustre/element/keyed

import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/client_ffi
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/work_filters
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/ui/tone
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
    blocked_count: Int,
    oldest_age_days: Int,
    pressure_score: Int,
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
  let state = derive_state(config)
  let content = case state {
    LoadingState ->
      empty_state.notice_with_class(
        "clock",
        i18n.t(config.locale, i18n_text.CapabilityBoardLoading),
        empty_state.Loading,
        "capability-board-state capability-board-loading",
      )
    ErrorState(message) ->
      empty_state.notice_with_class(
        "exclamation-triangle",
        message,
        empty_state.Error,
        "capability-board-state capability-board-error",
      )
    EmptyState ->
      empty_state.notice_with_class(
        "clipboard-document-list",
        i18n.t(config.locale, i18n_text.CapabilityBoardEmpty),
        empty_state.HealthyEmpty,
        "capability-board-state capability-board-empty",
      )
    NoResultsState ->
      empty_state.notice_with_class(
        "magnifying-glass",
        i18n.t(config.locale, i18n_text.CapabilityBoardNoResults),
        empty_state.NoResults,
        "capability-board-state capability-board-no-results",
      )
    ReadyState(rows) -> view_rows(config, rows)
  }

  section(
    [
      attribute.class("capability-board"),
      attribute.attribute("data-testid", "capability-board"),
    ],
    [
      view_surface_header(config, state),
      content,
    ],
  )
}

fn view_surface_header(config: Config(msg), state: ViewState) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(config.locale, i18n_text.CapabilitiesBoard),
    purpose: i18n.t(config.locale, i18n_text.CapabilityBoardPurpose),
    summary: capability_summary(config, state),
    actions: [],
    extra_class: Some("capability-board-header"),
    testid: Some("capability-board-header"),
  ))
}

fn capability_summary(
  config: Config(msg),
  state: ViewState,
) -> List(work_surface.SummaryChip) {
  case state {
    ReadyState(rows) -> [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(sum_rows(rows, fn(row) { list.length(row.pending) })),
        tone.Available,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsClaimed),
        int.to_string(sum_rows(rows, fn(row) { list.length(row.claimed) })),
        tone.Claimed,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsOngoing),
        int.to_string(sum_rows(rows, fn(row) { list.length(row.ongoing) })),
        tone.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(sum_rows(rows, fn(row) { row.blocked_count })),
        tone.Blocked,
      ),
    ]
    _ -> []
  }
}

fn sum_rows(rows: List(CapabilityRow), value: fn(CapabilityRow) -> Int) -> Int {
  list.fold(rows, 0, fn(total, row) { total + value(row) })
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
    |> list.sort(compare_rows)

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
    Ok(unassigned_row) ->
      list.append(assigned_rows, [unassigned_row])
      |> list.sort(compare_rows)
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
  let blocked_count = list.count(tasks, fn(task) { task.blocked_count > 0 })
  let oldest_age_days = oldest_task_age_days(tasks)

  case pending, claimed, ongoing {
    [], [], [] -> Error(Nil)
    _, _, _ ->
      Ok(CapabilityRow(
        id: id,
        name: name,
        pending: pending,
        claimed: claimed,
        ongoing: ongoing,
        blocked_count: blocked_count,
        oldest_age_days: oldest_age_days,
        pressure_score: pressure_score(
          pending: list.length(pending),
          claimed: list.length(claimed),
          ongoing: list.length(ongoing),
          blocked: blocked_count,
          oldest_age_days: oldest_age_days,
        ),
        is_unassigned: is_unassigned,
      ))
  }
}

fn oldest_task_age_days(tasks: List(Task)) -> Int {
  tasks
  |> list.map(fn(task) { client_ffi.days_since_iso(task.created_at) })
  |> list.fold(0, int.max)
}

fn pressure_score(
  pending pending: Int,
  claimed claimed: Int,
  ongoing ongoing: Int,
  blocked blocked: Int,
  oldest_age_days oldest_age_days: Int,
) -> Int {
  let unstarted_pressure = case pending > 0 && ongoing == 0 {
    True -> 80
    False -> 0
  }

  let claimed_pressure = int.max(claimed - ongoing, 0) * 8
  let age_pressure = int.min(oldest_age_days, 30)

  unstarted_pressure + { blocked * 40 } + claimed_pressure + age_pressure
}

fn compare_rows(a: CapabilityRow, b: CapabilityRow) -> order.Order {
  case int.compare(b.pressure_score, a.pressure_score) {
    order.Eq ->
      case a.is_unassigned, b.is_unassigned {
        True, False -> order.Gt
        False, True -> order.Lt
        _, _ -> string.compare(a.name, b.name)
      }
    other -> other
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
      attribute.attribute(
        "data-pressure-score",
        int.to_string(row.pressure_score),
      ),
    ],
    [
      div([attribute.class("capability-board-row-header")], [
        div([attribute.class("capability-board-row-heading")], [
          h4(
            [
              attribute.class("capability-board-row-title"),
              attribute.attribute("id", heading_id),
            ],
            [text(row.name)],
          ),
          span(
            [
              attribute.class(
                "capability-board-pressure " <> pressure_tone(row),
              ),
            ],
            [text(pressure_label(config.locale, row))],
          ),
        ]),
        div([attribute.class("capability-board-row-summary")], [
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsAvailable),
            list.length(row.pending),
            tone.Available,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsClaimed),
            list.length(row.claimed),
            tone.Claimed,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsOngoing),
            list.length(row.ongoing),
            tone.Ongoing,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.Blocked),
            row.blocked_count,
            tone.Blocked,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.CapabilityBoardOldest),
            row.oldest_age_days,
            tone.Neutral,
            "age",
          ),
        ]),
      ]),
      div([attribute.class("capability-board-row-grid")], [
        view_lane_group(config, PendingLane, row.pending),
        view_lane_group(config, ClaimedLane, row.claimed),
        view_lane_group(config, OngoingLane, row.ongoing),
      ]),
    ],
  )
}

fn view_summary_chip(
  label: String,
  value: Int,
  tone_value: tone.Tone,
  extra_class: String,
) -> Element(msg) {
  let chip =
    signal_chip.metric_int(label, value, tone_value)
    |> signal_chip.with_class("capability-summary-chip")
    |> signal_chip.with_parts(
      "capability-summary-value",
      "capability-summary-label",
    )
    |> signal_chip.with_testid("capability-summary-chip")

  case extra_class {
    "" -> chip
    _ -> signal_chip.with_extra_class(chip, extra_class)
  }
  |> signal_chip.view
}

fn pressure_label(locale: Locale, row: CapabilityRow) -> String {
  case row.blocked_count > 0 {
    True -> i18n.t(locale, i18n_text.CapabilityBoardPressureBlocked)
    False ->
      case row.pending, row.claimed, row.ongoing {
        [], [], _ -> i18n.t(locale, i18n_text.CapabilityBoardPressureFlowing)
        _, _, [] -> i18n.t(locale, i18n_text.CapabilityBoardPressureNoTraction)
        _, _, _ -> i18n.t(locale, i18n_text.CapabilityBoardPressureFlowing)
      }
  }
}

fn pressure_tone(row: CapabilityRow) -> String {
  case row.blocked_count > 0 {
    True -> "blocked"
    False ->
      case row.pending, row.claimed, row.ongoing {
        [], [], _ -> "neutral"
        _, _, [] -> "warning"
        _, _, _ -> "flowing"
      }
  }
}

fn view_lane_group(
  config: Config(msg),
  lane: LaneState,
  tasks: List(Task),
) -> Element(msg) {
  let #(title, group_class, icon_name, state_name, empty_text) =
    lane_metadata(config.locale, lane)

  div(
    [
      attribute.class("capability-lane-group " <> group_class),
      attribute.attribute("data-testid", "capability-lane-group"),
      attribute.attribute("data-column-state", state_name),
    ],
    [
      div([attribute.class("capability-lane-header")], [
        div([attribute.class("capability-lane-title")], [
          span(
            [
              attribute.class("capability-lane-icon"),
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
        [] -> view_empty_group(empty_text)
        _ ->
          keyed.ul(
            [
              attribute.class(
                "capability-lane-content capability-board-column-content",
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
      i18n.t(locale, i18n_text.MetricsAvailable),
      "available",
      icons.Pause,
      "pending",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyPending),
    )
    ClaimedLane -> #(
      task_state_ui.label(locale, Claimed(Taken)),
      "claimed",
      icons.Pause,
      "claimed",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyClaimed),
    )
    OngoingLane -> #(
      task_state_ui.label(locale, Claimed(Ongoing)),
      "ongoing",
      icons.Play,
      "ongoing",
      i18n.t(locale, i18n_text.CapabilityBoardEmptyOngoing),
    )
  }
}

fn view_empty_group(message: String) -> Element(msg) {
  div(
    [
      attribute.class("capability-lane-empty"),
      attribute.attribute("data-testid", "capability-lane-empty"),
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
      span(
        [
          attribute.class("task-claimed-by"),
          attribute.attribute(
            "title",
            i18n.t(config.locale, i18n_text.ClaimedBy) <> " " <> claimed_label,
          ),
        ],
        [
          text(claimed_label),
          span([attribute.class("task-claimed-icon")], [
            icons.nav_icon(status_icon, icons.XSmall),
          ]),
        ],
      )
    }
    Available ->
      span(
        [
          attribute.class("task-status-muted"),
          attribute.attribute(
            "title",
            task_state_ui.hint(config.locale, task.status),
          ),
        ],
        [text(task_status_utils.label(config.locale, task.status))],
      )
    Completed -> task_item.empty_secondary()
  }

  let #(card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info(config.cards, task)
  let border_class = task_color.card_border_class(resolved_color)
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  let actions = case task.status {
    Available ->
      task_item.single_action(task_actions.claim_icon(
        task_state_ui.next_action(config.locale, task.status),
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
      leading: view_card_identity_swatch(card_title_opt),
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

fn view_card_identity_swatch(card_title: Option(String)) -> Option(Element(msg)) {
  case card_title {
    Some(title) ->
      Some(
        span(
          [
            attribute.class("task-card-identity-swatch"),
            attribute.attribute("aria-hidden", "true"),
            attribute.attribute("title", title),
          ],
          [],
        ),
      )
    None -> None
  }
}
