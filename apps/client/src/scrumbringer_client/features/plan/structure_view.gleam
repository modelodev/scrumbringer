//// Plan / Structure explorer.

import domain/card.{type Card}
import domain/task as domain_task
import domain/task/state as task_execution_state
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h4, input, label, li, option as html_option, p, select, span,
  strong, text, ul,
}
import lustre/event

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/move_target
import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/features/plan/structure_filters
import scrumbringer_client/features/plan/structure_move
import scrumbringer_client/features/plan/structure_policy
import scrumbringer_client/features/plan/structure_presentation
import scrumbringer_client/features/plan/structure_rollups
import scrumbringer_client/features/plan/structure_tree
import scrumbringer_client/features/plan/tree_table
import scrumbringer_client/features/plan/types
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/tone
import scrumbringer_client/utils/card_queries

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    tasks: List(domain_task.Task),
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    card_query: String,
    show_closed: Option(Bool),
    status_filter: member_pool.PlanStatusFilter,
    sort_order: member_pool.PlanSort,
    collapsed_card_ids: List(Int),
    search_query: String,
    is_pm_or_admin: Bool,
    plan_mode: member_pool.PlanMode,
    move_mode: member_pool.PlanMoveMode,
    move_drag_state: member_pool.PlanMoveDragState,
    move_in_flight: Bool,
    move_error: Option(String),
    on_plan_mode_change: fn(String) -> msg,
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
    on_closed_toggled: fn(Bool) -> msg,
    on_status_filter_change: fn(String) -> msg,
    on_sort_change: fn(String) -> msg,
    on_card_toggle: fn(Int) -> msg,
    on_card_click: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
    on_move_requested: fn(Int) -> msg,
    on_move_cancelled: msg,
    on_move_destination_search_change: fn(String) -> msg,
    on_move_destination_selected: fn(move_target.MoveTarget) -> msg,
    on_move_drag_started: fn(Int) -> msg,
    on_move_drag_entered: fn(move_target.MoveTarget) -> msg,
    on_move_dropped: fn(move_target.MoveTarget) -> msg,
    on_move_drag_ended: msg,
    on_create_task_in_card: fn(Int) -> msg,
    on_create_subcard: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let include_closed = include_closed(config)
  let rows = structure_rows(config, include_closed)
  let summary =
    structure_rollups.summary_for_rows(rows, config.cards, config.tasks)
  let detail = structure_detail(config, include_closed, rows)
  let content = case rows {
    [] -> view_empty_state(config)
    _ -> view_body(config, rows, detail)
  }

  let surface =
    work_surface.new_surface(view_surface_header(
      config,
      summary,
      include_closed,
    ))
    |> work_surface.with_filters(view_scope_bar(config, include_closed))
    |> work_surface.with_content(content)
    |> work_surface.surface_with_class("plan-structure-view")
    |> work_surface.surface_with_testid("plan-structure-view")

  let surface = case config.move_error {
    Some(_) -> work_surface.with_state(surface, view_move_feedback(config))
    None -> surface
  }

  work_surface.surface(surface)
}

fn view_surface_header(
  config: Config(msg),
  summary: types.CardRollup,
  include_closed: Bool,
) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: "Plan",
    purpose: "Estructura de tarjetas y trabajo preparado.",
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryCards),
        int.to_string(list.length(visible_cards(config, include_closed))),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        "Tareas",
        int.to_string(summary.total_tasks),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(summary.available_tasks),
        tone.Available,
      ),
      work_surface.summary_chip(
        "Preparadas",
        int.to_string(summary.pool_impact),
        tone.Warning,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(summary.blocked_tasks),
        tone.Blocked,
      ),
    ],
    actions: move_header_actions(config),
    extra_class: Some("plan-structure-header"),
    testid: Some("plan-structure-header"),
  ))
}

fn move_header_actions(config: Config(msg)) -> List(Element(msg)) {
  case structure_move.moving_card(config.cards, config.move_mode) {
    Some(card) -> [
      div(
        [
          attribute.class("plan-move-context"),
          attribute.attribute("data-testid", "plan-move-context"),
        ],
        [
          span([attribute.class("plan-move-context-label")], [
            text("Moviendo: " <> card.title),
          ]),
          button(
            [
              attribute.type_("button"),
              attribute.class("work-surface-action"),
              attribute.attribute("data-testid", "plan-move-cancel"),
              event.on_click(config.on_move_cancelled),
            ],
            [text("Cancelar")],
          ),
        ],
      ),
    ]
    None -> []
  }
}

fn view_move_feedback(config: Config(msg)) -> Element(msg) {
  case config.move_error {
    Some(message) ->
      div(
        [
          attribute.class("plan-move-feedback"),
          attribute.attribute("data-testid", "plan-move-feedback"),
          attribute.attribute("role", "status"),
        ],
        [text(message)],
      )
    None -> element.none()
  }
}

fn view_scope_bar(config: Config(msg), include_closed: Bool) -> Element(msg) {
  scope_bar.view(scope_bar.Config(
    locale: config.locale,
    cards: config.cards,
    depth_names: config.depth_names,
    scope_kind: config.scope_kind,
    selected_depth: config.selected_depth,
    selected_card_id: config.selected_card_id,
    card_query: config.card_query,
    show_closed: include_closed,
    id_prefix: "plan-structure",
    mode_controls: [],
    refinement_controls: plan_refinement_controls(config),
    show_closed_control: True,
    on_scope_kind_change: config.on_scope_kind_change,
    on_scope_depth_change: config.on_scope_depth_change,
    on_scope_card_change: config.on_scope_card_change,
    on_scope_card_search_change: config.on_scope_card_search_change,
    on_closed_toggled: config.on_closed_toggled,
  ))
}

