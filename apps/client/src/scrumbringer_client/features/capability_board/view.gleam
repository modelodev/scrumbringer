import domain/api_error.{type ApiError}
import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/remote.{type Remote, Failed, Loaded}
import domain/task as domain_task
import domain/task_status.{Available, Claimed, Done, Ongoing, Taken}
import domain/task_type.{type TaskType}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html.{
  button, div, h4, input, label, option as html_option, select, span, text,
}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/capability_scope.{type CapabilityScope}
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
    tasks: Remote(List(domain_task.Task)),
    task_types: Remote(List(TaskType)),
    capabilities: Remote(List(Capability)),
    cards: List(Card),
    org_users: List(OrgUser),
    capability_scope: CapabilityScope,
    my_capability_ids: List(Int),
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search_query: String,
    on_capability_scope_change: fn(String) -> msg,
    on_type_filter_change: fn(String) -> msg,
    on_capability_filter_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_task_click: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    capability_mode: member_pool.PlanCapabilityMode,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    card_query: String,
    show_closed: Option(Bool),
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
    on_closed_toggled: fn(Bool) -> msg,
    on_capability_mode_change: fn(String) -> msg,
  )
}

type CapabilityColumn {
  CapabilityColumn(
    key: String,
    name: String,
    capability_id: Option(Int),
    is_unassigned: Bool,
  )
}

type CapabilityHealth {
  CapabilityHealth(
    available: Int,
    claimed: Int,
    ongoing: Int,
    done: Int,
    blocked: Int,
  )
}

type CapabilityCell {
  CapabilityCell(
    column: CapabilityColumn,
    tasks: List(domain_task.Task),
    health: CapabilityHealth,
  )
}

type CapabilityRow {
  CapabilityRow(
    id: String,
    title: String,
    card: Card,
    cells: List(CapabilityCell),
    tasks: List(domain_task.Task),
    health: CapabilityHealth,
  )
}

type CapabilityData {
  CapabilityData(
    rows: List(CapabilityRow),
    columns: List(CapabilityColumn),
    health: CapabilityHealth,
  )
}

type ViewState {
  LoadingState
  ErrorState(message: String)
  EmptyState
  NoResultsState
  ReadyState(data: CapabilityData)
}

pub fn view(config: Config(msg)) -> element.Element(msg) {
  let state = derive_state(config)
  let include_closed = include_closed(config)

  let content = case state {
    LoadingState ->
      empty_notice(
        "clock",
        i18n.t(config.locale, i18n_text.CapabilityBoardLoading),
        "capability-board-state capability-board-loading",
      )
    ErrorState(message) ->
      empty_notice(
        "exclamation-triangle",
        message,
        "capability-board-state capability-board-error",
      )
    EmptyState ->
      empty_notice(
        "clipboard-document-list",
        i18n.t(config.locale, i18n_text.CapabilityBoardEmpty),
        "capability-board-state capability-board-empty",
      )
    NoResultsState ->
      empty_notice(
        "magnifying-glass",
        i18n.t(config.locale, i18n_text.CapabilityBoardNoResults),
        "capability-board-state capability-board-no-results",
      )
    ReadyState(data) ->
      case config.capability_mode {
        member_pool.PlanCapabilityList -> view_list(config, data)
        member_pool.PlanCapabilityMatrix -> view_matrix(config, data)
      }
  }

  div(
    [
      attribute.class("capability-board"),
      attribute.attribute("data-testid", "capability-board"),
    ],
    [
      view_surface_header(config, state, include_closed),
      content,
    ],
  )
}

fn empty_notice(_icon: String, message: String, class_name: String) {
  div([attribute.class(class_name)], [
    span(
      [
        attribute.class("empty-icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [
        icons.nav_icon(icons.InboxEmpty, icons.Medium),
      ],
    ),
    span([attribute.class("empty-text")], [text(message)]),
  ])
}

fn view_surface_header(
  config: Config(msg),
  state: ViewState,
  include_closed: Bool,
) -> element.Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(config.locale, i18n_text.CapabilitiesBoard),
    purpose: i18n.t(config.locale, i18n_text.CapabilityBoardPurpose),
    summary: capability_summary(config, state),
    actions: [view_my_capabilities_action(config)],
    extra_class: Some("capability-board-header"),
    testid: Some("capability-board-header"),
  ))
  |> with_scope_bar(config, include_closed)
}

