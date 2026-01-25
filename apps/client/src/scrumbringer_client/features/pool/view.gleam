//// Pool View
////
//// View functions for the member pool section including task canvas,
//// task cards, and layout assembly.
////
//// ## Responsibilities
////
//// - Pool main layout and task canvas/list rendering
//// - Task card rendering with drag-drop support
//// - Right panel with claimed tasks dropzone
//// - Assembles filters and dialogs from submodules
////
//// ## Non-responsibilities
////
//// - Filter panel (see `features/pool/filters.gleam`)
//// - Dialogs (see `features/pool/dialogs.gleam`)
////
//// ## Relations
////
//// - **features/pool/filters.gleam**: Filter panel component
//// - **features/pool/dialogs.gleam**: Dialog components
//// - **features/pool/update.gleam**: State management

import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, h3, p, span, text}
import lustre/element/keyed
import lustre/event

import domain/task.{type Task, Task}
import domain/task_status.{Available, Claimed, Taken, task_status_to_string}
import domain/user.{type User}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberClaimClicked,
  MemberCompleteClicked, MemberCreateDialogOpened, MemberDragEnded,
  MemberDragMoved, MemberDragStarted, MemberReleaseClicked, NotAsked,
}
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/features/pool/filters as pool_filters
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_visuals
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/card_badge
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/update_helpers

// =============================================================================
// Types
// =============================================================================

/// State of available tasks after filtering.
///
/// Makes the task loading/filtering state explicit for cleaner view rendering.
type AvailableTasksState {
  TasksLoading
  TasksError(message: String)
  TasksEmpty(has_filters: Bool)
  TasksReady(tasks: List(Task))
}

/// Determines the current state of available tasks.
fn get_available_tasks_state(model: Model) -> AvailableTasksState {
  case model.member_tasks {
    NotAsked | Loading -> TasksLoading
    Failed(err) -> TasksError(err.message)
    Loaded(tasks) -> {
      let available =
        list.filter(tasks, fn(t) {
          let Task(status: status, ..) = t
          status == Available
        })
      case available {
        [] -> TasksEmpty(has_filters: has_active_filters(model))
        _ -> TasksReady(available)
      }
    }
  }
}

/// Checks if any filters are active.
fn has_active_filters(model: Model) -> Bool {
  string.trim(model.member_filters_type_id) != ""
  || string.trim(model.member_filters_capability_id) != ""
  || string.trim(model.member_filters_q) != ""
}

/// Renders the main pool section with filters, canvas/list toggle, and tasks.
pub fn view_pool_main(model: Model, _user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attrs.empty()], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ -> {
      div([attrs.section()], [
        // Unified toolbar: view mode, filters toggle, and new task - all in one row
        pool_filters.view_unified_toolbar(model),
        view_tasks(model),
        case model.member_create_dialog_open {
          True -> pool_dialogs.view_create_dialog(model)
          False -> element.none()
        },
        case model.member_notes_task_id {
          opt.Some(task_id) -> pool_dialogs.view_task_details(model, task_id)
          opt.None -> element.none()
        },
        case model.member_position_edit_task {
          opt.Some(task_id) -> pool_dialogs.view_position_edit(model, task_id)
          opt.None -> element.none()
        },
      ])
    }
  }
}

/// Renders the right panel with claimed tasks dropzone.
pub fn view_right_panel(model: Model, user: User) -> Element(Msg) {
  let dropzone_class = case
    model.member_pool_drag_to_claim_armed,
    model.member_pool_drag_over_my_tasks
  {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }

  let claimed_tasks = case model.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        let Task(status: status, claimed_by: claimed_by, ..) = t
        status == Claimed(Taken) && claimed_by == opt.Some(user.id)
      })
      |> list.sort(by: my_bar_view.compare_member_bar_tasks)

    _ -> []
  }

  div([], [
    // Now Working section (unified)
    now_working_panel.view(model),
    // My Tasks section with dropzone
    h3([], [text(update_helpers.i18n_t(model, i18n_text.MyTasks))]),
    div(
      [
        attribute.attribute("id", "pool-my-tasks"),
        attribute.class(dropzone_class),
      ],
      [
        case model.member_pool_drag_to_claim_armed {
          True ->
            div([attribute.class("dropzone-hint")], [
              text(
                update_helpers.i18n_t(model, i18n_text.Claim)
                <> ": "
                <> update_helpers.i18n_t(model, i18n_text.MyTasks),
              ),
            ])
          False -> element.none()
        },
        case claimed_tasks {
          // P03: Improved empty state for claimed tasks
          [] ->
            empty_state.simple(
              icons.Hand,
              update_helpers.i18n_t(model, i18n_text.NoClaimedTasks),
            )
          _ ->
            keyed.div(
              [attribute.class("task-list")],
              list.map(claimed_tasks, fn(t) {
                let Task(id: task_id, ..) = t
                #(
                  int.to_string(task_id),
                  my_bar_view.view_member_bar_task_row(model, user, t),
                )
              }),
            )
        },
      ],
    ),
  ])
}