fn plan_refinement_controls(config: Config(msg)) -> List(Element(msg)) {
  case config.move_mode {
    member_pool.PlanMovingCard(_, _) -> [view_move_destination_search(config)]
    member_pool.PlanNotMoving -> normal_plan_refinement_controls(config)
  }
}

fn view_move_destination_search(config: Config(msg)) -> Element(msg) {
  let #(query, options) =
    structure_move.search_state(
      config.cards,
      config.tasks,
      config.depth_names,
      config.move_mode,
    )
  let listbox_id = "plan-move-destination-options"

  div([attribute.class("plan-move-search")], [
    label([attribute.class("plan-filter-control")], [
      span([], [text("Buscar destino")]),
      input([
        attribute.type_("search"),
        attribute.attribute("data-testid", "plan-move-destination-search"),
        attribute.attribute("role", "combobox"),
        attribute.attribute("aria-controls", listbox_id),
        attribute.attribute(
          "aria-expanded",
          attribute_value.boolean(query != ""),
        ),
        attribute.attribute("aria-autocomplete", "list"),
        attribute.attribute("autocomplete", "off"),
        attribute.placeholder("Titulo, ruta o #id"),
        attribute.value(query),
        event.on_input(config.on_move_destination_search_change),
        event.on_change(config.on_move_destination_search_change),
      ]),
    ]),
    view_move_root_option(config),
    case string.trim(query) {
      "" -> element.none()
      _ ->
        div(
          [
            attribute.id(listbox_id),
            attribute.class("card-target-options plan-move-picker-options"),
            attribute.attribute("data-testid", "plan-move-destination-options"),
            attribute.attribute("role", "listbox"),
          ],
          case options {
            [] -> [
              span([attribute.class("card-target-empty")], [
                text("Sin destinos para esa busqueda."),
              ]),
            ]
            _ ->
              list.map(options, fn(option) {
                view_move_destination_option(config, option)
              })
          },
        )
    },
  ])
}

fn view_move_destination_option(
  config: Config(msg),
  option: card_target.CardTargetOption,
) -> Element(msg) {
  let disabled = case option.disabled_reason {
    Some(_) -> True
    None -> False
  }

  button(
    [
      attribute.type_("button"),
      attribute.class(move_option_class(disabled)),
      attribute.attribute("data-testid", "plan-move-destination-option"),
      attribute.attribute("data-card-id", int.to_string(option.id)),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-label", option.label),
      attribute.disabled(disabled || config.move_in_flight),
      event.on_click(
        config.on_move_destination_selected(move_target.InsideCard(option.id)),
      ),
    ],
    [
      span([attribute.class("card-target-title")], [text(option.title)]),
      span([attribute.class("card-target-meta")], [
        text(
          option.path
          <> " - "
          <> option.level_name
          <> " #"
          <> int.to_string(option.id),
        ),
      ]),
      case option.disabled_reason {
        Some(reason) ->
          span([attribute.class("plan-move-destination-reason")], [
            text(card_target.disabled_reason_label(config.locale, reason)),
          ])
        None -> element.none()
      },
    ],
  )
}

fn view_move_root_option(config: Config(msg)) -> Element(msg) {
  case structure_move.moving_card(config.cards, config.move_mode) {
    Some(card) ->
      case card_policy.move_to_root_blocked_reason(card) {
        None ->
          button(
            [
              attribute.type_("button"),
              attribute.class("card-target-option plan-move-root-option"),
              attribute.attribute("data-testid", "plan-move-root-option"),
              attribute.disabled(config.move_in_flight),
              event.on_click(config.on_move_destination_selected(
                move_target.ProjectRoot,
              )),
            ],
            [
              span([attribute.class("card-target-title")], [
                text("Mover a raiz"),
              ]),
              span([attribute.class("card-target-meta")], [
                text("Quedará como tarjeta principal del proyecto"),
              ]),
            ],
          )
        Some(_) -> element.none()
      }
    None -> element.none()
  }
}

fn move_option_class(disabled: Bool) -> String {
  case disabled {
    True -> "card-target-option is-disabled"
    False -> "card-target-option"
  }
}

fn normal_plan_refinement_controls(config: Config(msg)) -> List(Element(msg)) {
  let filters =
    types.PlanFilters(
      status: config.status_filter,
      sort: config.sort_order,
      search_query: config.search_query,
      include_closed: include_closed(config),
    )

  list.append(
    [
      label([attribute.class("plan-filter-control")], [
        span([], [text("Estado")]),
        select(
          [
            attribute.attribute("data-testid", "plan-filter-status"),
            attribute.value(structure_filters.plan_status_value(filters.status)),
            event.on_input(config.on_status_filter_change),
            event.on_change(config.on_status_filter_change),
          ],
          [
            html_option(
              [attribute.value("all")],
              i18n.t(config.locale, i18n_text.PlanStatusAll),
            ),
            html_option(
              [attribute.value("draft")],
              i18n.t(config.locale, i18n_text.CardPhaseDraft),
            ),
            html_option(
              [attribute.value("active")],
              i18n.t(config.locale, i18n_text.CardPhaseActive),
            ),
            html_option(
              [attribute.value("closed")],
              i18n.t(config.locale, i18n_text.CardPhaseClosed),
            ),
          ],
        ),
      ]),
      label([attribute.class("plan-filter-control")], [
        span([], [text("Orden")]),
        select(
          [
            attribute.attribute("data-testid", "plan-filter-sort"),
            attribute.value(structure_filters.plan_sort_value(filters.sort)),
            event.on_input(config.on_sort_change),
            event.on_change(config.on_sort_change),
          ],
          [
            html_option([attribute.value("path")], "Árbol"),
            html_option([attribute.value("state")], "Estado"),
            html_option([attribute.value("due_date")], "Próximo vencimiento"),
            html_option([attribute.value("pool_impact")], "Trabajo preparado"),
          ],
        ),
      ]),
    ],
    list.append(
      case string.trim(filters.search_query) {
        "" -> []
        query -> [
          span([attribute.class("plan-filter-search-chip")], [
            text("Buscar: " <> query),
          ]),
        ]
      },
      case filters.include_closed {
        True -> [
          span([attribute.class("plan-filter-search-chip")], [
            text(i18n.t(config.locale, i18n_text.PlanIncludesClosed)),
          ]),
        ]
        False -> []
      },
    ),
  )
}

