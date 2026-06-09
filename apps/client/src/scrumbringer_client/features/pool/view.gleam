//// Pool View
////
//// Pure view functions for the member pool section including task canvas,
//// task cards, and layout assembly.
////
//// ## Responsibilities
////
//// - Pool main layout and task canvas/list rendering
//// - Right panel with claimed tasks dropzone
//// - Drag container event wiring through provided messages
////
//// ## Non-responsibilities
////
//// - Root `client_state.Model` adaptation (see `features/pool/view_config.gleam`)
//// - Filter panel (see `features/layout/center_panel.gleam`)
//// - Dialogs (see `features/pool/dialogs.gleam`)

import gleam/int
import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/element/keyed
import lustre/event

import domain/task.{type Task, Task}

import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/chrome as pool_chrome
import scrumbringer_client/features/pool/my_tasks_dropzone
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/features/pool/task_row
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/pool_prefs
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders

pub type MainConfig(msg) {
  MainConfig(
    locale: Locale,
    has_active_projects: Bool,
    on_create_opened: msg,
    available_tasks: available_tasks.Config,
    view_mode: pool_prefs.ViewMode,
    task_card_config: fn(Task) -> task_card.Config(msg),
    task_row_config: fn(Task) -> task_row.Config(msg),
  )
}

pub type RightPanelConfig(msg) {
  RightPanelConfig(
    locale: Locale,
    now_working_config: now_working_panel.Config(msg),
    drag_armed: Bool,
    drag_over: Bool,
    claimed_tasks: List(Task),
    task_row_config: my_bar_view.TaskRowConfig(msg),
  )
}

pub type BodyConfig(msg) {
  BodyConfig(
    main_config: MainConfig(msg),
    right_panel_config: RightPanelConfig(msg),
    on_drag_moved: fn(Int, Int) -> msg,
    on_drag_ended: msg,
  )
}

/// Renders the main pool section with filters, canvas/list toggle, and tasks.
pub fn view_pool_main(config: MainConfig(msg)) -> Element(msg) {
  case config.has_active_projects {
    False -> pool_chrome.no_projects(config.locale)
    True ->
      div([attribute.class("section pool-view")], [
        pool_chrome.header(config.locale, config.on_create_opened),
        view_tasks(config),
      ])
  }
}

/// Renders the right panel with claimed tasks dropzone.
pub fn view_right_panel(config: RightPanelConfig(msg)) -> Element(msg) {
  div([], [
    now_working_panel.view(config.now_working_config),
    my_tasks_dropzone.view(my_tasks_dropzone.Config(
      locale: config.locale,
      drag_armed: config.drag_armed,
      drag_over: config.drag_over,
      claimed_tasks: config.claimed_tasks,
      task_row_config: config.task_row_config,
    )),
  ])
}

/// Renders the pool body with mouse event handlers for drag-drop.
pub fn view_pool_body(config: BodyConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("pool-layout"),
      event.on(
        "mousemove",
        event_decoders.mouse_client_position(config.on_drag_moved),
      ),
      event.on(
        "touchmove",
        event_decoders.touch_client_position(config.on_drag_moved),
      ),
      event.on("mouseup", event_decoders.message(config.on_drag_ended)),
      event.on("mouseleave", event_decoders.message(config.on_drag_ended)),
      event.on("touchend", event_decoders.message(config.on_drag_ended)),
      event.on("touchcancel", event_decoders.message(config.on_drag_ended)),
    ],
    [
      div([attribute.class("content pool-main")], [
        view_pool_main(config.main_config),
      ]),
      div([attribute.class("pool-right")], [
        view_right_panel(config.right_panel_config),
      ]),
    ],
  )
}

/// Renders a task row in list view.
pub fn view_pool_task_row(config: task_row.Config(msg)) -> Element(msg) {
  task_row.view(config)
}

/// Renders a task card for the pool canvas view with drag-and-drop support.
pub fn view_task_card(config: task_card.Config(msg)) -> Element(msg) {
  task_card.view(config)
}

/// Renders the task list/canvas based on loading state and view mode.
fn view_tasks(config: MainConfig(msg)) -> Element(msg) {
  case available_tasks.state(config.available_tasks) {
    available_tasks.Loading -> pool_chrome.tasks_loading(config.locale)
    available_tasks.Error(message) -> error_notice.view(message)
    available_tasks.Empty(has_filters: True) ->
      pool_chrome.tasks_no_matches(config.locale)
    available_tasks.Empty(has_filters: False) ->
      pool_chrome.tasks_onboarding(config.locale, config.on_create_opened)
    available_tasks.Ready(tasks) -> view_tasks_collection(config, tasks)
  }
}

fn view_tasks_collection(
  config: MainConfig(msg),
  tasks: List(Task),
) -> Element(msg) {
  case config.view_mode {
    pool_prefs.Canvas -> view_tasks_canvas(config, tasks)
    pool_prefs.List -> view_tasks_list(config, tasks)
  }
}

fn view_tasks_canvas(config: MainConfig(msg), tasks: List(Task)) -> Element(msg) {
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
      #(int.to_string(id), view_task_card(config.task_card_config(task)))
    }),
  )
}

fn view_tasks_list(config: MainConfig(msg), tasks: List(Task)) -> Element(msg) {
  keyed.div(
    [attribute.class("task-list")],
    list.map(tasks, fn(task) {
      let Task(id: id, ..) = task
      #(int.to_string(id), view_pool_task_row(config.task_row_config(task)))
    }),
  )
}
