//// Task Show header.

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{div, span, text}

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task/state as task_execution_state

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/inspector_header
import scrumbringer_client/ui/task_status_indicator

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(domain_task.Task),
    parent_card_title: opt.Option(String),
    capability_name: opt.Option(String),
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
  inspector_header.view(inspector_header.Config(
    title: title,
    title_id: "task-show-title",
    state_line: opt.None,
    context: opt.None,
    meta: meta,
    primary_action: opt.None,
    open_in: opt.None,
    secondary_actions: opt.None,
    close_label: t(config, i18n_text.Close),
    on_close: config.on_close,
    extra_class: "task-inspector-header",
  ))
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
      capability_chip(config),
      span([attribute.class("task-meta-chip task-meta-priority")], [
        icons.nav_icon(icons.Automation, icons.Small),
        text("P" <> int.to_string(task.priority)),
      ]),
    ]),
    div([attribute.class("detail-meta-group")], [
      task_status_indicator.view(task_status_indicator.Config(
        locale: config.locale,
        status: task_execution_state.to_status(task.state),
        variant: task_status_indicator.InlineFull,
        label: opt.None,
        title: opt.None,
        extra_class: opt.Some("task-meta-chip task-meta-status"),
        testid: opt.Some("task-show-status-indicator"),
      )),
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

fn capability_chip(config: Config(msg)) -> Element(msg) {
  case config.capability_name {
    opt.Some(name) ->
      span([attribute.class("task-meta-chip task-meta-capability")], [
        icons.nav_icon(icons.Capabilities, icons.Small),
        text(name),
      ])
    opt.None -> none()
  }
}

fn assignee(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  case task_execution_state.claimed_by(task.state) {
    opt.Some(user_id) ->
      span([attribute.class("task-meta-chip task-meta-assignee")], [
        icons.nav_icon(icons.UserCircle, icons.Small),
        text(t(config, i18n_text.ClaimedBy) <> " #" <> int.to_string(user_id)),
      ])
    opt.None ->
      span([attribute.class("task-meta-chip task-meta-assignee muted")], [
        text(task_status_indicator_label(config, task)),
      ])
  }
}

fn task_status_indicator_label(
  config: Config(msg),
  task: domain_task.Task,
) -> String {
  case task.state {
    task_execution_state.Available -> t(config, i18n_text.TaskNextActionClaim)
    task_execution_state.Closed(..) -> t(config, i18n_text.TaskNextActionOpen)
    task_execution_state.Claimed(..) -> t(config, i18n_text.TaskNextActionOpen)
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
    Loaded(dependencies) -> blocking.open_dependency_count(dependencies)
    _ -> task.blocked_count
  }
}
