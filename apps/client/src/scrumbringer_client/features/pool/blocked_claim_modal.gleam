import gleam/list
import gleam/option.{type Option, None, Some}

import domain/task.{type Task}
import domain/task_status.{Claimed}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{li, p, text, ul}

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/task_state as ui_task_state

pub type Config(msg) {
  Config(
    locale: Locale,
    task_id: Int,
    task: Option(Task),
    on_confirm: msg,
    on_cancel: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let blocking = blocking.incomplete_dependencies_or_empty(config.task)
  confirm_dialog.view(confirm_dialog.ConfirmConfig(
    title: i18n.t(config.locale, i18n_text.BlockedTaskTitle),
    body: [
      p([attribute.class("blocked-claim-title")], [
        text(task_title(config.locale, config.task_id, config.task)),
      ]),
      p([attribute.class("blocked-claim-warning")], [
        text(i18n.t(
          config.locale,
          i18n_text.BlockedTaskWarning(list.length(blocking)),
        )),
      ]),
      case blocking {
        [] -> element.none()
        _ ->
          ul(
            [attribute.class("blocked-claim-list")],
            list.map(blocking, fn(dep) {
              li([], [
                text(
                  dep.title
                  <> " - "
                  <> dependency_status(
                    config.locale,
                    dep.status,
                    dep.claimed_by,
                  ),
                ),
              ])
            }),
          )
      },
    ],
    confirm_label: i18n.t(config.locale, i18n_text.Claim),
    cancel_label: i18n.t(config.locale, i18n_text.Cancel),
    on_confirm: config.on_confirm,
    on_cancel: config.on_cancel,
    is_open: True,
    is_loading: False,
    error: None,
    confirm_class: "btn-primary",
  ))
}

fn task_title(locale: Locale, task_id: Int, task: Option(Task)) -> String {
  case task {
    Some(task) -> task.title
    None -> i18n.t(locale, i18n_text.TaskNumber(task_id))
  }
}

fn dependency_status(
  locale: Locale,
  status,
  claimed_by: Option(String),
) -> String {
  let status_label = ui_task_state.label(locale, status)
  case status, claimed_by {
    Claimed(_), Some(email) ->
      i18n.t(locale, i18n_text.ClaimedBy) <> " " <> email
    _, _ -> status_label
  }
}
