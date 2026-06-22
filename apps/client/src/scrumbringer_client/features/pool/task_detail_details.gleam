//// Task detail modal details tab presenter.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{a, div, span, text}

import domain/card.{type Card}
import domain/remote.{type Remote}
import domain/task.{type Task, type TaskDependency}

import scrumbringer_client/features/cards/scoped_navigation
import scrumbringer_client/features/pool/task_detail_summary
import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/pinned_context

pub type Config(msg) {
  Config(
    locale: Locale,
    task: opt.Option(Task),
    dependencies: Remote(List(TaskDependency)),
    parent_card_title: opt.Option(String),
    parent_card: opt.Option(Card),
    pinned_notes: List(pinned_context.PinnedNote),
    on_open_notes: msg,
    on_open_parent_card: fn(Int) -> msg,
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
          pinned_context.view(pinned_context.Config(
            title: i18n.t(config.locale, i18n_text.PinnedContext),
            notes: config.pinned_notes,
            open_notes_label: i18n.t(config.locale, i18n_text.OpenNotes),
            more_label: fn(count) {
              i18n.t(config.locale, i18n_text.MorePinnedNotes(count))
            },
            on_open_notes: config.on_open_notes,
          )),
          parent_card_context(config),
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

fn parent_card_context(config: Config(msg)) -> Element(msg) {
  case config.parent_card {
    opt.Some(card) ->
      div([attribute.class("task-parent-context")], [
        div([attribute.class("task-parent-context-main")], [
          div([attribute.class("task-parent-context-label")], [
            text(i18n.t(config.locale, i18n_text.ParentCardLabel)),
          ]),
          div([attribute.class("task-parent-context-title")], [
            text(card.title),
          ]),
        ]),
        div([attribute.class("task-parent-context-actions")], [
          button.view(
            button.icon_text(
              i18n.t(config.locale, i18n_text.OpenCard),
              config.on_open_parent_card(card.id),
              icons.Cards,
              button.Secondary,
              button.EntityAction,
            )
            |> button.with_class("task-parent-open-card"),
          ),
          a(
            [
              attribute.class(
                "btn btn-secondary btn-icon-text btn-entity-action btn-sm task-parent-plan-link",
              ),
              attribute.href(scoped_navigation.plan_url(card)),
            ],
            [
              span([attribute.class("btn-icon-prefix")], [
                icons.nav_icon(icons.List, icons.Small),
              ]),
              text(i18n.t(config.locale, i18n_text.ViewInPlan)),
            ],
          ),
        ]),
      ])
    opt.None -> element.none()
  }
}
