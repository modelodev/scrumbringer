//// Task detail modal details tab presenter.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/remote.{type Remote}
import domain/task.{type Task, type TaskDependency}

import scrumbringer_client/features/pool/task_detail_summary
import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(Task),
    dependencies: Remote(List(TaskDependency)),
    parent_card_title: opt.Option(String),
    editor: detail_editor.Config(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("task-details-section detail-section")], [
    case config.task {
      opt.Some(task) ->
        div([attribute.class("task-details-stack")], [
          case config.editor.editing {
            True -> element.none()
            False ->
              task_detail_summary.view(task_detail_summary.Config(
                locale: config.locale,
                task: task,
                dependencies: config.dependencies,
                parent_card_title: config.parent_card_title,
              ))
          },
          detail_editor.view_readonly_fields(config.editor, task),
        ])
      opt.None ->
        div([attribute.class("loading")], [
          text(i18n.t(config.locale, i18n_text.LoadingEllipsis)),
        ])
    },
  ])
}

pub fn is_dirty(config: Config(msg), task: Task) -> Bool {
  detail_editor.is_dirty(config.editor, task)
}