fn view_body(
  config: Config(msg),
  rows: List(types.StructureRow),
  detail: Option(types.StructureDetail),
) -> Element(msg) {
  case config.scope_kind, detail {
    member_pool.PlanScopeCard, Some(value) ->
      div([attribute.class("plan-card-scope-layout")], [
        view_detail(config, value),
        view_table(config, rows),
      ])
    _, Some(value) ->
      div([attribute.class("plan-structure-split")], [
        view_table(config, rows),
        view_detail(config, value),
      ])
    _, None -> view_table(config, rows)
  }
}

fn view_table(
  config: Config(msg),
  rows: List(types.StructureRow),
) -> Element(msg) {
  tree_table.view(
    tree_table.Config(
      caption: "Plan structure",
      class_name: "plan-structure-table",
      columns: [
        tree_table.column(
          first_column_label(config),
          fn(row) { view_tree_cell(config, row) },
          "plan-col-tree",
          "plan-cell-tree",
        ),
        tree_table.column(
          "Trabajo",
          fn(row) { view_work_cell(config.locale, row) },
          "plan-col-work",
          "plan-cell-work",
        ),
        tree_table.column(
          "Acciones",
          fn(row) { view_actions_cell(config, row, "desktop") },
          "plan-col-actions",
          "plan-cell-actions",
        ),
      ],
      rows: rows,
      key_fn: row_key,
      mobile_row: fn(row) { view_mobile_row(config, row) },
    ),
  )
}

fn view_mobile_row(config: Config(msg), row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, path:, level_name:, ..) = row

  div(
    [
      attribute.class("plan-tree-mobile-row " <> move_row_class(config, row)),
      attribute.attribute("data-testid", "plan-tree-mobile-row"),
      attribute.attribute("data-card-id", int.to_string(card.id)),
      ..move_drop_attributes(config, card)
    ],
    [
      div([attribute.class("plan-tree-mobile-main")], [
        view_tree_toggle(config, card),
        button(
          [
            attribute.type_("button"),
            attribute.class("plan-tree-trigger"),
            attribute.attribute("data-testid", "mobile-card-open"),
            attribute.attribute("title", path),
            event.on_click(config.on_card_click(card.id)),
          ],
          [span([attribute.class("plan-tree-title")], [text(card.title)])],
        ),
      ]),
      div([attribute.class("plan-tree-mobile-path")], [
        span([attribute.class("plan-tree-level")], [text(level_name)]),
        case path {
          "" -> element.none()
          _ -> span([attribute.class("plan-tree-mobile-parent")], [text(path)])
        },
      ]),
      div([attribute.class("plan-tree-mobile-meta")], [
        view_work_cell(config.locale, row),
      ]),
      view_actions_cell(config, row, "mobile"),
    ],
  )
}

fn view_tree_cell(config: Config(msg), row: types.StructureRow) -> Element(msg) {
  let types.CardRow(depth:, outline:, card:, path:, level_name:, ..) = row
  let depth_class = case depth > 1 {
    True -> " is-nested"
    False -> ""
  }
  let child_class = case
    card_queries.direct_child_cards(card.id, config.cards)
  {
    [] -> " is-leaf-row"
    _ -> " has-children"
  }

  div(
    [
      attribute.class(
        "plan-tree-cell"
        <> depth_class
        <> child_class
        <> " "
        <> move_row_class(config, row),
      ),
      ..move_drop_attributes(config, card)
    ],
    [
      view_tree_gutter(config, card, outline),
      button(
        [
          attribute.type_("button"),
          attribute.class("plan-tree-trigger"),
          attribute.attribute("data-testid", "card-show-open"),
          attribute.attribute("title", path),
          event.on_click(config.on_card_click(card.id)),
        ],
        [span([attribute.class("plan-tree-title")], [text(card.title)])],
      ),
      span([attribute.class("plan-tree-level")], [text(level_name)]),
    ],
  )
}

fn view_tree_gutter(
  config: Config(msg),
  card: Card,
  outline: List(types.TreeRail),
) -> Element(msg) {
  div(
    [attribute.class("plan-tree-gutter")],
    list.append(view_tree_rails(outline), [
      view_tree_node(config, card),
    ]),
  )
}

fn view_tree_rails(outline: List(types.TreeRail)) -> List(Element(msg)) {
  list.map(outline, fn(rail) {
    span(
      [
        attribute.class("plan-tree-rail " <> tree_rail_class(rail)),
        attribute.attribute("aria-hidden", "true"),
      ],
      [],
    )
  })
}

