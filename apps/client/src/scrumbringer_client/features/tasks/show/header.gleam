//// Task Show header.

import gleam/option as opt

import lustre/element.{type Element}

import domain/remote.{type Remote}
import domain/task as domain_task

import scrumbringer_client/features/tasks/show/headline
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/inspector_header
import scrumbringer_client/ui/inspector_meta

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(domain_task.Task),
    parent_card_title: opt.Option(String),
    current_user_id: opt.Option(Int),
    dependencies: Remote(List(domain_task.TaskDependency)),
    actions: opt.Option(Element(msg)),
    on_close: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.task {
    opt.Some(task) ->
      render_header(
        config,
        task.title,
        opt.Some(headline.text(headline_config(config, task))),
        opt.Some(task_header_meta(config, task)),
      )

    opt.None ->
      render_header(
        config,
        t(config, i18n_text.LoadingEllipsis),
        opt.None,
        opt.None,
      )
  }
}

fn render_header(
  config: Config(msg),
  title: String,
  state_line: opt.Option(String),
  meta: opt.Option(Element(msg)),
) -> Element(msg) {
  inspector_header.view(inspector_header.Config(
    title: title,
    title_id: "task-show-title",
    state_line: state_line,
    context: opt.None,
    meta: meta,
    actions: config.actions,
    close_label: t(config, i18n_text.Close),
    on_close: config.on_close,
    extra_class: "task-inspector-header",
  ))
}

fn task_header_meta(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  let created_signal =
    inspector_meta.created_at(
      config.locale,
      task.created_at,
      "task-header-created-at",
    )

  inspector_meta.container_required([
    inspector_meta.group_required([created_signal]),
  ])
}

fn headline_config(
  config: Config(msg),
  task: domain_task.Task,
) -> headline.Config {
  headline.Config(
    locale: config.locale,
    task: task,
    parent_card_title: config.parent_card_title,
    current_user_id: config.current_user_id,
    dependencies: config.dependencies,
  )
}
