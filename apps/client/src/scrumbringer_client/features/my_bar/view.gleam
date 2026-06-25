//// My Bar views for claimed task list and personal metrics.
////
//// ## Mission
////
//// Renders the "My Bar" section showing the user's claimed tasks
//// and personal metrics summary.
////
//// ## Responsibilities
////
//// - List of user's claimed tasks with actions
//// - Personal metrics panel (claimed/released/closed counts)
//// - Task row rendering with action buttons
//// - Task sorting by priority and status
////
//// ## Non-responsibilities
////
//// - Task state management (see client_state.gleam)
//// - API calls (see api/ modules)
//// - Pool/canvas views (see pool/view.gleam)
////
//// ## Relations
////
//// - **client_view.gleam**: Main view imports this for member section
//// - **client_state.gleam**: Root assembler provides Config data and callbacks
//// - **features/pool/view.gleam**: Reuses task row rendering
////
//// ## Line Count Justification
////
//// This module groups tightly related views for the personal task bar:
//// main view, task row, metrics panel, and sorting helpers.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/order
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, h3, p, span, text}
import lustre/element/keyed

import domain/card
import domain/metrics.{type MyMetrics, MyMetrics, window_days_value}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task as domain_task
import domain/task/state as task_state

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/card_badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/icons

import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/task_type_icon

pub type Config(msg) {
  Config(
    locale: Locale,
    has_active_projects: Bool,
    member_tasks: Remote(List(domain_task.Task)),
    member_metrics: Remote(MyMetrics),
    task_row_config: TaskRowConfig(msg),
    on_create_task_in_card: fn(Int) -> msg,
  )
}

pub type TaskRowConfig(msg) {
  TaskRowConfig(
    locale: Locale,
    theme: Theme,
    user_id: Int,
    active_task_id: opt.Option(Int),
    disable_actions: Bool,
    task_card_info: fn(domain_task.Task) ->
      #(opt.Option(String), opt.Option(card.CardColor)),
    on_claim: fn(Int, Int) -> msg,
    on_start: fn(Int) -> msg,
    on_pause: msg,
    on_release: fn(Int, Int) -> msg,
    on_close: fn(Int, Int) -> msg,
    on_task_open: fn(Int) -> msg,
  )
}

/// Renders the My Bar section with claimed tasks and metrics.
pub fn view_bar(config: Config(msg)) -> Element(msg) {
  case config.has_active_projects {
    False ->
      div([attribute.class("empty")], [
        h2([], [text(i18n.t(config.locale, i18n_text.NoProjectsYet))]),
        p([], [text(i18n.t(config.locale, i18n_text.NoProjectsBody))]),
      ])

    True ->
      case config.member_tasks {
        NotAsked | Loading ->
          div([attribute.class("empty")], [
            text(i18n.t(config.locale, i18n_text.LoadingEllipsis)),
          ])

        // MB01: Error display with banner
        Failed(err) -> error_notice.view(err.message)

        Loaded(tasks) -> {
          let mine =
            tasks
            |> list.filter(fn(t) {
              case t.state {
                task_state.Claimed(claimed_by: claimed_by, ..) ->
                  claimed_by == config.task_row_config.user_id
                _ -> False
              }
            })
            |> list.sort(by: compare_member_bar_tasks)

          div([attribute.class("section")], [
            view_member_metrics_panel(config.locale, config.member_metrics),
            case mine {
              // MB02: Improved empty state using empty_state component
              [] ->
                empty_state.new(
                  "archive-box",
                  i18n.t(config.locale, i18n_text.NoClaimedTasks),
                  i18n.t(config.locale, i18n_text.GoToPoolToClaimTasks),
                )
                |> empty_state.view

              _ -> view_tasks_grouped_by_card(config, mine)
            },
          ])
        }
      }
  }
}

/// A card group with its tasks.
type CardGroup {
  CardGroup(
    card_id: opt.Option(Int),
    card_title: opt.Option(String),
    card_color: opt.Option(card.CardColor),
    tasks: List(domain_task.Task),
  )
}

/// Groups tasks by card_id and renders them with collapsible headers.
fn view_tasks_grouped_by_card(
  config: Config(msg),
  tasks: List(domain_task.Task),
) -> Element(msg) {
  // Group tasks by card_id
  let groups = group_tasks_by_card(tasks)

  div(
    [attribute.class("my-bar-card-groups")],
    list.map(groups, fn(g) { view_card_group(config, g) }),
  )
}