fn tree_rail_class(rail: types.TreeRail) -> String {
  case rail {
    types.TreeBlank -> "is-blank"
    types.TreeContinue -> "is-continue"
    types.TreeElbow -> "is-elbow"
    types.TreeEnd -> "is-end"
  }
}

fn view_tree_node(config: Config(msg), card: Card) -> Element(msg) {
  span([attribute.class(tree_node_class(config, card))], [
    view_tree_toggle(config, card),
  ])
}

fn tree_node_class(config: Config(msg), card: Card) -> String {
  let has_children =
    card_queries.direct_child_cards(card.id, config.cards) != []
  let open = has_children && !is_collapsed(config, card.id)

  case open {
    True -> "plan-tree-node is-open"
    False -> "plan-tree-node"
  }
}

fn view_tree_toggle(config: Config(msg), card: Card) -> Element(msg) {
  let has_children =
    card_queries.direct_child_cards(card.id, config.cards) != []
  let collapsed = is_collapsed(config, card.id)

  case has_children {
    True ->
      button(
        [
          attribute.type_("button"),
          attribute.class("plan-tree-toggle"),
          attribute.attribute("data-testid", "plan-tree-toggle"),
          attribute.attribute("aria-label", "Alternar " <> card.title),
          attribute.attribute(
            "aria-expanded",
            attribute_value.boolean(!collapsed),
          ),
          event.on_click(config.on_card_toggle(card.id)),
        ],
        [
          text(case collapsed {
            True -> "▸"
            False -> "▾"
          }),
        ],
      )
    False ->
      span(
        [
          attribute.class("plan-tree-toggle-placeholder"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [span([attribute.class("plan-tree-terminal-dot")], [])],
      )
  }
}

fn view_state_cell(locale: Locale, row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, ..) = row
  signal_chip.text(
    structure_presentation.card_state_label(locale, card),
    structure_presentation.card_state_tone(card),
  )
  |> signal_chip.with_class("plan-state-chip")
  |> signal_chip.view
}

fn view_task_count_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(rollup:, ..) = row
  span([attribute.class("plan-task-count")], [
    text(
      int.to_string(rollup.closed_tasks)
      <> "/"
      <> int.to_string(rollup.total_tasks),
    ),
  ])
}

fn view_work_cell(locale: Locale, row: types.StructureRow) -> Element(msg) {
  div([attribute.class("plan-work-summary")], [
    view_state_cell(locale, row),
    view_task_count_cell(row),
    view_pool_impact_cell(row),
    view_due_date_cell(row),
  ])
}

fn view_pool_impact_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, rollup:, ..) = row
  case card.state {
    card.Draft ->
      signal_chip.text(
        structure_presentation.draft_pool_impact_label(rollup),
        tone.Warning,
      )
      |> signal_chip.view
    _ -> element.none()
  }
}

fn view_due_date_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, ..) = row
  case card.due_date {
    Some(date) -> span([attribute.class("plan-due-date")], [text(date)])
    None -> element.none()
  }
}

fn view_actions_cell(
  config: Config(msg),
  row: types.StructureRow,
  render_context: String,
) -> Element(msg) {
  case config.move_mode {
    member_pool.PlanMovingCard(_, _) ->
      view_move_actions_cell(config, row, render_context)
    member_pool.PlanNotMoving ->
      view_normal_actions_cell(config, row, render_context)
  }
}

fn view_normal_actions_cell(
  config: Config(msg),
  row: types.StructureRow,
  _render_context: String,
) -> Element(msg) {
  let types.CardRow(card:, actions:, ..) = row
  let primary_create = primary_create_action(actions)

  div([attribute.class("plan-row-actions")], [
    view_contextual_create_action(config, card, primary_create),
  ])
}

fn view_move_actions_cell(
  config: Config(msg),
  row: types.StructureRow,
  render_context: String,
) -> Element(msg) {
  let types.CardRow(card:, ..) = row

  div([attribute.class("plan-row-actions plan-row-move-actions")], [
    case
      structure_move.destination_state(
        config.cards,
        config.tasks,
        config.move_mode,
        config.move_drag_state,
        card,
      )
    {
      structure_move.MovingSource(is_dragging) ->
        view_move_source(config, card, render_context, is_dragging)
      structure_move.MoveTarget(structure_move.ValidDropTarget) ->
        view_move_here_button(config, card)
      structure_move.MoveTarget(structure_move.ActiveDropTarget) ->
        div([attribute.class("plan-drop-target-actions")], [
          span(
            [
              attribute.class("plan-drop-target-hint"),
              attribute.attribute("data-testid", "plan-drop-target-hint"),
            ],
            [text("Soltar dentro de " <> card.title)],
          ),
          view_move_here_button(config, card),
        ])
      structure_move.MoveTarget(structure_move.InvalidDropTarget(reason)) ->
        div(
          [
            attribute.class("plan-move-invalid"),
            attribute.attribute("data-testid", "plan-move-invalid"),
          ],
          [
            span([attribute.class("plan-move-invalid-label")], [
              text("No disponible"),
            ]),
            span([attribute.class("plan-move-invalid-reason")], [
              text(card_policy.move_blocked_reason_label(reason)),
            ]),
          ],
        )
      structure_move.MoveTarget(structure_move.NotDropTarget) -> element.none()
      structure_move.NotMoveCandidate -> element.none()
    },
  ])
}

fn view_move_here_button(config: Config(msg), card: Card) -> Element(msg) {
  ui_button.text(
    "Mover dentro",
    config.on_move_destination_selected(move_target.InsideCard(card.id)),
    ui_button.Primary,
    ui_button.EntityAction,
  )
  |> ui_button.with_size(ui_button.ExtraSmall)
  |> ui_button.with_disabled(config.move_in_flight)
  |> ui_button.with_testid("plan-move-here")
  |> ui_button.view
}

