//// Task Show details tab presenter.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/remote.{type Remote}
import domain/task.{type Task, type TaskDependency}

import scrumbringer_client/features/pool/task_show_summary
import scrumbringer_client/features/tasks/show_editor
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/pinned_context

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(Task),
    dependencies: Remote(List(TaskDependency)),
    parent_card_title: opt.Option(String),
    pinned_notes: List(pinned_context.PinnedNote),
    on_open_notes: msg,
    editor: show_editor.Config(msg),
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
              task_show_summary.view(task_show_summary.Config(
                locale: config.locale,
                task: task,
                dependencies: config.dependencies,
                parent_card_title: config.parent_card_title,
              ))
          },
          pinned_context.view(pinned_context.Config(
            title: i18n.t(config.locale, i18n_text.PinnedContext),
            notes: config.pinned_notes,
            open_notes_label: i18n.t(config.locale, i18n_text.OpenNotes),
            more_label: fn(count) {
              i18n.t(config.locale, i18n_text.MorePinnedNotes(count))
            },
            on_open_notes: config.on_open_notes,
          )),
          show_editor.view_readonly_fields(config.editor, task),
        ])
      opt.None ->
        div([attribute.class("loading")], [
          text(i18n.t(config.locale, i18n_text.LoadingEllipsis)),
        ])
    },
  ])
}

pub fn is_dirty(config: Config(msg), task: Task) -> Bool {
  show_editor.is_dirty(config.editor, task)
}
