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
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, h3, p, text}
import lustre/element/keyed
import lustre/event

import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task, Task, TaskNote}
import domain/task_state
import domain/task_status.{Available, Claimed, Completed, Taken}
import domain/user.{type User}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, MemberClaimClicked, MemberCompleteClicked,
  MemberCreateDialogOpened, MemberDragEnded, MemberDragMoved, MemberDragStarted,
  MemberPoolTouchEnded, MemberPoolTouchStarted, MemberReleaseClicked,
  MemberTaskDetailsOpened, MemberTaskHoverOpened, pool_msg,
}
import scrumbringer_client/client_state/types.{
  PoolDragDragging, PoolDragIdle, PoolDragPendingRect,
}
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/filters as pool_filters
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_blocked_badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_hover_popup
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_status_utils
import scrumbringer_client/ui/task_type_icon
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/card_queries

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
  case model.member.member_tasks {
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
  model.member.member_filters_type_id != opt.None
  || model.member.member_filters_capability_id != opt.None
  || string.trim(model.member.member_filters_q) != ""
}

// Justification: nested case improves clarity for branching logic.
/// Renders the main pool section with filters, canvas/list toggle, and tasks.
pub fn view_pool_main(model: Model, _user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ -> {
      div([attribute.class("section")], [
        // Unified toolbar: view mode, filters toggle, and new task - all in one row
        pool_filters.view_unified_toolbar(model),
        view_tasks(model),
      ])
    }
  }
}

/// Renders the right panel with claimed tasks dropzone.
pub fn view_right_panel(model: Model, user: User) -> Element(Msg) {
  let #(drag_armed, drag_over) = case model.member.member_pool_drag {
    PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    PoolDragPendingRect -> #(True, False)
    PoolDragIdle -> #(False, False)
  }

  let dropzone_class = case drag_armed, drag_over {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }

  let claimed_tasks = case model.member.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        case t.state {
          task_state.Claimed(claimed_by: claimed_by, mode: Taken, ..) ->
            claimed_by == user.id
          _ -> False
        }
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
        case drag_armed {
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
      event.on(
        "mousemove",
        event_decoders.mouse_client_position(fn(x, y) {
          pool_msg(MemberDragMoved(x, y))
        }),
      ),
      event.on(
        "touchmove",
        event_decoders.touch_client_position(fn(x, y) {
          pool_msg(MemberDragMoved(x, y))
        }),
      ),
      event.on("mouseup", event_decoders.message(pool_msg(MemberDragEnded))),
      event.on("mouseleave", event_decoders.message(pool_msg(MemberDragEnded))),
      event.on("touchend", event_decoders.message(pool_msg(MemberDragEnded))),
      event.on("touchcancel", event_decoders.message(pool_msg(MemberDragEnded))),
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
  error_notice.view(message)
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
    pool_msg(MemberCreateDialogOpened),
  )
  |> empty_state.view
}