fn view_move_source(
  config: Config(msg),
  card: Card,
  render_context: String,
  is_dragging: Bool,
) -> Element(msg) {
  div([attribute.class("plan-move-source-actions")], [
    case render_context {
      "desktop" ->
        span(
          [
            attribute.class("plan-move-drag-handle"),
            attribute.attribute("data-testid", "plan-move-drag-handle"),
            attribute.attribute("role", "button"),
            attribute.attribute("tabindex", "0"),
            attribute.attribute("draggable", "true"),
            attribute.attribute("aria-label", "Arrastrar " <> card.title),
            attribute.attribute("title", "Arrastrar para mover"),
            on_drag_start(config.on_move_drag_started(card.id)),
            on_drag_end(config.on_move_drag_ended),
          ],
          [text("Arrastrar")],
        )
      _ -> element.none()
    },
    span(
      [
        attribute.class(source_chip_class(is_dragging)),
        attribute.attribute("data-testid", "plan-move-source"),
      ],
      [
        text(case is_dragging {
          True -> "Arrastrando"
          False -> "Moviendo"
        }),
      ],
    ),
  ])
}

fn view_contextual_create_action(
  config: Config(msg),
  card: Card,
  planned: Option(types.PlannedAction),
) -> Element(msg) {
  case planned {
    Some(action) -> {
      let types.PlannedAction(action: action_kind, availability:) = action
      let #(label, msg) = action_event(config, card, action_kind)
      let #(disabled, title) = availability_attrs(availability)

      ui_button.icon_text(
        label,
        msg,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
      |> ui_button.with_size(ui_button.ExtraSmall)
      |> ui_button.with_disabled(disabled)
      |> ui_button.with_tooltip(contextual_action_title(label, title))
      |> ui_button.with_testid("plan-action-contextual-create")
      |> ui_button.with_class("plan-contextual-create-btn")
      |> ui_button.view
    }
    None -> element.none()
  }
}

fn contextual_action_title(label: String, title: String) -> String {
  case title {
    "" -> label
    _ -> title
  }
}

fn primary_create_action(
  actions: List(types.PlannedAction),
) -> Option(types.PlannedAction) {
  case find_available_action(actions, types.CreateSubcard) {
    Some(action) -> Some(action)
    None -> find_available_action(actions, types.CreateTask)
  }
}

fn find_available_action(
  actions: List(types.PlannedAction),
  target: types.CardAction,
) -> Option(types.PlannedAction) {
  case
    list.find(actions, fn(planned) {
      let types.PlannedAction(action:, availability:) = planned
      action == target && availability == types.Available
    })
  {
    Ok(action) -> Some(action)
    Error(_) -> None
  }
}

fn view_detail(
  config: Config(msg),
  detail: types.StructureDetail,
) -> Element(msg) {
  let #(card, title, body) = case detail {
    types.SubcardsDetail(card, subcards, rollup) -> #(
      card,
      "Contenido: subtarjetas",
      view_detail_subcards(config, subcards, rollup),
    )
    types.TasksDetail(card, tasks, rollup) -> #(
      card,
      "Contenido: tareas",
      view_detail_tasks(config.locale, tasks, rollup),
    )
    types.EmptyCardContent(card, rollup) -> #(
      card,
      "Contenido",
      view_detail_empty(rollup),
    )
  }
  let direct_subcards = card_queries.direct_child_cards(card.id, config.cards)
  let direct_tasks = card_queries.direct_child_tasks(card.id, config.tasks)
  let rollup = detail_rollup(detail)

  div(
    [
      attribute.class("plan-structure-detail"),
      attribute.attribute("data-testid", "plan-structure-detail"),
    ],
    [
      div([attribute.class("plan-detail-heading")], [
        h4([], [text(card.title)]),
        span([], [
          text(
            structure_presentation.card_state_label(config.locale, card)
            <> " - "
            <> level_label(config, card),
          ),
        ]),
      ]),
      div([attribute.class("plan-detail-path")], [
        text(card_queries.card_path(card, config.cards)),
      ]),
      view_detail_context(config, card, direct_subcards, direct_tasks, rollup),
      view_detail_rollup(card, rollup),
      h4([attribute.class("plan-detail-section-title")], [text(title)]),
      body,
      div([attribute.class("plan-detail-actions")], [
        view_detail_action(config, card, types.CreateSubcard),
        view_detail_action(config, card, types.CreateTask),
        view_detail_action(config, card, types.ActivateSubtree),
        view_detail_action(config, card, types.MoveCard),
        view_detail_action(config, card, types.CloseCard),
        view_detail_action(config, card, types.DeleteCard),
      ]),
    ],
  )
}

fn view_detail_context(
  config: Config(msg),
  card: Card,
  direct_subcards: List(Card),
  direct_tasks: List(domain_task.Task),
  rollup: types.CardRollup,
) -> Element(msg) {
  div([attribute.class("plan-detail-context")], [
    div([attribute.class("plan-detail-context-item")], [
      span([], [text("Nivel")]),
      strong([], [text(level_label(config, card))]),
    ]),
    div([attribute.class("plan-detail-context-item")], [
      span([], [text("Hijas")]),
      strong([], [text(int.to_string(list.length(direct_subcards)))]),
    ]),
    div([attribute.class("plan-detail-context-item")], [
      span([], [text("Tareas directas")]),
      strong([], [text(int.to_string(list.length(direct_tasks)))]),
    ]),
    div([attribute.class("plan-detail-context-item")], [
      span([], [text("Tareas descendientes")]),
      strong([], [text(int.to_string(rollup.total_tasks))]),
    ]),
  ])
}

