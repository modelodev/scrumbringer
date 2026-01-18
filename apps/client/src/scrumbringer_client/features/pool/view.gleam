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
import domain/task_type
import domain/user.{type User}

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading,
  MemberClaimClicked, MemberCompleteClicked, MemberCreateDialogOpened,
  MemberDragEnded, MemberDragMoved, MemberDragStarted,
  MemberPoolFiltersToggled, MemberPoolViewModeSet, MemberReleaseClicked, NotAsked,
}
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/features/pool/filters as pool_filters
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_visuals
import scrumbringer_client/pool_prefs
import scrumbringer_client/update_helpers

/// Renders the main pool section with filters, canvas/list toggle, and tasks.
pub fn view_pool_main(model: Model, _user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ -> {
      let filters_toggle_label = case model.member_pool_filters_visible {
        True -> update_helpers.i18n_t(model, i18n_text.HideFilters)
        False -> update_helpers.i18n_t(model, i18n_text.ShowFilters)
      }

      let canvas_classes = case model.member_pool_view_mode {
        pool_prefs.Canvas -> "btn-xs btn-active"
        pool_prefs.List -> "btn-xs"
      }

      let list_classes = case model.member_pool_view_mode {
        pool_prefs.List -> "btn-xs btn-active"
        pool_prefs.Canvas -> "btn-xs"
      }

      div([attribute.class("section")], [
        div([attribute.class("actions")], [
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberPoolFiltersToggled),
            ],
            [text(filters_toggle_label)],
          ),
          button(
            [
              attribute.class(canvas_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewCanvas),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.Canvas)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Canvas))],
          ),
          button(
            [
              attribute.class(list_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewList),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.List)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.List))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberCreateDialogOpened),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NewTaskShortcut))],
          ),
        ]),
        case model.member_pool_filters_visible {
          True -> pool_filters.view(model)
          False -> element.none()
        },
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
          [] ->
            div([attribute.class("empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NoClaimedTasks)),
            ])
          _ ->
            keyed.div(
              [attribute.class("task-list")],
              list.map(claimed_tasks, fn(t) {
                let Task(id: task_id, ..) = t
                #(int.to_string(task_id), my_bar_view.view_member_bar_task_row(model, user, t))
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
      attribute.class("body"),
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
fn view_tasks(model: Model) -> Element(Msg) {
  case model.member_tasks {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])
    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(tasks) -> {
      let available_tasks =
        tasks
        |> list.filter(fn(t) {
          let Task(status: status, ..) = t
          status == Available
        })

      case available_tasks {
        [] -> {
          let no_filters =
            string.trim(model.member_filters_type_id) == ""
            && string.trim(model.member_filters_capability_id) == ""
            && string.trim(model.member_filters_q) == ""

          case no_filters {
            True ->
              div([attribute.class("empty")], [
                h2([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.NoAvailableTasksRightNow,
                  )),
                ]),
                p([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.CreateFirstTaskToStartUsingPool,
                  )),
                ]),
                button([event.on_click(MemberCreateDialogOpened)], [
                  text(update_helpers.i18n_t(model, i18n_text.NewTask)),
                ]),
              ])

            False ->
              div([attribute.class("empty")], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.NoTasksMatchYourFilters,
                )),
              ])
          }
        }

        _ -> {
          case model.member_pool_view_mode {
            pool_prefs.Canvas -> view_tasks_canvas(model, available_tasks)
            pool_prefs.List -> view_tasks_list(model, available_tasks)
          }
        }
      }
    }
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
      [text("✋")],
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
    ..,
  ) = task

  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  let is_mine = claimed_by == opt.Some(current_user_id)

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let highlight = should_highlight_task(model, opt.Some(task_type))

  let #(x, y) = case dict.get(model.member_positions_by_task, id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  let size = member_visuals.priority_to_px(priority)

  let age_days = age_in_days(created_at)

  let #(opacity, saturation) = decay_to_visuals(age_days)

  let prefer_left = x > 760

  let card_classes = case highlight, prefer_left {
    True, True -> "task-card highlight preview-left"
    True, False -> "task-card highlight"
    False, True -> "task-card preview-left"
    False, False -> "task-card"
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
        [text("✋")],
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
        [text("⟲")],
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
      [text("⠿")],
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
        [text("☑")],
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

fn should_highlight_task(
  model: Model,
  _task_type: opt.Option(task_type.TaskTypeInline),
) -> Bool {
  case model.member_quick_my_caps {
    False -> False
    True -> False
  }
}
