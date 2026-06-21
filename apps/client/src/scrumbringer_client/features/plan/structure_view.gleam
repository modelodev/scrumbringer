//// Plan / Structure explorer.

import domain/card.{type Card, Active, Closed, Draft}
import domain/task.{type Task}
import domain/task_status.{Available, Claimed, Done, Ongoing, Taken}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, li, p, span, text, ul}
import lustre/event

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/features/plan/types
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone
import scrumbringer_client/utils/card_queries

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    tasks: List(Task),
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    show_closed: Option(Bool),
    search_query: String,
    is_pm_or_admin: Bool,
    plan_mode: member_pool.PlanMode,
    on_plan_mode_change: fn(String) -> msg,
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_closed_toggled: fn(Bool) -> msg,
    on_card_click: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
    on_create_task_in_card: fn(Int) -> msg,
    on_create_subcard: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let include_closed = include_closed(config)
  let rows = structure_rows(config, include_closed)
  let summary = summary_for_rows(rows, config)
  let detail = structure_detail(config, include_closed)

  div(
    [
      attribute.class("plan-structure-view"),
      attribute.attribute("data-testid", "plan-structure-view"),
    ],
    [
      view_surface_header(config, summary, include_closed),
      case rows {
        [] -> view_empty_state(config)
        _ -> view_body(config, rows, detail)
      },
    ],
  )
}

fn view_surface_header(
  config: Config(msg),
  summary: types.CardRollup,
  include_closed: Bool,
) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: "Plan",
    purpose: "Estructura de cards y trabajo preparado.",
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.KanbanSummaryCards),
        int.to_string(list.length(visible_cards(config, include_closed))),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        "Tasks",
        int.to_string(summary.total_tasks),
        tone.Neutral,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.MetricsAvailable),
        int.to_string(summary.available_tasks),
        tone.Available,
      ),
      work_surface.summary_chip(
        "Entrarian al pool",
        int.to_string(summary.pool_impact),
        tone.Warning,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.Blocked),
        int.to_string(summary.blocked_tasks),
        tone.Blocked,
      ),
    ],
    actions: [],
    extra_class: Some("plan-structure-header"),
    testid: Some("plan-structure-header"),
  ))
  |> with_scope_bar(config, include_closed)
}

fn with_scope_bar(
  header: Element(msg),
  config: Config(msg),
  include_closed: Bool,
) -> Element(msg) {
  div([attribute.class("plan-scope-shell")], [
    header,
    scope_bar.view(scope_bar.Config(
      locale: config.locale,
      cards: config.cards,
      depth_names: config.depth_names,
      scope_kind: config.scope_kind,
      selected_depth: config.selected_depth,
      selected_card_id: config.selected_card_id,
      show_closed: include_closed,
      id_prefix: "plan-structure",
      mode_controls: plan_mode_controls(config),
      on_scope_kind_change: config.on_scope_kind_change,
      on_scope_depth_change: config.on_scope_depth_change,
      on_scope_card_change: config.on_scope_card_change,
      on_closed_toggled: config.on_closed_toggled,
    )),
  ])
}

fn plan_mode_controls(config: Config(msg)) -> List(scope_bar.ModeControl(msg)) {
  [
    plan_mode_control(config, i18n_text.PlanModeStructure, "structure"),
    plan_mode_control(config, i18n_text.PlanModeKanban, "kanban"),
  ]
}

fn plan_mode_control(
  config: Config(msg),
  label_key: i18n_text.Text,
  value: String,
) -> scope_bar.ModeControl(msg) {
  scope_bar.ModeControl(
    label: i18n.t(config.locale, label_key),
    value: value,
    active: plan_mode_value(config.plan_mode) == value,
    testid: "plan-mode-" <> value,
    on_select: config.on_plan_mode_change(value),
  )
}

fn view_body(
  config: Config(msg),
  rows: List(types.StructureRow),
  detail: Option(types.StructureDetail),
) -> Element(msg) {
  case detail {
    Some(value) ->
      div([attribute.class("plan-structure-split")], [
        view_table(config, rows),
        view_detail(config, value),
      ])
    None -> view_table(config, rows)
  }
}