fn view_detail_subcards(
  config: Config(msg),
  subcards: List(Card),
  _rollup: types.CardRollup,
) -> Element(msg) {
  ul(
    [attribute.class("plan-detail-list")],
    list.map(subcards, fn(card) {
      li([], [
        button(
          [
            attribute.type_("button"),
            attribute.class("plan-detail-link"),
            event.on_click(config.on_card_click(card.id)),
          ],
          [text(card.title)],
        ),
        span([], [
          text(structure_presentation.card_state_label(config.locale, card)),
        ]),
      ])
    }),
  )
}

fn view_detail_tasks(
  locale: Locale,
  tasks: List(domain_task.Task),
  _rollup: types.CardRollup,
) -> Element(msg) {
  ul(
    [attribute.class("plan-detail-list")],
    list.map(tasks, fn(task) {
      li([], [
        span([attribute.class("plan-detail-task-title")], [text(task.title)]),
        span([], [
          text(task_status_utils.label(
            locale,
            task_execution_state.to_status(task.state),
          )),
        ]),
      ])
    }),
  )
}

fn view_detail_empty(_rollup: types.CardRollup) -> Element(msg) {
  div([attribute.class("plan-detail-empty")], [
    p([], [text("Esta tarjeta no contiene subtarjetas ni tareas directas.")]),
  ])
}

fn view_detail_rollup(card: Card, rollup: types.CardRollup) -> Element(msg) {
  div(
    [attribute.class("plan-detail-rollup")],
    list.append(
      [
        signal_chip.metric_int("tareas", rollup.total_tasks, tone.Neutral)
          |> signal_chip.view,
        signal_chip.metric_int(
          "disponibles",
          rollup.available_tasks,
          tone.Available,
        )
          |> signal_chip.view,
        signal_chip.metric_int("bloqueadas", rollup.blocked_tasks, tone.Blocked)
          |> signal_chip.view,
      ],
      view_detail_pool_impact(card, rollup),
    ),
  )
}

fn view_detail_pool_impact(
  card: Card,
  rollup: types.CardRollup,
) -> List(Element(msg)) {
  case card.state {
    card.Draft -> [
      signal_chip.text(
        structure_presentation.draft_pool_impact_label(rollup),
        tone.Warning,
      )
      |> signal_chip.view,
    ]
    _ -> []
  }
}

fn view_detail_action(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> Element(msg) {
  let availability = action_availability(config, card, action)
  let #(label, msg) = action_event(config, card, action)
  let #(disabled, title) = availability_attrs(availability)

  case disabled {
    True -> element.none()
    False -> view_detail_action_button(action, label, title, msg)
  }
}

fn view_detail_action_button(
  action: types.CardAction,
  label: String,
  title: String,
  msg: msg,
) -> Element(msg) {
  detail_action_button_config(action, label, msg)
  |> ui_button.with_size(ui_button.ExtraSmall)
  |> ui_button.with_tooltip(contextual_action_title(label, title))
  |> ui_button.with_testid(structure_policy.action_testid(action))
  |> ui_button.view
}

fn detail_action_button_config(
  action: types.CardAction,
  label: String,
  msg: msg,
) -> ui_button.Config(msg) {
  case action {
    types.CreateSubcard ->
      ui_button.icon_text(
        label,
        msg,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
    types.CreateTask ->
      ui_button.icon_text(
        label,
        msg,
        icons.Plus,
        ui_button.Secondary,
        ui_button.EntityAction,
      )
    types.ActivateSubtree ->
      ui_button.text(label, msg, ui_button.Primary, ui_button.EntityAction)
    types.MoveCard ->
      ui_button.text(label, msg, ui_button.Secondary, ui_button.EntityAction)
    types.CloseCard ->
      ui_button.text(label, msg, ui_button.Secondary, ui_button.EntityAction)
    types.DeleteCard ->
      ui_button.text(label, msg, ui_button.Danger, ui_button.EntityAction)
  }
}

fn view_empty_state(config: Config(msg)) -> Element(msg) {
  let #(title, body, show_create) = case
    config.scope_kind,
    config.selected_card_id
  {
    member_pool.PlanScopeCard, None -> #(
      i18n.t(config.locale, i18n_text.PlanScopeSelectCard),
      i18n.t(config.locale, i18n_text.PlanEmptyCardScopeBody),
      False,
    )
    _, _ -> #(
      i18n.t(config.locale, i18n_text.PlanEmptyScopeTitle),
      i18n.t(config.locale, i18n_text.PlanEmptyScopeBody),
      config.is_pm_or_admin,
    )
  }

  div(
    [
      attribute.class("plan-structure-empty"),
      attribute.attribute("data-testid", "plan-structure-empty"),
    ],
    [
      h4([], [text(title)]),
      p([], [text(body)]),
      case show_create {
        True ->
          ui_button.icon_text(
            "Subtarjeta",
            config.on_create_subcard(0),
            icons.Plus,
            ui_button.Secondary,
            ui_button.ViewAction,
          )
          |> ui_button.with_testid("plan-empty-create-subcard")
          |> ui_button.with_class("plan-contextual-create-btn")
          |> ui_button.view
        False -> element.none()
      },
    ],
  )
}

