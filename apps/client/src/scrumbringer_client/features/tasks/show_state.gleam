//// Pure Task Show state transitions.

import gleam/int
import gleam/option as opt

import domain/remote.{Loading, NotAsked}
import domain/task.{type Task}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/show_edit_form
import scrumbringer_client/features/tasks/task_list
import scrumbringer_client/ui/show_tabs

pub fn open(
  pool: member_pool.Model,
  notes: member_notes.Model,
  dependencies: member_dependencies.Model,
  task_id: Int,
  maybe_task: opt.Option(Task),
) -> #(member_pool.Model, member_notes.Model, member_dependencies.Model) {
  let fields = edit_fields(maybe_task)

  #(
    member_pool.Model(
      ..pool,
      member_task_show_tab: show_tabs.TaskDetailsTab,
      member_task_show_editing: False,
      member_task_show_edit_title: fields.title,
      member_task_show_edit_description: fields.description,
      member_task_show_edit_priority: fields.priority,
      member_task_show_edit_type_id: fields.type_id,
      member_task_show_edit_card_id: fields.card_id,
      member_task_show_edit_in_flight: False,
      member_task_show_edit_error: opt.None,
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
  pool: member_pool.Model,
  notes: member_notes.Model,
) -> #(member_pool.Model, member_notes.Model, member_dependencies.Model) {
  #(
    member_pool.Model(
      ..pool,
      member_task_show_tab: show_tabs.TaskDetailsTab,
      member_task_show_editing: False,
      member_task_show_edit_title: "",
      member_task_show_edit_description: "",
      member_task_show_edit_priority: "3",
      member_task_show_edit_type_id: "",
      member_task_show_edit_card_id: "",
      member_task_show_edit_in_flight: False,
      member_task_show_edit_error: opt.None,
    ),
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
  pool: member_pool.Model,
  tab: show_tabs.TaskShowTab,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_show_tab: tab)
}

pub fn start_edit(
  pool: member_pool.Model,
  maybe_task: opt.Option(Task),
  can_edit: Bool,
) -> member_pool.Model {
  case maybe_task, can_edit {
    opt.Some(_), True -> apply_edit_fields(pool, edit_fields(maybe_task), True)
    _, _ -> pool
  }
}

pub fn cancel_edit(
  pool: member_pool.Model,
  maybe_task: opt.Option(Task),
) -> member_pool.Model {
  case maybe_task {
    opt.Some(_) -> apply_edit_fields(pool, edit_fields(maybe_task), False)
    opt.None -> pool
  }
}

fn apply_edit_fields(
  pool: member_pool.Model,
  fields: EditFields,
  editing: Bool,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_editing: editing,
    member_task_show_edit_title: fields.title,
    member_task_show_edit_description: fields.description,
    member_task_show_edit_priority: fields.priority,
    member_task_show_edit_type_id: fields.type_id,
    member_task_show_edit_card_id: fields.card_id,
    member_task_show_edit_in_flight: False,
    member_task_show_edit_error: opt.None,
  )
}

pub fn change_edit_title(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_title: value,
    member_task_show_edit_error: opt.None,
  )
}

pub fn change_edit_description(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_description: value,
    member_task_show_edit_error: opt.None,
  )
}

pub fn change_edit_priority(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_priority: value,
    member_task_show_edit_error: opt.None,
  )
}

pub fn change_edit_type_id(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_type_id: value,
    member_task_show_edit_error: opt.None,
  )
}

pub fn change_edit_card_id(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_card_id: value,
    member_task_show_edit_error: opt.None,
  )
}

pub fn edit_invalid(
  pool: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_show_edit_error: opt.Some(message))
}

pub fn edit_unchanged(
  pool: member_pool.Model,
  submission: show_edit_form.Submission,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_editing: False,
    member_task_show_edit_title: submission.title,
    member_task_show_edit_description: submission.description,
    member_task_show_edit_priority: int.to_string(submission.priority),
    member_task_show_edit_type_id: int.to_string(submission.type_id),
    member_task_show_edit_card_id: id_to_form_value(submission.card_id),
    member_task_show_edit_in_flight: False,
    member_task_show_edit_error: opt.None,
  )
}

pub fn edit_started_submit(
  pool: member_pool.Model,
  submission: show_edit_form.Submission,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_title: submission.title,
    member_task_show_edit_description: submission.description,
    member_task_show_edit_priority: int.to_string(submission.priority),
    member_task_show_edit_type_id: int.to_string(submission.type_id),
    member_task_show_edit_card_id: id_to_form_value(submission.card_id),
    member_task_show_edit_in_flight: True,
    member_task_show_edit_error: opt.None,
  )
}

pub fn task_updated(
  pool: member_pool.Model,
  updated_task: Task,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_tasks: task_list.upsert(pool.member_tasks, updated_task),
    member_task_show_editing: False,
    member_task_show_edit_title: updated_task.title,
    member_task_show_edit_description: show_edit_form.task_description_text(
      updated_task,
    ),
    member_task_show_edit_priority: int.to_string(updated_task.priority),
    member_task_show_edit_type_id: int.to_string(show_edit_form.task_type_id(
      updated_task,
    )),
    member_task_show_edit_card_id: id_to_form_value(updated_task.card_id),
    member_task_show_edit_in_flight: False,
    member_task_show_edit_error: opt.None,
  )
}

fn id_to_form_value(id: opt.Option(Int)) -> String {
  case id {
    opt.Some(value) -> int.to_string(value)
    opt.None -> ""
  }
}

pub fn task_update_failed(
  pool: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_show_edit_in_flight: False,
    member_task_show_edit_error: opt.Some(message),
  )
}
