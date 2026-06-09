//// Pure task detail state transitions.

import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/metrics.{type TaskModalMetrics}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/detail_edit_form
import scrumbringer_client/features/tasks/task_list
import scrumbringer_client/ui/task_tabs

pub fn open(
  pool: member_pool.Model,
  notes: member_notes.Model,
  dependencies: member_dependencies.Model,
  task_id: Int,
  edit_title: String,
  edit_description: String,
) -> #(member_pool.Model, member_notes.Model, member_dependencies.Model) {
  #(
    member_pool.Model(
      ..pool,
      member_task_detail_tab: task_tabs.TasksTab,
      member_task_detail_metrics: Loading,
      member_task_detail_editing: False,
      member_task_detail_edit_title: edit_title,
      member_task_detail_edit_description: edit_description,
      member_task_detail_edit_in_flight: False,
      member_task_detail_edit_error: opt.None,
    ),
    member_notes.Model(
      ..notes,
      member_notes_task_id: opt.Some(task_id),
      member_notes: Loading,
      member_note_error: opt.None,
    ),
    member_dependencies.Model(
      ..dependencies,
      member_dependencies: Loading,
      member_dependency_add_error: opt.None,
      member_dependency_remove_in_flight: opt.None,
    ),
  )
}

pub fn close(
  pool: member_pool.Model,
  notes: member_notes.Model,
) -> #(member_pool.Model, member_notes.Model, member_dependencies.Model) {
  #(
    member_pool.Model(
      ..pool,
      member_task_detail_tab: task_tabs.TasksTab,
      member_task_detail_metrics: NotAsked,
      member_task_detail_editing: False,
      member_task_detail_edit_title: "",
      member_task_detail_edit_description: "",
      member_task_detail_edit_in_flight: False,
      member_task_detail_edit_error: opt.None,
    ),
    member_notes.Model(
      ..notes,
      member_notes_task_id: opt.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_error: opt.None,
      member_note_dialog_mode: dialog_mode.DialogClosed,
    ),
    member_dependencies.default_model(),
  )
}

pub fn select_tab(
  pool: member_pool.Model,
  tab: task_tabs.Tab,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_detail_tab: tab)
}

pub fn start_edit(
  pool: member_pool.Model,
  maybe_task: opt.Option(Task),
  can_edit: Bool,
) -> member_pool.Model {
  case maybe_task, can_edit {
    opt.Some(task), True ->
      member_pool.Model(
        ..pool,
        member_task_detail_editing: True,
        member_task_detail_edit_title: task.title,
        member_task_detail_edit_description: detail_edit_form.task_description_text(
          task,
        ),
        member_task_detail_edit_in_flight: False,
        member_task_detail_edit_error: opt.None,
      )
    _, _ -> pool
  }
}

pub fn cancel_edit(
  pool: member_pool.Model,
  maybe_task: opt.Option(Task),
) -> member_pool.Model {
  case maybe_task {
    opt.Some(task) ->
      member_pool.Model(
        ..pool,
        member_task_detail_editing: False,
        member_task_detail_edit_title: task.title,
        member_task_detail_edit_description: detail_edit_form.task_description_text(
          task,
        ),
        member_task_detail_edit_in_flight: False,
        member_task_detail_edit_error: opt.None,
      )
    opt.None -> pool
  }
}

pub fn change_edit_title(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_detail_edit_title: value,
    member_task_detail_edit_error: opt.None,
  )
}

pub fn change_edit_description(
  pool: member_pool.Model,
  value: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_detail_edit_description: value,
    member_task_detail_edit_error: opt.None,
  )
}

pub fn edit_invalid(
  pool: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_detail_edit_error: opt.Some(message))
}

pub fn edit_unchanged(
  pool: member_pool.Model,
  title: String,
  description: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_detail_editing: False,
    member_task_detail_edit_title: title,
    member_task_detail_edit_description: description,
    member_task_detail_edit_in_flight: False,
    member_task_detail_edit_error: opt.None,
  )
}

pub fn edit_started_submit(
  pool: member_pool.Model,
  title: String,
  description: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_detail_edit_title: title,
    member_task_detail_edit_description: description,
    member_task_detail_edit_in_flight: True,
    member_task_detail_edit_error: opt.None,
  )
}

pub fn metrics_loaded(
  pool: member_pool.Model,
  metrics: TaskModalMetrics,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_detail_metrics: Loaded(metrics))
}

pub fn metrics_failed(
  pool: member_pool.Model,
  err: ApiError,
) -> member_pool.Model {
  member_pool.Model(..pool, member_task_detail_metrics: Failed(err))
}

pub fn task_updated(
  pool: member_pool.Model,
  updated_task: Task,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_tasks: task_list.replace(pool.member_tasks, updated_task),
    member_task_detail_editing: False,
    member_task_detail_edit_title: updated_task.title,
    member_task_detail_edit_description: detail_edit_form.task_description_text(
      updated_task,
    ),
    member_task_detail_edit_in_flight: False,
    member_task_detail_edit_error: opt.None,
  )
}

pub fn task_update_failed(
  pool: member_pool.Model,
  message: String,
) -> member_pool.Model {
  member_pool.Model(
    ..pool,
    member_task_detail_edit_in_flight: False,
    member_task_detail_edit_error: opt.Some(message),
  )
}