fn view_table(
  config: Config(msg),
  rows: List(types.StructureRow),
) -> Element(msg) {
  data_table.new()
  |> data_table.with_class("plan-structure-table")
  |> data_table.with_caption("Plan structure")
  |> data_table.with_columns([
    data_table.column_with_class(
      first_column_label(config),
      fn(row) { view_tree_cell(config, row) },
      "plan-col-tree",
      "plan-cell-tree",
    ),
    data_table.column("Estado", fn(row) { view_state_cell(row) }),
    data_table.column("Tasks", fn(row) { view_task_count_cell(row) }),
    data_table.column("Pool impact", fn(row) { view_pool_impact_cell(row) }),
    data_table.column("Vence", fn(row) { view_due_date_cell(row) }),
    data_table.column_with_class(
      "Acciones",
      fn(row) { view_actions_cell(config, row) },
      "plan-col-actions",
      "plan-cell-actions",
    ),
  ])
  |> data_table.with_rows(rows, row_key)
  |> data_table.view
}

fn view_tree_cell(config: Config(msg), row: types.StructureRow) -> Element(msg) {
  let types.CardRow(depth:, card:, path:, level_name:, ..) = row
  let indent = int.to_string({ depth - 1 } * 16)
  button(
    [
      attribute.type_("button"),
      attribute.class("plan-tree-trigger"),
      attribute.style("padding-left", indent <> "px"),
      attribute.attribute("data-testid", "plan-structure-row-trigger"),
      attribute.attribute("title", path),
      event.on_click(config.on_card_click(card.id)),
    ],
    [
      span([attribute.class("plan-tree-marker")], [
        text(tree_marker(config, card)),
      ]),
      span([attribute.class("plan-tree-title")], [text(card.title)]),
      span([attribute.class("plan-tree-level")], [text(level_name)]),
      case path {
        "" -> element.none()
        _ -> span([attribute.class("plan-tree-path")], [text(path)])
      },
    ],
  )
}

fn view_state_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, ..) = row
  signal_chip.text(card_state_label(card), card_state_tone(card))
  |> signal_chip.with_class("plan-state-chip")
  |> signal_chip.view
}

fn view_task_count_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(rollup:, ..) = row
  span([attribute.class("plan-task-count")], [
    text(
      int.to_string(rollup.completed_tasks)
      <> "/"
      <> int.to_string(rollup.total_tasks),
    ),
  ])
}

fn view_pool_impact_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, rollup:, ..) = row
  let label = case card.state {
    Draft -> "+" <> int.to_string(rollup.pool_impact)
    Active -> "ya activo"
    Closed -> "cerrada"
  }
  let tone_value = case card.state {
    Draft -> tone.Warning
    Active -> tone.Available
    Closed -> tone.Neutral
  }
  signal_chip.text(label, tone_value)
  |> signal_chip.with_class("plan-pool-chip")
  |> signal_chip.view
}

fn view_due_date_cell(row: types.StructureRow) -> Element(msg) {
  let types.CardRow(card:, ..) = row
  case card.due_date {
    Some(date) -> span([attribute.class("plan-due-date")], [text(date)])
    None -> span([attribute.class("plan-due-date is-empty")], [text("-")])
  }
}

fn view_actions_cell(
  config: Config(msg),
  row: types.StructureRow,
) -> Element(msg) {
  let types.CardRow(card:, actions:, ..) = row
  div([attribute.class("plan-row-actions")], [
    button(
      [
        attribute.type_("button"),
        attribute.class("plan-action-btn"),
        attribute.attribute("data-testid", "plan-card-detail-action"),
        event.on_click(config.on_card_click(card.id)),
      ],
      [text("Ver")],
    ),
    ..list.map(actions, fn(action) { view_compact_action(config, card, action) })
  ])
}