/// Renders the pool body with mouse event handlers for drag-drop.
pub fn view_pool_body(model: Model, user: User) -> Element(Msg) {
  div(
    [
      attribute.class("pool-layout"),
      event.on("mousemove", {
        use x <- decode.field("clientX", decode.int)
        use y <- decode.field("clientY", decode.int)
        decode.success(MemberDragMoved(x, y))
      }),
      event.on("mouseup", decode.success(MemberDragEnded)),
      event.on("mouseleave", decode.success(MemberDragEnded)),
    ],
    [
      div([attribute.class("content pool-main")], [
        view_pool_main(model, user),
      ]),
      div([attribute.class("pool-right")], [view_right_panel(model, user)]),
    ],
  )
}

/// Renders the task list/canvas based on loading state and view mode.
///
/// Uses `AvailableTasksState` to flatten control flow from 5 levels to 1.
fn view_tasks(model: Model) -> Element(Msg) {
  case get_available_tasks_state(model) {
    TasksLoading -> view_tasks_loading(model)
    TasksError(message) -> view_tasks_error(message)
    TasksEmpty(has_filters: True) -> view_tasks_no_matches(model)
    TasksEmpty(has_filters: False) -> view_tasks_onboarding(model)
    TasksReady(tasks) -> view_tasks_collection(model, tasks)
  }
}

/// Loading state view.
fn view_tasks_loading(model: Model) -> Element(Msg) {
  div([attribute.class("empty")], [
    text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
  ])
}

/// Error state view.
fn view_tasks_error(message: String) -> Element(Msg) {
  div([attribute.class("error")], [text(message)])
}

/// No matches for current filters.
fn view_tasks_no_matches(model: Model) -> Element(Msg) {
  empty_state.simple(
    icons.Search,
    update_helpers.i18n_t(model, i18n_text.NoTasksMatchYourFilters),
  )
}

/// Onboarding empty state with CTA.
fn view_tasks_onboarding(model: Model) -> Element(Msg) {
  empty_state.new(
    icons.Target,
    update_helpers.i18n_t(model, i18n_text.NoAvailableTasksRightNow),
    update_helpers.i18n_t(model, i18n_text.CreateFirstTaskToStartUsingPool),
  )
  |> empty_state.with_action(
    update_helpers.i18n_t(model, i18n_text.NewTask),
    MemberCreateDialogOpened,
  )
  |> empty_state.view
}

/// Renders task collection in the selected view mode.
fn view_tasks_collection(model: Model, tasks: List(Task)) -> Element(Msg) {
  case model.member_pool_view_mode {
    pool_prefs.Canvas -> view_tasks_canvas(model, tasks)
    pool_prefs.List -> view_tasks_list(model, tasks)
  }
}

fn view_tasks_canvas(model: Model, tasks: List(Task)) -> Element(Msg) {
  keyed.div(
    [
      attribute.attribute("id", "member-canvas"),
      attribute.attribute(
        "style",
        "position: relative; min-height: 600px; touch-action: none;",
      ),
    ],
    list.map(tasks, fn(task) {
      let Task(id: id, ..) = task
      #(int.to_string(id), view_task_card(model, task))
    }),
  )
}

fn view_tasks_list(model: Model, tasks: List(Task)) -> Element(Msg) {
  keyed.div(
    [attribute.class("task-list")],
    list.map(tasks, fn(task) {
      let Task(id: id, ..) = task
      #(int.to_string(id), view_pool_task_row(model, task))
    }),
  )
}

/// Renders a task row in list view.
pub fn view_pool_task_row(model: Model, task: Task) -> Element(Msg) {
  let Task(
    id: id,
    title: title,
    type_id: _type_id,
    task_type: task_type,
    priority: priority,
    created_at: created_at,
    version: version,
    ..,
  ) = task

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let disable_actions = model.member_task_mutation_in_flight

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
        event.on_click(MemberClaimClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [icons.nav_icon(icons.HandRaised, icons.Small)],
    )

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(update_helpers.i18n_t(model, i18n_text.MetaType)),
        case type_icon {
          opt.Some(icon) ->
            span([attribute.attribute("style", "margin-right:4px;")], [
              admin_view.view_task_type_icon_inline(icon, 16, model.theme),
            ])
        },
        text(type_label),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaPriority)),
        text(int.to_string(priority)),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaCreated)),
        text(created_at),
      ]),
    ]),
    div([attribute.class("task-row-actions")], [claim_action]),
  ])
}