fn view_my_capabilities_action(config: Config(msg)) -> element.Element(msg) {
  button(
    [
      attribute.type_("button"),
      attribute.class("work-surface-action"),
      attribute.attribute("data-testid", "capability-my-capabilities-action"),
      event.on_click(config.on_capability_scope_change("mine")),
    ],
    [text(i18n.t(config.locale, i18n_text.MyCapabilitiesLabel))],
  )
}

fn capability_summary(
  config: Config(msg),
  state: ViewState,
) -> List(work_surface.SummaryChip) {
  case state {
    ReadyState(CapabilityData(health: health, rows: rows, columns: columns)) -> [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryCards),
        int.to_string(list.length(rows)),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Capabilities),
        int.to_string(list.length(columns)),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(health.available),
        tone.Available,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsClaimed),
        int.to_string(health.claimed),
        tone.Claimed,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsOngoing),
        int.to_string(health.ongoing),
        tone.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(health.blocked),
        tone.Blocked,
      ),
    ]
    _ -> []
  }
}

fn with_scope_bar(
  header: element.Element(msg),
  config: Config(msg),
  include_closed: Bool,
) -> element.Element(msg) {
  div([attribute.class("plan-scope-shell")], [
    header,
    scope_bar.view(scope_bar.Config(
      locale: config.locale,
      cards: config.cards,
      depth_names: config.depth_names,
      scope_kind: config.scope_kind,
      selected_depth: config.selected_depth,
      selected_card_id: config.selected_card_id,
      card_query: config.card_query,
      show_closed: include_closed,
      id_prefix: "capability-plan",
      mode_controls: capability_mode_controls(config),
      refinement_controls: capability_refinement_controls(config),
      show_closed_control: True,
      on_scope_kind_change: config.on_scope_kind_change,
      on_scope_depth_change: config.on_scope_depth_change,
      on_scope_card_change: config.on_scope_card_change,
      on_scope_card_search_change: config.on_scope_card_search_change,
      on_closed_toggled: config.on_closed_toggled,
    )),
  ])
}