fn structure_rows(
  config: Config(msg),
  include_closed: Bool,
) -> List(types.StructureRow) {
  case config.scope_kind, config.selected_depth, config.selected_card_id {
    member_pool.PlanScopeCard, _, None -> []
    _, _, _ -> {
      let cards = visible_cards(config, include_closed)
      let scoped_cards =
        card_queries.cards_for_scope(
          cards,
          config.scope_kind,
          config.selected_depth,
          config.selected_card_id,
        )
        |> list.filter(fn(card) { matches_status(config, card) })
        |> list.filter(fn(card) { matches_search(config, card) })

      case config.scope_kind, config.selected_depth {
        member_pool.PlanScopeLevel, Some(_) ->
          scoped_cards
          |> list.sort(fn(a, b) { compare_cards(config, cards, a, b) })
          |> list.map(fn(card) { row_for_card(config, card, 1, []) })
        _, _ ->
          roots_for_scope(scoped_cards, config)
          |> list.flat_map(fn(card) {
            tree_rows(config, scoped_cards, card, 1, [], None)
          })
      }
    }
  }
}

fn tree_rows(
  config: Config(msg),
  scoped_cards: List(Card),
  card: Card,
  depth: Int,
  prefix: List(types.TreeRail),
  branch: Option(Bool),
) -> List(types.StructureRow) {
  let children =
    scoped_cards
    |> list.filter(fn(child) {
      structure_tree.nearest_visible_parent_id(
        child,
        scoped_cards,
        config.cards,
      )
      == Some(card.id)
    })
    |> list.sort(fn(a, b) { compare_cards(config, config.cards, a, b) })

  case is_collapsed(config, card.id) {
    True -> [row_for_card(config, card, depth, row_outline(prefix, branch))]
    False -> [
      row_for_card(config, card, depth, row_outline(prefix, branch)),
      ..child_tree_rows(
        config,
        scoped_cards,
        children,
        depth + 1,
        child_prefix(prefix, branch),
      )
    ]
  }
}

fn child_tree_rows(
  config: Config(msg),
  scoped_cards: List(Card),
  children: List(Card),
  depth: Int,
  prefix: List(types.TreeRail),
) -> List(types.StructureRow) {
  case children {
    [] -> []
    [child] -> tree_rows(config, scoped_cards, child, depth, prefix, Some(True))
    [child, ..rest] ->
      list.append(
        tree_rows(config, scoped_cards, child, depth, prefix, Some(False)),
        child_tree_rows(config, scoped_cards, rest, depth, prefix),
      )
  }
}

fn row_outline(
  prefix: List(types.TreeRail),
  branch: Option(Bool),
) -> List(types.TreeRail) {
  case branch {
    None -> []
    Some(True) -> list.append(prefix, [types.TreeEnd])
    Some(False) -> list.append(prefix, [types.TreeElbow])
  }
}

fn child_prefix(
  prefix: List(types.TreeRail),
  branch: Option(Bool),
) -> List(types.TreeRail) {
  case branch {
    None -> []
    Some(True) -> list.append(prefix, [types.TreeBlank])
    Some(False) -> list.append(prefix, [types.TreeContinue])
  }
}

fn roots_for_scope(cards: List(Card), config: Config(msg)) -> List(Card) {
  case config.scope_kind, config.selected_card_id {
    member_pool.PlanScopeCard, Some(card_id) ->
      list.filter(cards, fn(card) { card.id == card_id })
    _, _ -> {
      case
        list.filter(cards, fn(card) {
          structure_tree.nearest_visible_parent_id(card, cards, config.cards)
          == None
        })
      {
        [] -> card_queries.top_level_cards(cards)
        roots -> roots
      }
      |> list.sort(fn(a, b) { compare_cards(config, config.cards, a, b) })
    }
  }
}

fn row_for_card(
  config: Config(msg),
  card: Card,
  relative_depth: Int,
  outline: List(types.TreeRail),
) -> types.StructureRow {
  let absolute_depth = card_queries.card_depth(card, config.cards)
  types.CardRow(
    depth: relative_depth,
    outline: outline,
    card: card,
    path: card_queries.parent_path(card, config.cards),
    level_name: card_queries.depth_singular_label(
      config.depth_names,
      absolute_depth,
    ),
    rollup: structure_rollups.for_card(card, config.cards, config.tasks),
    actions: list.map(structure_policy.card_actions(), fn(action) {
      types.PlannedAction(
        action: action,
        availability: action_availability(config, card, action),
      )
    }),
  )
}

fn structure_detail(
  config: Config(msg),
  include_closed: Bool,
  rows: List(types.StructureRow),
) -> Option(types.StructureDetail) {
  case config.scope_kind, config.selected_card_id {
    member_pool.PlanScopeCard, Some(card_id) ->
      case
        list.find(visible_cards(config, include_closed), fn(card) {
          card.id == card_id
        })
      {
        Ok(card) -> Some(detail_for_card(config, card))
        Error(_) -> None
      }
    _, _ ->
      case rows {
        [types.CardRow(card:, ..), ..] ->
          case is_collapsed(config, card.id) {
            True -> None
            False -> Some(detail_for_card(config, card))
          }
        [] -> None
      }
  }
}

fn detail_for_card(config: Config(msg), card: Card) -> types.StructureDetail {
  let subcards = card_queries.direct_child_cards(card.id, config.cards)
  let tasks = card_queries.direct_child_tasks(card.id, config.tasks)
  let rollup = structure_rollups.for_card(card, config.cards, config.tasks)

  case subcards, tasks {
    [_, ..], _ -> types.SubcardsDetail(card, subcards, rollup)
    [], [_, ..] -> types.TasksDetail(card, tasks, rollup)
    [], [] -> types.EmptyCardContent(card, rollup)
  }
}