/// Renders a task card for the pool canvas view with drag-and-drop support.
pub fn view_task_card(model: Model, task: Task) -> Element(Msg) {
  let Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: priority,
    status: status,
    claimed_by: claimed_by,
    created_at: created_at,
    version: version,
    card_title: card_title,
    card_color: card_color,
    ..,
  ) = task

  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  let is_mine = claimed_by == opt.Some(current_user_id)

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  // Card color for border styling
  let card_color_opt = case card_color {
    opt.None -> opt.None
    opt.Some(c) -> color_picker.string_to_color(c)
  }
  let card_border_class = color_picker.border_class(card_color_opt)

  // Get saved position or generate deterministic initial position based on task ID
  let #(x, y) = case dict.get(model.member_positions_by_task, id) {
    Ok(xy) -> xy
    Error(_) -> {
      // Generate spread-out initial positions using task ID as seed
      // This ensures consistent initial layout that doesn't overlap
      let canvas_width = 700
      let canvas_height = 500
      let padding = 50
      // Use prime multipliers for better distribution
      let initial_x =
        { { id * 137 } % { canvas_width - padding } } + { padding / 2 }
      let initial_y =
        { { id * 89 } % { canvas_height - padding } } + { padding / 2 }
      #(initial_x, initial_y)
    }
  }

  let size = member_visuals.priority_to_px(priority)

  let age_days = age_in_days(created_at)

  let #(opacity, saturation) = decay_to_visuals(age_days)

  let prefer_left = x > 760

  // Build CSS classes including card border color
  let base_classes = case prefer_left {
    True -> "task-card preview-left"
    False -> "task-card"
  }
  let card_classes = case card_border_class {
    "" -> base_classes
    c -> base_classes <> " " <> c
  }

  let style =
    "position:absolute; left:"
    <> int.to_string(x)
    <> "px; top:"
    <> int.to_string(y)
    <> "px; width:"
    <> int.to_string(size)
    <> "px; height:"
    <> int.to_string(size)
    <> "px; opacity:"
    <> float.to_string(opacity)
    <> "; filter:saturate("
    <> float.to_string(saturation)
    <> ");"

  let disable_actions = model.member_task_mutation_in_flight

  let primary_action = case status, is_mine {
    Available, _ ->
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
          event.on_click(MemberClaimClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [icons.nav_icon(icons.HandRaised, icons.Small)],
      )

    Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          event.on_click(MemberReleaseClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [icons.nav_icon(icons.Refresh, icons.Small)],
      )

    _, _ -> element.none()
  }

  let drag_handle =
    button(
      [
        attribute.class("btn-xs btn-icon secondary-action drag-handle"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Drag),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Drag),
        ),
        attribute.attribute("type", "button"),
        event.on("mousedown", {
          use ox <- decode.field("offsetX", decode.int)
          use oy <- decode.field("offsetY", decode.int)
          decode.success(MemberDragStarted(id, ox, oy))
        }),
      ],
      [icons.nav_icon(icons.DragHandle, icons.Small)],
    )

  let complete_action = case status, is_mine {
    Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon secondary-action"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          event.on_click(MemberCompleteClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [icons.nav_icon(icons.CheckCircle, icons.Small)],
      )

    _, _ -> element.none()
  }

  div(
    [
      attribute.class(card_classes),
      attribute.attribute("style", style),
      attribute.attribute(
        "aria-describedby",
        "task-preview-" <> int.to_string(id),
      ),
    ],
    [
      div([attribute.class("task-card-top")], [
        // Card initials badge if task belongs to a card
        case card_title {
          opt.Some(ct) -> card_badge.view(ct, card_color_opt, opt.Some(ct))
          opt.None -> element.none()
        },
        // P02: Decay badge showing age
        case age_days > 7 {
          True ->
            span(
              [
                attribute.class("decay-badge"),
                attribute.attribute(
                  "title",
                  update_helpers.i18n_t(
                    model,
                    i18n_text.CreatedAgoDays(age_days),
                  ),
                ),
              ],
              [text(int.to_string(age_days) <> "d")],
            )
          False -> element.none()
        },
        div([attribute.class("task-card-actions")], [
          primary_action,
          drag_handle,
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        div([attribute.class("task-card-center")], [
          case type_icon {
            opt.Some(icon) ->
              div([attribute.class("task-card-center-icon")], [
                admin_view.view_task_type_icon_inline(icon, 22, model.theme),
              ])
          },
          div(
            [
              attribute.class("task-card-title"),
              attribute.attribute("title", title),
            ],
            [text(title)],
          ),
        ]),
      ]),
      div(
        [
          attribute.class("task-card-preview"),
          attribute.attribute("id", "task-preview-" <> int.to_string(id)),
          attribute.attribute("role", "tooltip"),
        ],
        [
          div([attribute.class("task-preview-grid")], [
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverType)),
            ]),
            span([attribute.class("task-preview-value")], [text(type_label)]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverCreated)),
            ]),
            span([attribute.class("task-preview-value")], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.CreatedAgoDays(age_days),
              )),
            ]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverStatus)),
            ]),
            span([attribute.class("task-preview-value")], [
              span(
                [
                  attribute.class(
                    "task-preview-badge task-preview-badge-"
                    <> task_status_to_string(status),
                  ),
                ],
                [text(task_status_to_string(status))],
              ),
            ]),
          ]),
        ],
      ),
    ],
  )
}

// --- Helpers ---

fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}

fn decay_to_visuals(age_days: Int) -> #(Float, Float) {
  case age_days {
    d if d < 9 -> #(1.0, 1.0)
    d if d < 18 -> #(0.95, 0.85)
    d if d < 27 -> #(0.85, 0.65)
    _ -> #(0.8, 0.55)
  }
}
