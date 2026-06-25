//// Pure Task Show state transitions.

import gleam/int
import gleam/option as opt

import domain/remote.{Loading, NotAsked}
import domain/task.{type Task}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/tasks/show/model as show_model
import scrumbringer_client/features/tasks/show_edit_form
import scrumbringer_client/ui/show_tabs

pub fn open(
  _task_show: show_model.Model,
  notes: member_notes.Model,
  dependencies: member_dependencies.Model,
  task_id: Int,
  maybe_task: opt.Option(Task),
) -> #(show_model.Model, member_notes.Model, member_dependencies.Model) {
  let fields = edit_fields(maybe_task)

  #(
    show_model.Model(
      active_tab: show_tabs.TaskDetailsTab,
      editing: False,
      edit_title: fields.title,
      edit_description: fields.description,
      edit_priority: fields.priority,
      edit_type_id: fields.type_id,
      edit_card_id: fields.card_id,
      edit_in_flight: False,
      edit_error: opt.None,
    ),
    member_notes.Model(
      ..notes,
      member_notes_task_id: opt.Some(task_id),
      member_notes: Loading,
      member_note_error: opt.None,
      member_note_delete_in_flight: opt.None,
      member_note_pin_in_flight: opt.None,
      member_activity: Loading,
      member_activity_total: 0,
      member_activity_loading_more: False,
    ),
    member_dependencies.Model(
      ..dependencies,
      member_dependencies: Loading,
      member_dependency_add_error: opt.None,
      member_dependency_remove_in_flight: opt.None,
    ),
  )
}

type EditFields {
  EditFields(
    title: String,
    description: String,
    priority: String,
    type_id: String,
    card_id: String,
  )
}

fn edit_fields(maybe_task: opt.Option(Task)) -> EditFields {
  case maybe_task {
    opt.Some(task) ->
      EditFields(
        title: task.title,
        description: show_edit_form.task_description_text(task),
        priority: int.to_string(task.priority),
        type_id: int.to_string(show_edit_form.task_type_id(task)),
        card_id: id_to_form_value(task.card_id),
      )
    opt.None ->
      EditFields(
        title: "",
        description: "",
        priority: "3",
        type_id: "",
        card_id: "",
      )
  }
}

pub fn close(
  notes: member_notes.Model,
) -> #(show_model.Model, member_notes.Model, member_dependencies.Model) {
  #(
    show_model.default(),
    member_notes.Model(
      ..notes,
      member_notes_task_id: opt.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_error: opt.None,
      member_note_dialog_mode: dialog_mode.DialogClosed,
      member_note_delete_in_flight: opt.None,
      member_note_pin_in_flight: opt.None,
      member_activity: NotAsked,
      member_activity_total: 0,
      member_activity_loading_more: False,
    ),
    member_dependencies.default_model(),
  )
}

pub fn select_tab(
  task_show: show_model.Model,
  tab: show_tabs.TaskShowTab,
) -> show_model.Model {
  show_model.Model(..task_show, active_tab: tab)
}

pub fn start_edit(
  task_show: show_model.Model,
  maybe_task: opt.Option(Task),
  can_edit: Bool,
) -> show_model.Model {
  case maybe_task, can_edit {
    opt.Some(_), True ->
      apply_edit_fields(task_show, edit_fields(maybe_task), True)
    _, _ -> task_show
  }
}

pub fn cancel_edit(
  task_show: show_model.Model,
  maybe_task: opt.Option(Task),
) -> show_model.Model {
  case maybe_task {
    opt.Some(_) -> apply_edit_fields(task_show, edit_fields(maybe_task), False)
    opt.None -> task_show
  }
}

fn apply_edit_fields(
  task_show: show_model.Model,
  fields: EditFields,
  editing: Bool,
) -> show_model.Model {
  show_model.Model(
    ..task_show,
    editing: editing,
    edit_title: fields.title,
    edit_description: fields.description,
    edit_priority: fields.priority,
    edit_type_id: fields.type_id,
    edit_card_id: fields.card_id,
    edit_in_flight: False,
    edit_error: opt.None,
  )
}

pub fn change_edit_title(
  task_show: show_model.Model,
  value: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_title: value, edit_error: opt.None)
}

pub fn change_edit_description(
  task_show: show_model.Model,
  value: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_description: value, edit_error: opt.None)
}

pub fn change_edit_priority(
  task_show: show_model.Model,
  value: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_priority: value, edit_error: opt.None)
}

pub fn change_edit_type_id(
  task_show: show_model.Model,
  value: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_type_id: value, edit_error: opt.None)
}

pub fn change_edit_card_id(
  task_show: show_model.Model,
  value: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_card_id: value, edit_error: opt.None)
}

pub fn edit_invalid(
  task_show: show_model.Model,
  message: String,
) -> show_model.Model {
  show_model.Model(..task_show, edit_error: opt.Some(message))
}

pub fn edit_unchanged(
  task_show: show_model.Model,
  submission: show_edit_form.Submission,
) -> show_model.Model {
  show_model.Model(
    ..task_show,
    editing: False,
    edit_title: submission.title,
    edit_description: submission.description,
    edit_priority: int.to_string(submission.priority),
    edit_type_id: int.to_string(submission.type_id),
    edit_card_id: id_to_form_value(submission.card_id),
    edit_in_flight: False,
    edit_error: opt.None,
  )
}

pub fn edit_started_submit(
  task_show: show_model.Model,
  submission: show_edit_form.Submission,
) -> show_model.Model {
  show_model.Model(
    ..task_show,
    edit_title: submission.title,
    edit_description: submission.description,
    edit_priority: int.to_string(submission.priority),
    edit_type_id: int.to_string(submission.type_id),
    edit_card_id: id_to_form_value(submission.card_id),
    edit_in_flight: True,
    edit_error: opt.None,
  )
}

pub fn task_updated(
  task_show: show_model.Model,
  updated_task: Task,
) -> show_model.Model {
  show_model.Model(
    ..task_show,
    editing: False,
    edit_title: updated_task.title,
    edit_description: show_edit_form.task_description_text(updated_task),
    edit_priority: int.to_string(updated_task.priority),
    edit_type_id: int.to_string(show_edit_form.task_type_id(updated_task)),
    edit_card_id: id_to_form_value(updated_task.card_id),
    edit_in_flight: False,
    edit_error: opt.None,
  )
}

fn id_to_form_value(id: opt.Option(Int)) -> String {
  case id {
    opt.Some(value) -> int.to_string(value)
    opt.None -> ""
  }
}

pub fn task_update_failed(
  task_show: show_model.Model,
  message: String,
) -> show_model.Model {
  show_model.Model(
    ..task_show,
    edit_in_flight: False,
    edit_error: opt.Some(message),
  )
}
