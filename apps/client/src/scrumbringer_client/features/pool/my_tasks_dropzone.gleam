//// My Tasks dropzone for the pool right rail.

import gleam/int
import gleam/list

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}
import lustre/element/keyed

import domain/task.{type Task, Task}

import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/pool/chrome as pool_chrome
import scrumbringer_client/i18n/locale.{type Locale}

pub type Config(msg) {
  Config(
    locale: Locale,
    drag_armed: Bool,
    drag_over: Bool,
    claimed_tasks: List(Task),
    task_row_config: my_bar_view.TaskRowConfig(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([], [
    pool_chrome.my_tasks_heading(config.locale),
    div(
      [
        attribute.attribute("id", "pool-my-tasks"),
        attribute.class(dropzone_class(config.drag_armed, config.drag_over)),
      ],
      [
        case config.drag_armed {
          True -> pool_chrome.my_tasks_dropzone_hint(config.locale)
          False -> element.none()
        },
        view_tasks(config),
      ],
    ),
  ])
}

fn dropzone_class(drag_armed: Bool, drag_over: Bool) -> String {
  case drag_armed, drag_over {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }
}

fn view_tasks(config: Config(msg)) -> Element(msg) {
  case config.claimed_tasks {
    [] -> pool_chrome.no_claimed_tasks(config.locale)
    tasks ->
      keyed.div(
        [attribute.class("task-list")],
        list.map(tasks, fn(task) {
          let Task(id: task_id, ..) = task
          #(
            int.to_string(task_id),
            my_bar_view.view_member_bar_task_row(config.task_row_config, task),
          )
        }),
      )
  }
}