fn view_compact_action(
  config: Config(msg),
  card: Card,
  planned: types.PlannedAction,
) -> Element(msg) {
  let types.PlannedAction(action:, availability:) = planned
  let #(label, msg) = action_event(config, card, action)
  let #(disabled, title) = availability_attrs(availability)

  button(
    [
      attribute.type_("button"),
      attribute.class(action_class(action)),
      attribute.attribute("data-testid", action_testid(action)),
      attribute.attribute("title", title),
      attribute.disabled(disabled),
      event.on_click(msg),
    ],
    [text(label)],
  )
}

fn view_detail(
  config: Config(msg),
  detail: types.StructureDetail,
) -> Element(msg) {
  let #(card, title, body) = case detail {
    types.SubcardsDetail(card, subcards, rollup) -> #(
      card,
      "Contenido: subcards",
      view_detail_subcards(config, subcards, rollup),
    )
    types.TasksDetail(card, tasks, rollup) -> #(
      card,
      "Contenido: tasks",
      view_detail_tasks(tasks, rollup),
    )
    types.EmptyCardDetail(card, rollup) -> #(
      card,
      "Contenido",
      view_detail_empty(rollup),
    )
  }

  div(
    [
      attribute.class("plan-structure-detail"),
      attribute.attribute("data-testid", "plan-structure-detail"),
    ],
    [
      div([attribute.class("plan-detail-heading")], [
        h4([], [text(card.title)]),
        span([], [
          text(card_state_label(card) <> " - " <> level_label(config, card)),
        ]),
      ]),
      div([attribute.class("plan-detail-path")], [
        text(card_queries.card_path(card, config.cards)),
      ]),
      view_detail_rollup(card, detail_rollup(detail)),
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
        span([], [text(card_state_label(card))]),
      ])
    }),
  )
}

fn view_detail_tasks(
  tasks: List(Task),
  _rollup: types.CardRollup,
) -> Element(msg) {
  ul(
    [attribute.class("plan-detail-list")],
    list.map(tasks, fn(task) {
      li([], [
        span([attribute.class("plan-detail-task-title")], [text(task.title)]),
        span([], [text(task_status_label(task))]),
      ])
    }),
  )
}

fn view_detail_empty(_rollup: types.CardRollup) -> Element(msg) {
  div([attribute.class("plan-detail-empty")], [
    p([], [text("Esta card no contiene subcards ni tasks directas.")]),
  ])
}

fn view_detail_rollup(card: Card, rollup: types.CardRollup) -> Element(msg) {
  div([attribute.class("plan-detail-rollup")], [
    signal_chip.metric_int("tasks", rollup.total_tasks, tone.Neutral)
      |> signal_chip.view,
    signal_chip.metric_int(
      "disponibles",
      rollup.available_tasks,
      tone.Available,
    )
      |> signal_chip.view,
    signal_chip.metric_int("bloqueadas", rollup.blocked_tasks, tone.Blocked)
      |> signal_chip.view,
    signal_chip.text(pool_impact_label(card, rollup), tone.Warning)
      |> signal_chip.view,
  ])
}

fn view_detail_action(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> Element(msg) {
  let availability = action_availability(config, card, action)
  let #(label, msg) = action_event(config, card, action)
  let #(disabled, title) = availability_attrs(availability)

  button(
    [
      attribute.type_("button"),
      attribute.class(action_class(action)),
      attribute.attribute("data-testid", action_testid(action)),
      attribute.attribute("title", title),
      attribute.disabled(disabled),
      event.on_click(msg),
    ],
    [text(label)],
  )
}

fn view_empty_state(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("plan-structure-empty"),
      attribute.attribute("data-testid", "plan-structure-empty"),
    ],
    [
      h4([], [text("No hay cards en este scope.")]),
      p([], [
        text(
          "Crea una card o cambia el scope para revisar otra parte del plan.",
        ),
      ]),
      case config.is_pm_or_admin {
        True ->
          button(
            [
              attribute.type_("button"),
              attribute.class("plan-action-btn plan-action-primary"),
              event.on_click(config.on_create_subcard(0)),
            ],
            [text("+ Subcard")],
          )
        False -> element.none()
      },
    ],
  )
}