fn include_closed(config: Config(msg)) -> Bool {
  structure_filters.include_closed(
    config.show_closed,
    config.cards,
    config.tasks,
    config.scope_kind,
    config.selected_card_id,
  )
}

fn visible_cards(config: Config(msg), include_closed: Bool) -> List(Card) {
  structure_filters.visible_cards(config.cards, include_closed)
}

fn matches_search(config: Config(msg), card: Card) -> Bool {
  structure_filters.matches_search(config.search_query, config.cards, card)
}

fn matches_status(config: Config(msg), card: Card) -> Bool {
  structure_filters.matches_status(config.status_filter, card)
}

fn compare_cards(config: Config(msg), cards: List(Card), a: Card, b: Card) {
  structure_filters.compare_cards(config.sort_order, cards, config.tasks, a, b)
}

fn is_collapsed(config: Config(msg), card_id: Int) -> Bool {
  structure_filters.is_collapsed(config.collapsed_card_ids, card_id)
}

fn action_availability(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> types.ActionAvailability {
  structure_policy.action_availability(
    config.is_pm_or_admin,
    config.cards,
    config.tasks,
    card,
    action,
  )
}

fn move_row_class(config: Config(msg), row: types.StructureRow) -> String {
  structure_move.row_state_for_row(
    config.cards,
    config.tasks,
    config.move_mode,
    config.move_drag_state,
    row,
  )
  |> structure_move.row_class
}

fn first_column_label(config: Config(msg)) -> String {
  case config.scope_kind, config.selected_depth {
    member_pool.PlanScopeLevel, Some(depth) ->
      card_queries.depth_singular_label(config.depth_names, depth)
    _, _ -> "Tarjeta / Árbol"
  }
}

fn action_event(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> #(String, msg) {
  case action {
    types.CreateSubcard -> #("Subtarjeta", config.on_create_subcard(card.id))
    types.CreateTask -> #("Tarea", config.on_create_task_in_card(card.id))
    types.ActivateSubtree -> #(
      "Activar subárbol",
      config.on_card_click(card.id),
    )
    types.MoveCard -> #("Mover a...", config.on_move_requested(card.id))
    types.CloseCard -> #("Cerrar", config.on_card_click(card.id))
    types.DeleteCard -> #("Eliminar", config.on_card_delete(card.id))
  }
}

fn availability_attrs(availability: types.ActionAvailability) -> #(Bool, String) {
  case availability {
    types.Available -> #(False, "")
    types.Disabled(reason) -> #(True, reason)
  }
}

fn source_chip_class(is_dragging: Bool) -> String {
  case is_dragging {
    True -> "plan-move-source-chip is-dragging"
    False -> "plan-move-source-chip"
  }
}

fn move_drop_attributes(config: Config(msg), card: Card) {
  case
    structure_move.destination_state(
      config.cards,
      config.tasks,
      config.move_mode,
      config.move_drag_state,
      card,
    )
  {
    structure_move.MoveTarget(structure_move.ValidDropTarget)
    | structure_move.MoveTarget(structure_move.ActiveDropTarget) -> [
      on_drag_enter(
        config.on_move_drag_entered(move_target.InsideCard(card.id)),
      ),
      on_drag_over(config.on_move_drag_entered(move_target.InsideCard(card.id))),
      on_drop(config.on_move_dropped(move_target.InsideCard(card.id))),
    ]
    structure_move.MoveTarget(structure_move.InvalidDropTarget(_)) -> [
      on_drag_enter(
        config.on_move_drag_entered(move_target.InsideCard(card.id)),
      ),
    ]
    structure_move.MoveTarget(structure_move.NotDropTarget)
    | structure_move.MovingSource(_)
    | structure_move.NotMoveCandidate -> []
  }
}

fn on_drag_start(msg: msg) -> attribute.Attribute(msg) {
  event.advanced("dragstart", {
    decode.success(event.handler(
      msg,
      prevent_default: False,
      stop_propagation: True,
    ))
  })
}

fn on_drag_enter(msg: msg) -> attribute.Attribute(msg) {
  event.advanced("dragenter", {
    decode.success(event.handler(
      msg,
      prevent_default: False,
      stop_propagation: True,
    ))
  })
}

fn on_drag_over(msg: msg) -> attribute.Attribute(msg) {
  event.advanced("dragover", {
    decode.success(event.handler(
      msg,
      prevent_default: True,
      stop_propagation: True,
    ))
  })
}

fn on_drop(msg: msg) -> attribute.Attribute(msg) {
  event.advanced("drop", {
    decode.success(event.handler(
      msg,
      prevent_default: True,
      stop_propagation: True,
    ))
  })
}

fn on_drag_end(msg: msg) -> attribute.Attribute(msg) {
  event.advanced("dragend", {
    decode.success(event.handler(
      msg,
      prevent_default: False,
      stop_propagation: True,
    ))
  })
}

fn detail_rollup(detail: types.StructureDetail) -> types.CardRollup {
  case detail {
    types.SubcardsDetail(rollup: rollup, ..) -> rollup
    types.TasksDetail(rollup: rollup, ..) -> rollup
    types.EmptyCardContent(rollup: rollup, ..) -> rollup
  }
}

fn row_key(row: types.StructureRow) -> String {
  let types.CardRow(card:, ..) = row
  int.to_string(card.id)
}

fn level_label(config: Config(msg), card: Card) -> String {
  card_queries.depth_singular_label(
    config.depth_names,
    card_queries.card_depth(card, config.cards),
  )
}
