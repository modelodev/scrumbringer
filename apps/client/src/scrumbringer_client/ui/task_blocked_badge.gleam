//// Blocked task badge with tooltip.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import domain/task.{type Task, type TaskDependency, dependency_is_closed}
import domain/task/state as task_execution_state
import domain/task_status

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_status_utils

pub fn view(locale: Locale, task: Task, extra_class: String) -> Element(msg) {
  case task.blocked_count > 0 {
    False -> element.none()
    True -> {
      let tooltip = tooltip_text(locale, task)
      span(
        [
          attribute.class("task-blocked-badge " <> extra_class),
          attribute.attribute("title", tooltip),
          attribute.attribute("aria-label", tooltip),
        ],
        [
          icons.nav_icon(icons.Warning, icons.XSmall),
          span([attribute.class("task-blocked-count")], [
            text(int.to_string(task.blocked_count)),
          ]),
        ],
      )
    }
  }
}

pub fn tooltip_text(locale: Locale, task: Task) -> String {
  let blocking =
    list.filter(task.dependencies, fn(dep) { !dependency_is_closed(dep) })
  let blocking_count = case blocking {
    [] -> task.blocked_count
    _ -> list.length(blocking)
  }
  let header = i18n.t(locale, i18n_text.BlockedByTasks(blocking_count))
  let items =
    list.map(blocking, fn(dep) {
      dep.title <> " (" <> dependency_status_text(locale, dep) <> ")"
    })
  case items {
    [] -> header
    _ -> header <> "\n" <> string.join(items, "\n")
  }
}

fn dependency_status_text(locale: Locale, dep: TaskDependency) -> String {
  let status = task_execution_state.to_status(dep.state)
  let status_label = task_status_utils.label(locale, status)
  case status {
    task_status.Claimed(_) ->
      case dep.claimed_by {
        opt.Some(email) -> i18n.t(locale, i18n_text.ClaimedBy) <> " " <> email
        opt.None -> status_label
      }
    _ -> status_label
  }
}
