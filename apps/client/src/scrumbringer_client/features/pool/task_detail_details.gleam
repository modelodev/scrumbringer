//// Task detail modal details tab presenter.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/card.{type Card}
import domain/milestone.{type MilestoneProgress}
import domain/remote.{type Remote}
import domain/task.{type Task}
import domain/task_type.{type TaskType}

import scrumbringer_client/features/tasks/detail_editor
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Config(msg) {
  Config(
    locale: Locale,
    current_user_id: opt.Option(Int),
    task: opt.Option(Task),
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_priority: String,
    edit_type_id: String,
    edit_card_id: String,
    edit_milestone_id: String,
    edit_error: opt.Option(String),
    edit_in_flight: Bool,
    task_types: Remote(List(TaskType)),
    cards: List(Card),
    milestones: Remote(List(MilestoneProgress)),
    parent_card_title: opt.Option(String),
    on_edit_started: msg,
    on_edit_cancelled: msg,
    on_title_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_type_id_changed: fn(String) -> msg,
    on_card_id_changed: fn(String) -> msg,
    on_milestone_id_changed: fn(String) -> msg,
    on_submitted: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("task-details-section detail-section")], [
    case config.task {
      opt.Some(task) ->
        detail_editor.view_readonly_fields(detail_editor_config(config), task)
      opt.None ->
        div([attribute.class("loading")], [
          text(i18n.t(config.locale, i18n_text.LoadingEllipsis)),
        ])
    },
  ])
}

fn detail_editor_config(config: Config(msg)) -> detail_editor.Config(msg) {
  detail_editor.Config(
    locale: config.locale,
    current_user_id: config.current_user_id,
    editing: config.editing,
    edit_title: config.edit_title,
    edit_description: config.edit_description,
    edit_priority: config.edit_priority,
    edit_type_id: config.edit_type_id,
    edit_card_id: config.edit_card_id,
    edit_milestone_id: config.edit_milestone_id,
    edit_error: config.edit_error,
    edit_in_flight: config.edit_in_flight,
    task_types: config.task_types,
    cards: config.cards,
    milestones: config.milestones,
    parent_card_title: config.parent_card_title,
    on_edit_started: config.on_edit_started,
    on_edit_cancelled: config.on_edit_cancelled,
    on_title_changed: config.on_title_changed,
    on_description_changed: config.on_description_changed,
    on_priority_changed: config.on_priority_changed,
    on_type_id_changed: config.on_type_id_changed,
    on_card_id_changed: config.on_card_id_changed,
    on_milestone_id_changed: config.on_milestone_id_changed,
    on_submitted: config.on_submitted,
  )
}