fn capability_refinement_controls(
  config: Config(msg),
) -> List(element.Element(msg)) {
  [
    label([attribute.class("plan-filter-control")], [
      span([], [text(i18n.t(config.locale, i18n_text.TypeLabel))]),
      select(
        [
          attribute.attribute("data-testid", "capability-filter-type"),
          attribute.value(option_int_to_string(config.type_filter)),
          event.on_input(config.on_type_filter_change),
        ],
        type_options(config.locale, config.task_types),
      ),
    ]),
    label([attribute.class("plan-filter-control")], [
      span([], [text(i18n.t(config.locale, i18n_text.CapabilityLabel))]),
      select(
        [
          attribute.attribute("data-testid", "capability-filter-capability"),
          attribute.value(option_int_to_string(config.capability_filter)),
          event.on_input(config.on_capability_filter_change),
        ],
        capability_options(config.locale, config.capabilities),
      ),
    ]),
    label([attribute.class("plan-filter-control capability-search-control")], [
      span([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
      input([
        attribute.type_("search"),
        attribute.attribute("data-testid", "capability-filter-search"),
        attribute.placeholder(i18n.t(config.locale, i18n_text.SearchPlaceholder)),
        attribute.value(config.search_query),
        event.on_input(config.on_search_change),
      ]),
    ]),
  ]
}

fn type_options(
  locale: Locale,
  task_types: Remote(List(TaskType)),
) -> List(element.Element(msg)) {
  let base = [
    html_option([attribute.value("")], i18n.t(locale, i18n_text.AllOption)),
  ]

  case task_types {
    Loaded(values) ->
      list.append(
        base,
        list.map(values, fn(task_type) {
          html_option(
            [attribute.value(int.to_string(task_type.id))],
            task_type.name,
          )
        }),
      )
    _ -> base
  }
}

fn capability_options(
  locale: Locale,
  capabilities: Remote(List(Capability)),
) -> List(element.Element(msg)) {
  let base = [
    html_option([attribute.value("")], i18n.t(locale, i18n_text.AllOption)),
  ]

  case capabilities {
    Loaded(values) ->
      list.append(
        base,
        list.map(values, fn(capability) {
          html_option(
            [attribute.value(int.to_string(capability.id))],
            capability.name,
          )
        }),
      )
    _ -> base
  }
}

fn option_int_to_string(value: Option(Int)) -> String {
  case value {
    Some(int_value) -> int.to_string(int_value)
    None -> ""
  }
}

fn capability_mode_controls(
  config: Config(msg),
) -> List(scope_bar.ModeControl(msg)) {
  [
    capability_mode_control(config, i18n_text.PlanCapabilityList, "list"),
    capability_mode_control(config, i18n_text.PlanCapabilityMatrix, "matrix"),
  ]
}

fn capability_mode_control(
  config: Config(msg),
  label_key: i18n_text.Text,
  value: String,
) -> scope_bar.ModeControl(msg) {
  let active = capability_mode_value(config.capability_mode) == value

  scope_bar.ModeControl(
    label: i18n.t(config.locale, label_key),
    value: value,
    active: active,
    testid: "capability-mode-" <> value,
    on_select: config.on_capability_mode_change(value),
  )
}

fn derive_state(config: Config(msg)) -> ViewState {
  case config.tasks, config.task_types, config.capabilities {
    Failed(err), _, _ -> ErrorState(capability_board_error(config.locale, err))
    _, Failed(err), _ -> ErrorState(capability_board_error(config.locale, err))
    _, _, Failed(err) -> ErrorState(capability_board_error(config.locale, err))
    Loaded(tasks), Loaded(task_types), Loaded(capabilities) -> {
      let status_tasks =
        tasks
        |> list.filter(fn(task) { include_task_status(config, task) })

      let filtered_tasks =
        status_tasks
        |> list.filter(fn(task) {
          matches_active_filters(task, config, task_types)
        })

      case status_tasks {
        [] -> EmptyState
        _ -> {
          case filtered_tasks {
            [] -> NoResultsState
            _ -> {
              let rows =
                build_rows(filtered_tasks, task_types, capabilities, config)
              case rows {
                [] -> NoResultsState
                _ ->
                  ReadyState(CapabilityData(
                    rows: rows,
                    columns: columns_from_rows(rows),
                    health: health_for_tasks(
                      list.flat_map(rows, fn(row) { row.tasks }),
                    ),
                  ))
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

fn include_task_status(config: Config(msg), task: domain_task.Task) -> Bool {
  case domain_task.status(task) {
    Done -> include_closed(config)
    _ -> True
  }
}

fn matches_active_filters(
  task: domain_task.Task,
  config: Config(msg),
  task_types: List(TaskType),
) -> Bool {
  work_filters.matches(
    work_filters.Filters(
      type_filter: config.type_filter,
      capability_filter: config.capability_filter,
      search_query: config.search_query,
      capability_scope: config.capability_scope,
      my_capability_ids: config.my_capability_ids,
      task_types: task_types,
    ),
    task,
  )
}

fn build_rows(
  tasks: List(domain_task.Task),
  task_types: List(TaskType),
  capabilities: List(Capability),
  config: Config(msg),
) -> List(CapabilityRow) {
  let columns =
    columns_for_tasks(tasks, task_types, capabilities, config.locale)

  row_cards(config)
  |> list.filter_map(fn(card) {
    let row_tasks =
      tasks
      |> list.filter(fn(task) {
        card_queries.task_in_card_subtree(task, card.id, config.cards)
      })

    case row_tasks {
      [] -> Error(Nil)
      _ -> {
        let cells =
          columns
          |> list.map(fn(column) {
            let cell_tasks =
              row_tasks
              |> list.filter(fn(task) {
                task_matches_column(task, column, task_types, capabilities)
              })
              |> sort_tasks
            CapabilityCell(
              column: column,
              tasks: cell_tasks,
              health: health_for_tasks(cell_tasks),
            )
          })

        Ok(CapabilityRow(
          id: "card-" <> int.to_string(card.id),
          title: card.title,
          card: card,
          cells: cells,
          tasks: sort_tasks(row_tasks),
          health: health_for_tasks(row_tasks),
        ))
      }
    }
  })
  |> list.sort(compare_rows)
}

fn row_cards(config: Config(msg)) -> List(Card) {
  card_queries.row_cards_for_scope(
    config.cards,
    config.scope_kind,
    config.selected_depth,
    config.selected_card_id,
  )
}

fn columns_for_tasks(
  tasks: List(domain_task.Task),
  task_types: List(TaskType),
  capabilities: List(Capability),
  locale: Locale,
) -> List(CapabilityColumn) {
  let assigned =
    capabilities
    |> list.filter(fn(capability) {
      list.any(tasks, fn(task) {
        work_filters.task_capability_id(task, task_types) == Some(capability.id)
      })
    })
    |> list.map(fn(capability) {
      CapabilityColumn(
        key: "capability-" <> int.to_string(capability.id),
        name: capability.name,
        capability_id: Some(capability.id),
        is_unassigned: False,
      )
    })
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })

  let has_unassigned =
    list.any(tasks, fn(task) {
      case work_filters.task_capability_id(task, task_types) {
        Some(capability_id) -> !has_capability(capabilities, capability_id)
        None -> True
      }
    })

  case has_unassigned {
    True ->
      list.append(assigned, [
        CapabilityColumn(
          key: "capability-unassigned",
          name: i18n.t(locale, i18n_text.NoCapability),
          capability_id: None,
          is_unassigned: True,
        ),
      ])
    False -> assigned
  }
}

fn columns_from_rows(rows: List(CapabilityRow)) -> List(CapabilityColumn) {
  rows
  |> list.flat_map(fn(row) { row.cells })
  |> list.filter(fn(cell) { cell.tasks != [] })
  |> list.fold([], fn(columns: List(CapabilityColumn), cell) {
    case has_column(columns, cell.column.key) {
      True -> columns
      False -> list.append(columns, [cell.column])
    }
  })
}

fn has_column(columns: List(CapabilityColumn), key: String) -> Bool {
  list.any(columns, fn(column) { column.key == key })
}

fn task_matches_column(
  task: domain_task.Task,
  column: CapabilityColumn,
  task_types: List(TaskType),
  capabilities: List(Capability),
) -> Bool {
  case column.capability_id, work_filters.task_capability_id(task, task_types) {
    Some(column_id), Some(task_column_id) -> column_id == task_column_id
    None, Some(task_column_id) -> !has_capability(capabilities, task_column_id)
    None, None -> True
    _, _ -> False
  }
}

fn has_capability(capabilities: List(Capability), capability_id: Int) -> Bool {
  list.any(capabilities, fn(capability) { capability.id == capability_id })
}

fn view_list(config: Config(msg), data: CapabilityData) -> element.Element(msg) {
  keyed.div(
    [
      attribute.class("capability-list"),
      attribute.attribute("data-testid", "capability-list"),
    ],
    data.columns
      |> list.map(fn(column) {
        #(column.key, view_list_section(config, column, data.rows))
      }),
  )
}

fn view_list_section(
  config: Config(msg),
  column: CapabilityColumn,
  rows: List(CapabilityRow),
) -> element.Element(msg) {
  let cells =
    rows
    |> list.filter_map(fn(row) {
      case list.find(row.cells, fn(cell) { cell.column.key == column.key }) {
        Ok(cell) ->
          case cell.tasks {
            [] -> Error(Nil)
            _ -> Ok(#(row, cell))
          }
        Error(_) -> Error(Nil)
      }
    })

  let health =
    health_for_tasks(list.flat_map(cells, fn(pair) { { pair.1 }.tasks }))

  div(
    [
      attribute.class("capability-list-section"),
      attribute.attribute("data-testid", "capability-list-section"),
    ],
    [
      div([attribute.class("capability-list-section-header")], [
        h4([], [text(column.name)]),
        div([attribute.class("capability-board-row-summary")], [
          view_summary_chip(
            i18n.t(config.locale, i18n_text.CapabilityBoardTotal),
            health_total(health),
            tone.Neutral,
            "total",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.CapabilityBoardComplete),
            health.done,
            tone.Neutral,
            "done",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.Blocked),
            health.blocked,
            tone.Blocked,
            "blocked",
          ),
        ]),
      ]),
      keyed.div([attribute.class("capability-list-rows")], case cells {
        [] -> [#("empty", view_no_tasks(config))]
        _ ->
          list.map(cells, fn(pair) {
            let #(row, cell) = pair
            #(row.id <> "-" <> column.key, view_list_row(config, row, cell))
          })
      }),
    ],
  )
}

fn view_list_row(
  config: Config(msg),
  row: CapabilityRow,
  cell: CapabilityCell,
) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-list-row"),
      attribute.attribute("data-testid", "capability-list-row"),
      attribute.attribute("data-card-id", int.to_string(row.card.id)),
    ],
    [
      div([attribute.class("capability-list-row-header")], [
        div([attribute.class("capability-list-row-title")], [
          span(
            [
              attribute.class(
                "capability-row-swatch "
                <> task_color.card_border_class(row.card.color),
              ),
              attribute.attribute("aria-hidden", "true"),
            ],
            [],
          ),
          h4([], [text(row.title)]),
        ]),
        div([attribute.class("capability-board-row-summary")], [
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsAvailable),
            cell.health.available,
            tone.Available,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsClaimed),
            cell.health.claimed,
            tone.Claimed,
            "",
          ),
          view_summary_chip(
            i18n.t(config.locale, i18n_text.MetricsOngoing),
            cell.health.ongoing,
            tone.Ongoing,
            "",
          ),
        ]),
      ]),
      keyed.div(
        [attribute.class("capability-list-task-preview")],
        cell.tasks
          |> sort_tasks
          |> list.take(3)
          |> list.map(fn(task) {
            #(int.to_string(task.id), view_task_item(config, task))
          }),
      ),
    ],
  )
}

fn view_matrix(
  config: Config(msg),
  data: CapabilityData,
) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-matrix"),
      attribute.attribute("data-testid", "capability-matrix"),
      attribute.attribute("role", "table"),
    ],
    [
      div(
        [
          attribute.class("capability-matrix-row capability-matrix-header-row"),
          attribute.attribute("role", "row"),
        ],
        [
          view_matrix_header_cell(row_label(config)),
          ..list.append(
            list.map(data.columns, fn(column) {
              view_matrix_header_cell(column.name)
            }),
            [
              view_matrix_header_cell(i18n.t(
                config.locale,
                i18n_text.CapabilityBoardTotal,
              )),
            ],
          )
        ],
      ),
      keyed.div(
        [
          attribute.class("capability-matrix-body"),
          attribute.attribute("role", "rowgroup"),
        ],
        list.map(data.rows, fn(row) {
          #(row.id, view_matrix_row(config, row, data.columns))
        }),
      ),
      view_matrix_total_row(config, data),
    ],
  )
}