/// Group tasks by their card_id, keeping order stable.
fn group_tasks_by_card(tasks: List(domain_task.Task)) -> List(CardGroup) {
  // First, separate tasks with cards from those without
  let #(with_card, without_card) =
    list.partition(tasks, fn(t) {
      let domain_task.Task(card_id: card_id, ..) = t
      opt.is_some(card_id)
    })

  // Group tasks with cards by card_id
  let card_groups =
    with_card
    |> list.group(fn(t) {
      let domain_task.Task(card_id: card_id, ..) = t
      grouped_card_id(card_id)
    })
    |> dict.to_list()
    |> list.map(fn(pair) {
      let #(_card_id, card_tasks) = pair
      // Get card info from first task in group
      case card_tasks {
        [first, ..] -> {
          let domain_task.Task(
            card_id: card_id,
            card_title: card_title,
            card_color: card_color,
            ..,
          ) = first
          CardGroup(
            card_id: card_id,
            card_title: card_title,
            card_color: card_color,
            tasks: card_tasks,
          )
        }
        [] ->
          CardGroup(
            card_id: opt.None,
            card_title: opt.None,
            card_color: opt.None,
            tasks: [],
          )
      }
    })
    |> list.filter(fn(g) { !list.is_empty(g.tasks) })

  // Create ungrouped section for tasks without cards
  let ungrouped_group = case without_card {
    [] -> []
    tasks_without_card -> [
      CardGroup(
        card_id: opt.None,
        card_title: opt.None,
        card_color: opt.None,
        tasks: tasks_without_card,
      ),
    ]
  }

  // Return cards first, then ungrouped
  list.append(card_groups, ungrouped_group)
}

fn grouped_card_id(card_id: opt.Option(Int)) -> Int {
  case card_id {
    opt.Some(id) -> id
    opt.None -> 0
  }
}

/// Render a single card group with header and task list.
fn view_card_group(config: Config(msg), group: CardGroup) -> Element(msg) {
  let CardGroup(
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
    tasks: tasks,
  ) = group

  let border_class = task_color.card_border_class(card_color)

  let total = list.length(tasks)
  let closed =
    list.count(tasks, fn(t) {
      case t.state {
        task_state.Closed(..) -> True
        _ -> False
      }
    })

  let header_title = case card_title {
    opt.Some(title) -> title
    opt.None -> i18n.t(config.locale, i18n_text.UngroupedTasks)
  }

  div([attribute.class("my-bar-card-group " <> border_class)], [
    // Group header
    div([attribute.class("my-bar-card-header")], [
      // Card badge (only if has card)
      case card_title {
        opt.Some(ct) -> card_badge.view(ct, card_color, opt.None)
        opt.None -> element.none()
      },
      // Card title
      span([attribute.class("my-bar-card-title")], [text(header_title)]),
      // Progress count
      span([attribute.class("my-bar-card-progress")], [
        text(i18n.t(config.locale, i18n_text.CardProgressCount(closed, total))),
      ]),
      // [+] button to create task in this card (Story 4.12 AC8-9, AC16)
      case card_id, card_title {
        opt.Some(id), opt.Some(title) ->
          action_buttons.add_icon_button_with_size_and_testid(
            i18n.t(config.locale, i18n_text.NewTaskInCard(title)),
            config.on_create_task_in_card(id),
            action_buttons.SizeSm,
            icons.Plus,
            opt.None,
            opt.Some("my-bar-add-task"),
          )
        _, _ -> element.none()
      },
    ]),
    // Task list
    keyed.div(
      [attribute.class("task-list")],
      list.map(tasks, fn(t) {
        let domain_task.Task(id: task_id, ..) = t
        #(
          int.to_string(task_id),
          view_member_bar_task_row(config.task_row_config, t),
        )
      }),
    ),
  ])
}

/// Renders the personal metrics panel.
pub fn view_member_metrics_panel(
  locale: Locale,
  member_metrics: Remote(MyMetrics),
) -> Element(msg) {
  let t = fn(key) { i18n.t(locale, key) }

  case member_metrics {
    NotAsked | Loading ->
      div([attribute.class("panel")], [
        h3([], [text(t(i18n_text.MyMetrics))]),
        div([attribute.class("loading")], [
          text(t(i18n_text.LoadingMetrics)),
        ]),
      ])

    Failed(err) ->
      div([attribute.class("panel")], [
        h3([], [text(t(i18n_text.MyMetrics))]),
        error_notice.view(err.message),
      ])

    Loaded(metrics) -> {
      let MyMetrics(
        window_days: window_days,
        claimed_count: claimed_count,
        released_count: released_count,
        closed_count: closed_count,
      ) = metrics

      div([attribute.class("panel")], [
        h3([], [text(t(i18n_text.MyMetrics))]),
        p([], [
          text(t(i18n_text.WindowDays(window_days_value(window_days)))),
        ]),
        data_table.new()
          |> data_table.with_columns([
            data_table.column(t(i18n_text.Claimed), fn(_) {
              text(int.to_string(claimed_count))
            }),
            data_table.column(t(i18n_text.Released), fn(_) {
              text(int.to_string(released_count))
            }),
            data_table.column(t(i18n_text.Closed), fn(_) {
              text(int.to_string(closed_count))
            }),
          ])
          |> data_table.with_rows([metrics], fn(_) { "metrics" })
          |> data_table.view(),
      ])
    }
  }
}

