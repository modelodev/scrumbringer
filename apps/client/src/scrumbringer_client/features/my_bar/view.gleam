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
//// - Personal metrics panel (claimed/released/completed counts)
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
//// - **client_state.gleam**: Provides Model and Msg types
//// - **update_helpers.gleam**: Provides helper functions
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
import lustre/element/html.{
  button, div, h2, h3, p, span, table, tbody, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import domain/metrics.{MyMetrics}
import domain/task.{type Task, Task}
import domain/task_status.{
  type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,
}
import domain/user.{type User}

import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberClaimClicked,
  MemberCompleteClicked, MemberNowWorkingPauseClicked,
  MemberNowWorkingStartClicked, MemberReleaseClicked, NotAsked, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme
import scrumbringer_client/ui/card_badge
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// Re-export view_task_type_icon_inline from client_view for internal use
// This function is needed for rendering task type icons in the bar

/// Renders the My Bar section with claimed tasks and metrics.
pub fn view_bar(model: Model, user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ ->
      case model.member_tasks {
        NotAsked | Loading ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])

        // MB01: Error display with banner
        Failed(err) ->
          div([attribute.class("error-banner")], [
            span([attribute.class("error-banner-icon")], [
              icons.nav_icon(icons.Warning, icons.Small),
            ]),
            span([], [text(err.message)]),
          ])

        Loaded(tasks) -> {
          let mine =
            tasks
            |> list.filter(fn(t) {
              let Task(claimed_by: claimed_by, ..) = t
              claimed_by == opt.Some(user.id)
            })
            |> list.sort(by: compare_member_bar_tasks)

          div([attribute.class("section")], [
            view_member_metrics_panel(model),
            case mine {
              // MB02: Improved empty state using empty_state component
              [] ->
                empty_state.new(
                  icons.Backpack,
                  update_helpers.i18n_t(model, i18n_text.NoClaimedTasks),
                  update_helpers.i18n_t(model, i18n_text.GoToPoolToClaimTasks),
                )
                |> empty_state.view

              _ -> view_tasks_grouped_by_card(model, user, mine)
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
    card_color: opt.Option(String),
    tasks: List(Task),
  )
}

/// Groups tasks by card_id and renders them with collapsible headers.
fn view_tasks_grouped_by_card(
  model: Model,
  user: User,
  tasks: List(Task),
) -> Element(Msg) {
  // Group tasks by card_id
  let groups = group_tasks_by_card(tasks)

  div(
    [attribute.class("my-bar-card-groups")],
    list.map(groups, fn(g) { view_card_group(model, user, g) }),
  )
}

/// Group tasks by their card_id, keeping order stable.
fn group_tasks_by_card(tasks: List(Task)) -> List(CardGroup) {
  // First, separate tasks with cards from those without
  let #(with_card, without_card) =
    list.partition(tasks, fn(t) {
      let Task(card_id: card_id, ..) = t
      opt.is_some(card_id)
    })

  // Group tasks with cards by card_id
  let card_groups =
    with_card
    |> list.group(fn(t) {
      let Task(card_id: card_id, ..) = t
      opt.unwrap(card_id, 0)
    })
    |> dict.to_list()
    |> list.map(fn(pair) {
      let #(_card_id, card_tasks) = pair
      // Get card info from first task in group
      case card_tasks {
        [first, ..] -> {
          let Task(
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

/// Render a single card group with header and task list.
fn view_card_group(model: Model, user: User, group: CardGroup) -> Element(Msg) {
  let CardGroup(
    card_id: _card_id,
    card_title: card_title,
    card_color: card_color,
    tasks: tasks,
  ) = group

  let card_color_opt = case card_color {
    opt.None -> opt.None
    opt.Some(c) -> color_picker.string_to_color(c)
  }

  let border_class = color_picker.border_class(card_color_opt)

  let total = list.length(tasks)
  let completed =
    list.count(tasks, fn(t) {
      let Task(status: status, ..) = t
      status == Completed
    })

  let header_title = case card_title {
    opt.Some(title) -> title
    opt.None -> update_helpers.i18n_t(model, i18n_text.UngroupedTasks)
  }

  div([attribute.class("my-bar-card-group " <> border_class)], [
    // Group header
    div([attribute.class("my-bar-card-header")], [
      // Card badge (only if has card)
      case card_title {
        opt.Some(ct) -> card_badge.view(ct, card_color_opt, opt.None)
        opt.None -> element.none()
      },
      // Card title
      span([attribute.class("my-bar-card-title")], [text(header_title)]),
      // Progress count
      span([attribute.class("my-bar-card-progress")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.CardProgressCount(completed, total),
        )),
      ]),
    ]),
    // Task list
    keyed.div(
      [attribute.class("task-list")],
      list.map(tasks, fn(t) {
        let Task(id: task_id, ..) = t
        #(int.to_string(task_id), view_member_bar_task_row(model, user, t))
      }),
    ),
  ])
}

/// Renders the personal metrics panel.
pub fn view_member_metrics_panel(model: Model) -> Element(Msg) {
  case model.member_metrics {
    NotAsked | Loading ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        div([attribute.class("loading")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingMetrics)),
        ]),
      ])

    Failed(err) ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        div([attribute.class("error")], [text(err.message)]),
      ])

    Loaded(metrics) -> {
      let MyMetrics(
        window_days: window_days,
        claimed_count: claimed_count,
        released_count: released_count,
        completed_count: completed_count,
      ) = metrics

      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.MyMetrics))]),
        p([], [
          text(update_helpers.i18n_t(model, i18n_text.WindowDays(window_days))),
        ]),
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
            ]),
          ]),
          tbody([], [
            tr([], [
              td([], [text(int.to_string(claimed_count))]),
              td([], [text(int.to_string(released_count))]),
              td([], [text(int.to_string(completed_count))]),
            ]),
          ]),
        ]),
      ])
    }
  }
}