fn view_matrix_header_cell(label_text: String) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-matrix-cell capability-matrix-header-cell"),
      attribute.attribute("role", "columnheader"),
    ],
    [text(label_text)],
  )
}

fn view_matrix_row(
  config: Config(msg),
  row: CapabilityRow,
  columns: List(CapabilityColumn),
) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-matrix-row"),
      attribute.attribute("role", "row"),
      attribute.attribute("data-testid", "capability-matrix-row"),
    ],
    [
      div(
        [
          attribute.class("capability-matrix-cell capability-matrix-card-cell"),
          attribute.attribute("role", "rowheader"),
        ],
        [
          span(
            [
              attribute.class(
                "capability-row-swatch "
                <> task_color.card_border_class(row.card.color),
              ),
              attribute.attribute("aria-hidden", "true"),
            ],
            [],
          ),
          span([], [text(row.title)]),
        ],
      ),
      ..list.append(
        list.map(columns, fn(column) {
          view_matrix_body_cell(config, row, column)
        }),
        [view_matrix_total_cell(config, row.health)],
      )
    ],
  )
}

fn view_matrix_body_cell(
  config: Config(msg),
  row: CapabilityRow,
  column: CapabilityColumn,
) -> element.Element(msg) {
  case list.find(row.cells, fn(cell) { cell.column.key == column.key }) {
    Ok(cell) ->
      case cell.tasks {
        [] -> view_empty_matrix_cell(config)
        _ -> view_matrix_health_cell(config, cell.health, False)
      }
    Error(_) -> view_empty_matrix_cell(config)
  }
}

