//// domain_task.Task detail modal header.

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header
import scrumbringer_client/ui/task_state

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(domain_task.Task),
    parent_card_title: opt.Option(String),
    dependencies: Remote(List(domain_task.TaskDependency)),
    on_close: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.task {
    opt.Some(task) ->
      render_header(config, task.title, opt.Some(task_meta(config, task)))

    opt.None ->
      render_header(config, t(config, i18n_text.LoadingEllipsis), opt.None)
  }
}

fn render_header(
  config: Config(msg),
  title: String,
  meta: opt.Option(Element(msg)),
) -> Element(msg) {
  modal_header.view_extended_with_close_label(
    base_header_config(config, title:, meta:),
    t(config, i18n_text.Close),
  )
}

fn base_header_config(
  config: Config(msg),
  title title: String,
  meta meta: opt.Option(Element(msg)),
) -> modal_header.ExtendedConfig(msg) {
  modal_header.ExtendedConfig(
    title: title,
    title_element: modal_header.TitleH2,
    close_position: modal_header.CloseAfterTitle,
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

fn task_meta(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  let blockers = blocking_count(config, task)

  div([attribute.class("detail-meta")], [
    div([attribute.class("detail-meta-group")], [
      card_chip(config),
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
        text(task_state.label(config.locale, domain_task.status(task))),
      ]),
      assignee(config, task),
      due_date(config, task),
      blocking_chip(config, blockers),
    ]),
  ])
}

fn card_chip(config: Config(msg)) -> Element(msg) {
  case config.parent_card_title {
    opt.Some(title) ->
      span([attribute.class("task-meta-chip task-meta-card")], [
        icons.nav_icon(icons.Cards, icons.Small),
        text(title),
      ])
    opt.None ->
      span([attribute.class("task-meta-chip task-meta-card muted")], [
        text(t(config, i18n_text.NoCard)),
      ])
  }
}

fn assignee(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  case domain_task.claimed_by(task) {
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

fn due_date(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  case task.due_date {
    opt.Some(date) ->
      span([attribute.class("task-meta-chip task-meta-due")], [
        icons.nav_icon(icons.Calendar, icons.Small),
        text(t(config, i18n_text.TaskDueDateLabel) <> " " <> date),
      ])
    opt.None ->
      span([attribute.class("task-meta-chip task-meta-due muted")], [
        text(t(config, i18n_text.NoDueDate)),
      ])
  }
}

fn blocking_chip(config: Config(msg), count: Int) -> Element(msg) {
  case count {
    0 ->
      span([attribute.class("task-meta-chip task-meta-blocking muted")], [
        text(t(config, i18n_text.TaskBlockingClear)),
      ])
    _ ->
      span([attribute.class("task-meta-chip task-meta-blocking blocking")], [
        text(t(config, i18n_text.BlockedByTasks(count))),
      ])
  }
}

fn blocking_count(config: Config(msg), task: domain_task.Task) -> Int {
  case config.dependencies {
    Loaded(dependencies) -> blocking.incomplete_dependency_count(dependencies)
    _ -> task.blocked_count
  }
}