/// Renders task collection in the selected view mode.
fn view_tasks_collection(model: Model, tasks: List(Task)) -> Element(Msg) {
  case model.member.member_pool_view_mode {
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
    version: version,
    blocked_count: blocked_count,
    ..,
  ) = task

  let type_icon = task_type.icon

  let disable_actions = model.member.member_task_mutation_in_flight

  let claim_actions = case blocked_count > 0 {
    True -> []
    False ->
      task_actions.claim_only(
        update_helpers.i18n_t(model, i18n_text.Claim),
        pool_msg(MemberClaimClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      )
  }

  let #(_card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info(model, task)

  let border_class = task_color.card_border_class(resolved_color)
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  task_item.view(
    task_item.Config(
      container_class: "task-row " <> border_class <> blocked_class,
      content_class: "task-row-title",
      on_click: opt.Some(pool_msg(MemberTaskDetailsOpened(id))),
      icon: opt.Some(task_type_icon.view(type_icon, 16, model.ui.theme)),
      icon_class: opt.None,
      title: title,
      title_class: opt.None,
      secondary: div([attribute.class("task-row-meta")], [
        task_blocked_badge.view(model.ui.locale, task, "task-blocked-inline"),
      ]),
      actions: [div([attribute.class("task-row-actions")], claim_actions)],
      testid: opt.None,
    ),
    task_item.Div,
  )
}

/// Renders a task card for the pool canvas view with drag-and-drop support.
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn view_task_card(model: Model, task: Task) -> Element(Msg) {
  let Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: _priority,
    status: status,
    blocked_count: blocked_count,
    created_at: created_at,
    description: description,
    version: version,
    ..,
  ) = task

  let current_user_id = case model.core.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  let is_mine = task_state.claimed_by(task.state) == opt.Some(current_user_id)

  let type_icon = task_type.icon

  let #(resolved_card_title, resolved_card_color) =
    card_queries.resolve_task_card_info(model, task)

  let card_border_class = task_color.card_border_class(resolved_card_color)
  let blocked_class = case task.blocked_count > 0 {
    True -> " task-blocked"
    False -> ""
  }

  // Get saved position or generate deterministic initial position based on task ID
  let #(x, y) = case dict.get(model.member.member_positions_by_task, id) {
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

  let size = 128

  let age_days = age_in_days(created_at)

  let shake_class = decay_to_shake_class(age_days)

  let prefer_left = x > 760

  // Build CSS classes including card border color and decay shake
  let base_classes = case prefer_left {
    True -> "task-card preview-left"
    False -> "task-card"
  }
  let with_border = case card_border_class {
    "" -> base_classes
    c -> base_classes <> " " <> c
  }
  let card_classes = case shake_class {
    "" -> with_border
    s -> with_border <> " " <> s
  }
  let card_classes = card_classes <> blocked_class
  let card_classes = case model.member.member_pool_preview_task_id {
    opt.Some(preview_id) if preview_id == id -> card_classes <> " touch-preview"
    _ -> card_classes
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
    <> "px;"

  let disable_actions = model.member.member_task_mutation_in_flight

  let primary_action = case status, is_mine {
    Available, _ if blocked_count > 0 -> element.none()
    Available, _ ->
      task_actions.claim_icon(
        update_helpers.i18n_t(model, i18n_text.Claim),
        pool_msg(MemberClaimClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      )

    Claimed(_), True ->
      task_actions.release_icon(
        update_helpers.i18n_t(model, i18n_text.Release),
        pool_msg(MemberReleaseClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
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
        event.on(
          "mousedown",
          event_decoders.mouse_client_position(fn(x, y) {
            pool_msg(MemberDragStarted(id, x, y))
          }),
        ),
      ],
      [icons.nav_icon(icons.DragHandle, icons.Small)],
    )

  let complete_action = case status, is_mine {
    Claimed(_), True ->
      task_actions.complete_icon(
        update_helpers.i18n_t(model, i18n_text.Complete),
        pool_msg(MemberCompleteClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "secondary-action",
        opt.None,
        opt.None,
      )

    _, _ -> element.none()
  }

  div(
    [
      attribute.class(card_classes),
      attribute.attribute("style", style),
      attribute.id("task-card-" <> int.to_string(id)),
      attribute.attribute(
        "aria-describedby",
        "task-preview-" <> int.to_string(id),
      ),
      attribute.attribute("tabindex", "0"),
      event.on(
        "mouseenter",
        event_decoders.message(pool_msg(MemberTaskHoverOpened(id))),
      ),
      event.on(
        "touchstart",
        event_decoders.touch_client_position(fn(x, y) {
          pool_msg(MemberPoolTouchStarted(id, x, y))
        }),
      ),
      event.on(
        "touchend",
        event_decoders.message(pool_msg(MemberPoolTouchEnded(id))),
      ),
      event.on(
        "touchcancel",
        event_decoders.message(pool_msg(MemberPoolTouchEnded(id))),
      ),
    ],
    [
      div([attribute.class("task-card-top")], [
        div([attribute.class("task-card-actions-left")], [
          task_blocked_badge.view(model.ui.locale, task, "task-blocked-card"),
          primary_action,
        ]),
        div([attribute.class("task-card-actions-right")], [
          drag_handle,
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        div([attribute.class("task-card-center")], [
          div([attribute.class("task-card-center-icon")], [
            task_type_icon.view(type_icon, 22, model.ui.theme),
          ]),
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
          attribute.attribute("id", "task-preview-" <> int.to_string(id)),
          attribute.attribute(
            "aria-describedby",
            "task-preview-" <> int.to_string(id),
          ),
        ],
        [
          task_hover_popup.view(task_hover_popup.TaskHoverConfig(
            card_label: update_helpers.i18n_t(model, i18n_text.ParentCardLabel),
            card_title: resolved_card_title,
            age_label: update_helpers.i18n_t(model, i18n_text.AgeLabel),
            age_value: update_helpers.i18n_t(
              model,
              i18n_text.CreatedAgoDays(age_days),
            ),
            description_label: update_helpers.i18n_t(
              model,
              i18n_text.Description,
            ),
            description: opt.unwrap(description, ""),
            blocked_label: hover_blocked_label(model, task),
            blocked_items: hover_blocked_items(model, task),
            notes_label: hover_notes_label(model, task),
            notes: hover_notes_for_task(model, id),
            open_label: update_helpers.i18n_t(model, i18n_text.OpenTask),
            on_open: pool_msg(MemberTaskDetailsOpened(id)),
          )),
        ],
      ),
    ],
  )
}

fn hover_blocked_label(model: Model, task: Task) -> opt.Option(String) {
  let blocking = blocking_dependencies(task)
  let count = list.length(blocking)
  case count > 0 {
    True ->
      opt.Some(update_helpers.i18n_t(model, i18n_text.BlockedByTasks(count)))
    False -> opt.None
  }
}

fn hover_blocked_items(model: Model, task: Task) -> List(String) {
  let blocking = blocking_dependencies(task)
  blocking
  |> list.take(2)
  |> list.map(fn(dep) {
    dep.title <> " · " <> task_status_utils.label(model.ui.locale, dep.status)
  })
}

fn blocking_dependencies(task: Task) -> List(task.TaskDependency) {
  let Task(dependencies: dependencies, ..) = task
  list.filter(dependencies, fn(dep) { dep.status != Completed })
}

fn hover_notes_label(model: Model, task: Task) -> opt.Option(String) {
  let Task(id: task_id, ..) = task
  case hover_notes_for_task(model, task_id) {
    [] -> opt.None
    _ -> opt.Some(update_helpers.i18n_t(model, i18n_text.RecentNotes))
  }
}

fn hover_notes_for_task(
  model: Model,
  task_id: Int,
) -> List(task_hover_popup.HoverNote) {
  let current_user_id = case model.core.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  case dict.get(model.member.member_hover_notes_cache, task_id) {
    Ok(notes) ->
      list.map(notes, fn(note) {
        let TaskNote(
          user_id: user_id,
          created_at: created_at,
          content: content,
          ..,
        ) = note
        let author = case user_id == current_user_id {
          True -> update_helpers.i18n_t(model, i18n_text.You)
          False -> update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
        }
        task_hover_popup.HoverNote(
          author: author,
          created_at: created_at,
          content: content,
        )
      })
    Error(_) -> []
  }
}

// --- Helpers ---

fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}

/// Returns a CSS class for shake animation based on task age.
/// Shake intensity increases with age to indicate staleness.
fn decay_to_shake_class(age_days: Int) -> String {
  case age_days {
    d if d < 9 -> ""
    d if d < 18 -> "decay-shake-low"
    d if d < 27 -> "decay-shake-medium"
    _ -> "decay-shake-high"
  }
}