fn view_empty_matrix_cell(config: Config(msg)) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-matrix-cell capability-matrix-empty-cell"),
      attribute.attribute("role", "cell"),
      attribute.attribute("data-testid", "capability-matrix-empty-cell"),
      attribute.attribute(
        "title",
        i18n.t(config.locale, i18n_text.CapabilityBoardEmptyCell),
      ),
    ],
    [text("-")],
  )
}

fn view_matrix_total_cell(
  config: Config(msg),
  health: CapabilityHealth,
) -> element.Element(msg) {
  view_matrix_health_cell(config, health, True)
}

fn view_matrix_health_cell(
  config: Config(msg),
  health: CapabilityHealth,
  total: Bool,
) -> element.Element(msg) {
  let class = case total {
    True -> "capability-matrix-cell capability-matrix-total-cell"
    False -> "capability-matrix-cell"
  }

  div(
    [
      attribute.class(class),
      attribute.attribute("role", "cell"),
      attribute.attribute("data-testid", case total {
        True -> "capability-matrix-total-cell"
        False -> "capability-matrix-cell"
      }),
    ],
    [
      span([attribute.class("capability-matrix-total")], [
        text(int.to_string(health_total(health))),
      ]),
      span([attribute.class("capability-matrix-breakdown")], [
        text(
          i18n.t(config.locale, i18n_text.MetricsOngoing)
          <> " "
          <> int.to_string(health.ongoing)
          <> " / "
          <> i18n.t(config.locale, i18n_text.CapabilityBoardComplete)
          <> " "
          <> int.to_string(health.done),
        ),
      ]),
    ],
  )
}