fn structure_rows(
  config: Config(msg),
  include_closed: Bool,
) -> List(types.StructureRow) {
  let cards = visible_cards(config, include_closed)
  let scoped_cards =
    card_queries.cards_for_scope(
      cards,
      config.scope_kind,
      config.selected_depth,
      config.selected_card_id,
    )
    |> list.filter(fn(card) { matches_search(config, card) })

  case config.scope_kind, config.selected_depth, config.selected_card_id {
    member_pool.PlanScopeLevel, Some(_), _ ->
      scoped_cards
      |> list.sort(fn(a, b) {
        string.compare(
          card_queries.card_path(a, cards),
          card_queries.card_path(b, cards),
        )
      })
      |> list.map(fn(card) { row_for_card(config, card, 1) })
    _, _, _ ->
      roots_for_scope(scoped_cards, config)
      |> list.flat_map(fn(card) { tree_rows(config, scoped_cards, card, 1) })
  }
}

fn tree_rows(
  config: Config(msg),
  scoped_cards: List(Card),
  card: Card,
  depth: Int,
) -> List(types.StructureRow) {
  let children =
    scoped_cards
    |> list.filter(fn(child) { child.parent_card_id == Some(card.id) })
    |> list.sort(fn(a, b) { string.compare(a.title, b.title) })
  [
    row_for_card(config, card, depth),
    ..list.flat_map(children, fn(child) {
      tree_rows(config, scoped_cards, child, depth + 1)
    })
  ]
}

fn roots_for_scope(cards: List(Card), config: Config(msg)) -> List(Card) {
  case config.scope_kind, config.selected_card_id {
    member_pool.PlanScopeCard, Some(card_id) ->
      list.filter(cards, fn(card) { card.id == card_id })
    _, _ -> {
      let card_ids = list.map(cards, fn(card) { card.id })
      case
        list.filter(cards, fn(card) {
          case card.parent_card_id {
            None -> True
            Some(parent_id) -> !list.contains(card_ids, parent_id)
          }
        })
      {
        [] -> card_queries.top_level_cards(cards)
        roots -> roots
      }
    }
  }
}

