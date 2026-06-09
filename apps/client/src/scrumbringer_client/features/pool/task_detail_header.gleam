//// Task detail modal header.

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import domain/task.{type Task, claimed_by}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/task_state

pub type Config(msg) {
  Config(locale: Locale, task: opt.Option(Task), on_close: msg)
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.task {
    opt.Some(task) ->
      modal_header.view_extended(base_header_config(
        config,
        title: task.title,
        meta: opt.Some(task_meta(config, task)),
      ))

    opt.None ->
      modal_header.view_extended(base_header_config(
        config,
        title: t(config, i18n_text.LoadingEllipsis),
        meta: opt.None,
      ))
  }
}

fn base_header_config(
  config: Config(msg),
  title title: String,
  meta meta: opt.Option(Element(msg)),
) -> modal_header.ExtendedConfig(msg) {
  modal_header.ExtendedConfig(
    title: title,
    title_element: modal_header.TitleH2,
    close_position: modal_header.CloseBeforeTitle,
    icon: opt.None,
    badges: [],
    meta: meta,
    progress: opt.None,
    on_close: config.on_close,
    header_class: "detail-header",
    title_row_class: "detail-title-row",
    title_class: "detail-title",
    title_id: "task-detail-title",
    close_button_class: "modal-close btn-icon",
  )
}

fn task_meta(config: Config(msg), task: Task) -> Element(msg) {
  div([attribute.class("detail-meta")], [
    div([attribute.class("detail-meta-group")], [
      span([attribute.class("task-meta-chip task-meta-type")], [
        icons.nav_icon(icons.TaskTypes, icons.Small),
        text(task.task_type.name),
      ]),
      span([attribute.class("task-meta-chip task-meta-priority")], [
        icons.nav_icon(icons.Automation, icons.Small),
        text("P" <> int.to_string(task.priority)),
      ]),
    ]),
    div([attribute.class("detail-meta-group")], [
      span([attribute.class("task-meta-chip task-meta-status")], [
        text(task_state.label(config.locale, task.status)),
      ]),
      assignee(config, task),
    ]),
  ])
}

fn assignee(config: Config(msg), task: Task) -> Element(msg) {
  case claimed_by(task) {
    opt.Some(_user_id) ->
      span([attribute.class("task-meta-chip task-meta-assignee")], [
        icons.nav_icon(icons.UserCircle, icons.Small),
        text(t(config, i18n_text.Assigned)),
      ])
    opt.None ->
      span([attribute.class("task-meta-chip task-meta-assignee muted")], [
        text(t(config, i18n_text.Unassigned)),
      ])
  }
}