fn view_matrix_total_row(
  config: Config(msg),
  data: CapabilityData,
) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-matrix-row capability-matrix-total-row"),
      attribute.attribute("role", "row"),
      attribute.attribute("data-testid", "capability-matrix-total-row"),
    ],
    [
      div(
        [
          attribute.class("capability-matrix-cell capability-matrix-card-cell"),
          attribute.attribute("role", "rowheader"),
        ],
        [text(i18n.t(config.locale, i18n_text.CapabilityBoardTotal))],
      ),
      ..list.append(
        list.map(data.columns, fn(column) {
          let tasks =
            data.rows
            |> list.flat_map(fn(row) {
              case
                list.find(row.cells, fn(cell) { cell.column.key == column.key })
              {
                Ok(cell) -> cell.tasks
                Error(_) -> []
              }
            })
          view_matrix_total_cell(config, health_for_tasks(tasks))
        }),
        [view_matrix_total_cell(config, data.health)],
      )
    ],
  )
}

fn view_no_tasks(config: Config(msg)) -> element.Element(msg) {
  div(
    [
      attribute.class("capability-list-empty"),
      attribute.attribute("data-testid", "capability-list-empty"),
    ],
    [text(i18n.t(config.locale, i18n_text.CapabilityBoardNoTasks))],
  )
}