/// Render a task row for the bar/list view mode.
pub fn view_member_bar_task_row(
  model: Model,
  user: User,
  task: Task,
) -> Element(Msg) {
  let Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: priority,
    status: status,
    created_at: _created_at,
    version: version,
    claimed_by: claimed_by,
    ..,
  ) = task

  let is_mine = claimed_by == opt.Some(user.id)

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let disable_actions =
    model.member_task_mutation_in_flight || model.member_now_working_in_flight

  let claim_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Claim),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Claim),
        ),
        event.on_click(pool_msg(MemberClaimClicked(id, version))),
        attribute.disabled(disable_actions),
      ],
      [icons.nav_icon(icons.HandRaised, icons.Small)],
    )

  let release_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute(
          "data-tooltip",
          update_helpers.i18n_t(model, i18n_text.Release),
        ),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Release),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Release),
        ),
        event.on_click(pool_msg(MemberReleaseClicked(id, version))),
        attribute.disabled(disable_actions),
      ],
      [icons.nav_icon(icons.Refresh, icons.Small)],
    )

  let complete_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute(
          "data-tooltip",
          update_helpers.i18n_t(model, i18n_text.Complete),
        ),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Complete),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Complete),
        ),
        event.on_click(pool_msg(MemberCompleteClicked(id, version))),
        attribute.disabled(disable_actions),
      ],
      [icons.nav_icon(icons.CheckCircle, icons.Small)],
    )

  let start_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.StartNowWorking),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.StartNowWorking),
        ),
        event.on_click(pool_msg(MemberNowWorkingStartClicked(id))),
        attribute.disabled(disable_actions),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.Start))],
    )

  let pause_action =
    button(
      [
        attribute.class("btn-xs"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.PauseNowWorking),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.PauseNowWorking),
        ),
        event.on_click(pool_msg(MemberNowWorkingPauseClicked)),
        attribute.disabled(disable_actions),
      ],
      [text(update_helpers.i18n_t(model, i18n_text.Pause))],
    )

  let is_active =
    update_helpers.now_working_active_task_id(model) == opt.Some(id)

  let now_working_action = case is_active {
    True -> pause_action
    False -> start_action
  }

  let actions = case status, is_mine {
    Available, _ -> [claim_action]
    Claimed(_), True -> [now_working_action, release_action, complete_action]
    _, _ -> []
  }

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(update_helpers.i18n_t(model, i18n_text.PriorityShort(priority))),
        text(" · "),
        case type_icon {
          opt.Some(icon) ->
            span([attribute.attribute("style", "margin-right:4px;")], [
              view_task_type_icon_inline(icon, 16, model.theme),
            ])
        },
        text(type_label),
      ]),
    ]),
    div([attribute.class("task-row-actions")], actions),
  ])
}

fn heroicon_outline_url(name: String) -> String {
  "https://unpkg.com/heroicons@2.1.0/24/outline/" <> name <> ".svg"
}

/// Inline heroicon for task type display.
fn view_heroicon_inline(
  name: String,
  size: Int,
  current_theme: theme.Theme,
) -> Element(Msg) {
  let url = heroicon_outline_url(name)

  let style = case current_theme {
    theme.Dark ->
      "vertical-align:middle; opacity:0.9; filter: invert(1) brightness(1.2);"
    theme.Default -> "vertical-align:middle; opacity:0.85;"
  }

  element.element(
    "img",
    [
      attribute.attribute("src", url),
      attribute.attribute("alt", name <> " icon"),
      attribute.attribute("width", int.to_string(size)),
      attribute.attribute("height", int.to_string(size)),
      attribute.attribute("style", style),
    ],
    [],
  )
}

/// Render task type icon using the icon catalog.
/// Falls back to CDN or text for icons not in catalog.
fn view_task_type_icon_inline(
  icon: String,
  size: Int,
  current_theme: theme.Theme,
) -> Element(Msg) {
  case string.is_empty(icon) {
    True -> element.none()
    False ->
      case icon_catalog.exists(icon) {
        True -> {
          let class = case current_theme {
            theme.Dark -> "icon-theme-dark"
            theme.Default -> ""
          }
          icon_catalog.render_with_class(icon, size, class)
        }
        False ->
          case string.contains(icon, "-") {
            True -> view_heroicon_inline(icon, size, current_theme)
            False ->
              span(
                [
                  attribute.attribute(
                    "style",
                    "font-size:" <> int.to_string(size) <> "px;",
                  ),
                ],
                [text(icon)],
              )
          }
      }
  }
}

/// Status rank for sorting (lower = higher priority).
pub fn member_bar_status_rank(status: TaskStatus) -> Int {
  case status {
    Claimed(Ongoing) -> 0
    Claimed(Taken) -> 1
    Available -> 2
    Completed -> 3
  }
}

/// Compare tasks for bar sorting (priority desc, status, created desc).
pub fn compare_member_bar_tasks(a: Task, b: Task) -> order.Order {
  let Task(priority: priority_a, status: status_a, created_at: created_at_a, ..) =
    a
  let Task(priority: priority_b, status: status_b, created_at: created_at_b, ..) =
    b

  case int.compare(priority_b, priority_a) {
    order.Eq ->
      case
        int.compare(
          member_bar_status_rank(status_a),
          member_bar_status_rank(status_b),
        )
      {
        order.Eq -> string.compare(created_at_b, created_at_a)
        other -> other
      }

    other -> other
  }
}