fn row_for_card(
  config: Config(msg),
  card: Card,
  relative_depth: Int,
) -> types.StructureRow {
  let absolute_depth = card_queries.card_depth(card, config.cards)
  types.CardRow(
    depth: relative_depth,
    card: card,
    path: card_queries.parent_path(card, config.cards),
    level_name: card_queries.depth_singular_label(
      config.depth_names,
      absolute_depth,
    ),
    rollup: rollup_for_card(card, config.cards, config.tasks),
    actions: list.map(card_actions(), fn(action) {
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
    _, _ -> None
  }
}

fn detail_for_card(config: Config(msg), card: Card) -> types.StructureDetail {
  let subcards = card_queries.direct_child_cards(card.id, config.cards)
  let tasks = card_queries.direct_child_tasks(card.id, config.tasks)
  let rollup = rollup_for_card(card, config.cards, config.tasks)

  case subcards, tasks {
    [_, ..], _ -> types.SubcardsDetail(card, subcards, rollup)
    [], [_, ..] -> types.TasksDetail(card, tasks, rollup)
    [], [] -> types.EmptyCardDetail(card, rollup)
  }
}

fn summary_for_rows(
  rows: List(types.StructureRow),
  config: Config(msg),
) -> types.CardRollup {
  let row_cards =
    rows
    |> list.map(fn(row) {
      let types.CardRow(card:, ..) = row
      card
    })

  let tasks =
    config.tasks
    |> list.filter(fn(task) {
      list.any(row_cards, fn(card) {
        card_queries.task_in_card_subtree(task, card.id, config.cards)
      })
    })

  let rollup = rollup_for_tasks(tasks)
  types.CardRollup(
    ..rollup,
    pool_impact: list.count(tasks, fn(task) {
      task.status == Available
      && list.any(row_cards, fn(card) {
        card.state == Draft
        && card_queries.task_in_card_subtree(task, card.id, config.cards)
      })
    }),
  )
}

fn rollup_for_tasks(tasks: List(Task)) -> types.CardRollup {
  types.CardRollup(
    total_tasks: list.length(tasks),
    completed_tasks: list.count(tasks, fn(task) { task.status == Done }),
    available_tasks: list.count(tasks, fn(task) { task.status == Available }),
    claimed_tasks: list.count(tasks, fn(task) { task.status == Claimed(Taken) }),
    ongoing_tasks: list.count(tasks, fn(task) {
      task.status == Claimed(Ongoing)
    }),
    blocked_tasks: list.count(tasks, fn(task) { task.blocked_count > 0 }),
    pool_impact: 0,
  )
}

fn rollup_pool_impact(card: Card, tasks: List(Task)) -> Int {
  case card.state {
    Draft -> list.count(tasks, fn(task) { task.status == Available })
    Active | Closed -> 0
  }
}

fn rollup_for_card(
  card: Card,
  cards: List(Card),
  tasks: List(Task),
) -> types.CardRollup {
  let card_tasks =
    tasks
    |> list.filter(fn(task) {
      card_queries.task_in_card_subtree(task, card.id, cards)
    })

  let rollup = rollup_for_tasks(card_tasks)
  types.CardRollup(..rollup, pool_impact: rollup_pool_impact(card, card_tasks))
}

fn include_closed(config: Config(msg)) -> Bool {
  case config.show_closed {
    Some(value) -> value
    None ->
      card_queries.closed_default_for_scope(
        config.cards,
        config.tasks,
        config.scope_kind,
        config.selected_card_id,
      )
  }
}

fn visible_cards(config: Config(msg), include_closed: Bool) -> List(Card) {
  case include_closed {
    True -> config.cards
    False -> list.filter(config.cards, fn(card) { card.state != Closed })
  }
}

fn matches_search(config: Config(msg), card: Card) -> Bool {
  let query = string.lowercase(string.trim(config.search_query))
  case query {
    "" -> True
    _ -> {
      let haystack =
        string.lowercase(
          card.title <> " " <> card_queries.card_path(card, config.cards),
        )
      string.contains(haystack, query)
    }
  }
}

fn first_column_label(config: Config(msg)) -> String {
  case config.scope_kind, config.selected_depth {
    member_pool.PlanScopeLevel, Some(depth) ->
      card_queries.depth_singular_label(config.depth_names, depth)
    _, _ -> "Card / Arbol"
  }
}

fn tree_marker(config: Config(msg), card: Card) -> String {
  case card_queries.direct_child_cards(card.id, config.cards) {
    [] -> "o"
    _ -> "v"
  }
}

fn card_actions() -> List(types.CardAction) {
  [
    types.CreateSubcard,
    types.CreateTask,
    types.ActivateSubtree,
    types.MoveCard,
    types.CloseCard,
    types.DeleteCard,
  ]
}

fn action_availability(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> types.ActionAvailability {
  let has_subcards =
    card_queries.direct_child_cards(card.id, config.cards) != []
  let has_direct_tasks =
    card_queries.direct_child_tasks(card.id, config.tasks) != []
  case action {
    types.CreateSubcard ->
      case config.is_pm_or_admin, has_direct_tasks {
        False, _ -> types.Disabled("Solo managers pueden modificar estructura")
        _, True -> types.Disabled("Esta card ya contiene tasks directas")
        _, False -> types.Available
      }
    types.CreateTask ->
      case has_subcards {
        True -> types.Disabled("Esta card contiene subcards")
        False -> types.Available
      }
    types.ActivateSubtree ->
      case config.is_pm_or_admin, card.state {
        False, _ -> types.Disabled("Solo managers pueden activar subarboles")
        _, Draft -> types.Available
        _, Active -> types.Disabled("Ya activo")
        _, Closed -> types.Disabled("La card esta cerrada")
      }
    types.MoveCard ->
      case config.is_pm_or_admin {
        True -> types.Available
        False -> types.Disabled("Solo managers pueden mover cards")
      }
    types.CloseCard ->
      case
        config.is_pm_or_admin,
        has_claimed_or_ongoing_descendants(config, card)
      {
        False, _ -> types.Disabled("Solo managers pueden cerrar cards")
        _, True -> types.Disabled("Hay tasks reclamadas o en curso debajo")
        _, False -> types.Available
      }
    types.DeleteCard ->
      case has_subcards || has_direct_tasks || card.task_count > 0 {
        True ->
          types.Disabled("Tiene historial operativo; cierrala en su lugar")
        False -> types.Available
      }
  }
}

fn has_claimed_or_ongoing_descendants(config: Config(msg), card: Card) -> Bool {
  config.tasks
  |> list.filter(fn(task) {
    card_queries.task_in_card_subtree(task, card.id, config.cards)
  })
  |> list.any(fn(task) {
    case task.status {
      Claimed(Taken) | Claimed(Ongoing) -> True
      _ -> False
    }
  })
}

fn action_event(
  config: Config(msg),
  card: Card,
  action: types.CardAction,
) -> #(String, msg) {
  case action {
    types.CreateSubcard -> #("+ Subcard", config.on_create_subcard(card.id))
    types.CreateTask -> #("+ Task", config.on_create_task_in_card(card.id))
    types.ActivateSubtree -> #("Activar", config.on_card_edit(card.id))
    types.MoveCard -> #("Mover a...", config.on_card_edit(card.id))
    types.CloseCard -> #("Cerrar", config.on_card_edit(card.id))
    types.DeleteCard -> #("Eliminar", config.on_card_delete(card.id))
  }
}

fn availability_attrs(availability: types.ActionAvailability) -> #(Bool, String) {
  case availability {
    types.Available -> #(False, "")
    types.Disabled(reason) -> #(True, reason)
  }
}

fn action_class(action: types.CardAction) -> String {
  case action {
    types.CreateSubcard -> "plan-action-btn"
    types.CreateTask -> "plan-action-btn"
    types.ActivateSubtree -> "plan-action-btn"
    types.MoveCard -> "plan-action-btn"
    types.CloseCard -> "plan-action-btn"
    types.DeleteCard -> "plan-action-btn plan-action-danger"
  }
}

fn action_testid(action: types.CardAction) -> String {
  case action {
    types.CreateSubcard -> "plan-action-create-subcard"
    types.CreateTask -> "plan-action-create-task"
    types.ActivateSubtree -> "plan-action-activate-subtree"
    types.MoveCard -> "plan-action-move-card"
    types.CloseCard -> "plan-action-close-card"
    types.DeleteCard -> "plan-action-delete-card"
  }
}

fn detail_rollup(detail: types.StructureDetail) -> types.CardRollup {
  case detail {
    types.SubcardsDetail(rollup: rollup, ..) -> rollup
    types.TasksDetail(rollup: rollup, ..) -> rollup
    types.EmptyCardDetail(rollup: rollup, ..) -> rollup
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

fn card_state_label(card: Card) -> String {
  case card.state {
    Draft -> "Draft"
    Active -> "Active"
    Closed -> "Closed"
  }
}

fn card_state_tone(card: Card) -> tone.Tone {
  case card.state {
    Draft -> tone.Warning
    Active -> tone.Available
    Closed -> tone.Neutral
  }
}

fn task_status_label(task: Task) -> String {
  case task.status {
    Available -> "disponible"
    Claimed(Taken) -> "reclamada"
    Claimed(Ongoing) -> "en curso"
    Done -> "completada"
  }
}

fn pool_impact_label(card: Card, rollup: types.CardRollup) -> String {
  case card.state {
    Draft -> "+" <> int.to_string(rollup.pool_impact) <> " al pool"
    Active -> "ya activo"
    Closed -> "cerrada"
  }
}

fn plan_mode_value(mode: member_pool.PlanMode) -> String {
  case mode {
    member_pool.PlanStructure -> "structure"
    member_pool.PlanKanban -> "kanban"
  }
}