fn view_summary_chip(
  label: String,
  value: Int,
  tone_value: tone.Tone,
  extra_class: String,
) -> element.Element(msg) {
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

fn view_task_item(
  config: Config(msg),
  task: domain_task.Task,
) -> element.Element(msg) {
  let status_display = case domain_task.status(task) {
    Claimed(_) -> {
      let claimed_label = case domain_task.claimed_by(task) {
        Some(user_id) ->
          case list.find(config.org_users, fn(user) { user.id == user_id }) {
            Ok(user) -> user.email
            Error(_) -> i18n.t(config.locale, i18n_text.UnknownUser)
          }
        None -> i18n.t(config.locale, i18n_text.UnknownUser)
      }

      let status_icon = task_status_utils.claimed_icon(domain_task.status(task))
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
            task_state_ui.hint(config.locale, domain_task.status(task)),
          ),
        ],
        [text(task_status_utils.label(config.locale, domain_task.status(task)))],
      )
    Done -> task_item.empty_secondary()
  }

  let #(card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info(config.cards, task)
  let border_class = task_color.card_border_class(resolved_color)
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  let actions = case domain_task.status(task) {
    Available ->
      task_item.single_action(task_actions.claim_icon(
        task_state_ui.next_action(config.locale, domain_task.status(task)),
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
      content_title: None,
      content_label: None,
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

fn view_card_identity_swatch(
  card_title: Option(String),
) -> Option(element.Element(msg)) {
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

fn include_closed(config: Config(msg)) -> Bool {
  case config.show_closed {
    Some(value) -> value
    None ->
      case config.scope_kind, config.selected_card_id {
        _, _ ->
          card_queries.closed_default_for_scope(
            config.cards,
            loaded_tasks(config.tasks),
            config.scope_kind,
            config.selected_card_id,
          )
      }
  }
}

fn loaded_tasks(tasks: Remote(List(domain_task.Task))) -> List(domain_task.Task) {
  case tasks {
    Loaded(values) -> values
    _ -> []
  }
}

fn health_for_tasks(tasks: List(domain_task.Task)) -> CapabilityHealth {
  CapabilityHealth(
    available: list.count(tasks, fn(task) {
      domain_task.status(task) == Available
    }),
    claimed: list.count(tasks, fn(task) {
      domain_task.status(task) == Claimed(Taken)
    }),
    ongoing: list.count(tasks, fn(task) {
      domain_task.status(task) == Claimed(Ongoing)
    }),
    done: list.count(tasks, fn(task) { domain_task.status(task) == Done }),
    blocked: list.count(tasks, fn(task) { task.blocked_count > 0 }),
  )
}

fn health_total(health: CapabilityHealth) -> Int {
  health.available + health.claimed + health.ongoing + health.done
}

fn compare_rows(a: CapabilityRow, b: CapabilityRow) -> order.Order {
  case int.compare(b.health.blocked, a.health.blocked) {
    order.Eq ->
      case int.compare(health_total(b.health), health_total(a.health)) {
        order.Eq -> string.compare(a.title, b.title)
        other -> other
      }
    other -> other
  }
}

fn sort_tasks(tasks: List(domain_task.Task)) -> List(domain_task.Task) {
  list.sort(tasks, compare_tasks)
}

fn compare_tasks(a: domain_task.Task, b: domain_task.Task) -> order.Order {
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
  case task.blocked_count > 0, domain_task.status(task) {
    True, _ -> 0
    False, Available -> 1
    False, Claimed(Ongoing) -> 2
    False, Claimed(Taken) -> 3
    False, Done -> 4
  }
}

fn row_label(config: Config(msg)) -> String {
  case config.scope_kind {
    member_pool.PlanScopeProject ->
      i18n.t(config.locale, i18n_text.CapabilityBoardCardColumn)
    member_pool.PlanScopeCard ->
      i18n.t(config.locale, i18n_text.CapabilityBoardCardColumn)
    member_pool.PlanScopeLevel ->
      i18n.t(config.locale, i18n_text.CapabilityBoardLevelColumn)
  }
}

fn capability_mode_value(mode: member_pool.PlanCapabilityMode) -> String {
  case mode {
    member_pool.PlanCapabilityList -> "list"
    member_pool.PlanCapabilityMatrix -> "matrix"
  }
}