/// Render a task row for the bar/list view mode.
pub fn view_member_bar_task_row(
  config: TaskRowConfig(msg),
  task: domain_task.Task,
) -> Element(msg) {
  let domain_task.Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: priority,
    created_at: _created_at,
    version: version,
    card_id: _card_id,
    card_title: card_title,
    card_color: card_color,
    ..,
  ) = task
  let type_label = task_type.name

  let type_icon = task_type.icon

  let #(resolved_card_title, resolved_card_color) = config.task_card_info(task)
  let card_title_opt = case card_title {
    opt.Some(ct) -> opt.Some(ct)
    opt.None -> resolved_card_title
  }
  let card_color_opt = case card_title {
    opt.Some(_) -> card_color
    opt.None -> resolved_card_color
  }

  let card_badge_el = case card_title_opt {
    opt.Some(ct) -> card_badge.view(ct, card_color_opt, opt.Some(ct))
    opt.None -> element.none()
  }

  let claim_action =
    task_actions.claim_only(
      task_state_ui.claim_action(config.locale),
      config.on_claim(id, version),
      action_buttons.SizeXs,
      config.disable_actions,
      "",
      opt.None,
      opt.None,
    )

  let start_action =
    task_actions.text_action(
      i18n.t(config.locale, i18n_text.Start),
      config.on_start(id),
      "btn-xs",
      task_state_ui.start_action(config.locale),
      config.disable_actions,
    )

  let pause_action =
    task_actions.text_action(
      i18n.t(config.locale, i18n_text.Pause),
      config.on_pause,
      "btn-xs",
      task_state_ui.pause_action(config.locale),
      config.disable_actions,
    )

  let is_active = config.active_task_id == opt.Some(id)
  let now_working_action = case is_active {
    True -> pause_action
    False -> start_action
  }

  let actions = case task.state {
    task_state.Available -> claim_action
    task_state.Claimed(claimed_by: claimed_by, ..)
      if claimed_by == config.user_id
    -> [
      now_working_action,
      ..task_actions.release_and_close(
        task_state_ui.release_action(config.locale),
        config.on_release(id, version),
        task_state_ui.close_action(config.locale),
        config.on_close(id, version),
        action_buttons.SizeXs,
        config.disable_actions,
        "",
        "",
        opt.Some(task_state_ui.release_action(config.locale)),
        opt.Some(task_state_ui.close_action(config.locale)),
        opt.None,
        opt.None,
      )
    ]
    task_state.Claimed(..) | task_state.Closed(..) -> []
  }

  task_item.view(
    task_item.Config(
      container_class: "task-row",
      content_class: "task-row-title",
      leading: opt.None,
      on_click: opt.Some(config.on_task_open(id)),
      content_title: opt.None,
      content_label: opt.None,
      icon: opt.None,
      icon_class: opt.None,
      title: title,
      title_class: opt.None,
      secondary: div([attribute.class("task-row-meta")], [
        card_badge_el,
        span([attribute.attribute("style", "margin-right:4px;")], [
          task_type_icon.view(type_icon, 16, config.theme),
        ]),
        text(i18n.t(config.locale, i18n_text.PriorityShort(priority))),
        text(" · "),
        text(type_label),
      ]),
      actions: [div([attribute.class("task-row-actions")], actions)],
      reserve_actions_slot: False,
      action_slot_class: opt.None,
      content_testid: opt.None,
      testid: opt.None,
    ),
    task_item.Div,
  )
}

// Inline icon helper removed in favor of ui/task_type_icon.view

/// Status rank for sorting (lower = higher priority).
pub fn member_bar_status_rank(state: task_state.TaskExecutionState) -> Int {
  case state {
    task_state.Claimed(mode: task_state.Ongoing, ..) -> 0
    task_state.Claimed(mode: task_state.Taken, ..) -> 1
    task_state.Available -> 2
    task_state.Closed(..) -> 3
  }
}

/// Compare tasks for bar sorting (priority desc, status, created desc).
pub fn compare_member_bar_tasks(
  a: domain_task.Task,
  b: domain_task.Task,
) -> order.Order {
  let domain_task.Task(priority: priority_a, created_at: created_at_a, ..) = a
  let domain_task.Task(priority: priority_b, created_at: created_at_b, ..) = b
  case int.compare(priority_b, priority_a) {
    order.Eq ->
      case
        int.compare(
          member_bar_status_rank(a.state),
          member_bar_status_rank(b.state),
        )
      {
        order.Eq -> string.compare(created_at_b, created_at_a)
        other -> other
      }

    other -> other
  }
}
