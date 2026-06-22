import gleam/dict
import gleam/option.{None, Some}
import lustre/effect

import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/show_update
import scrumbringer_client/ui/show_tabs

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn show_context() -> show_update.Context(Nil) {
  show_update.Context(
    on_notes_fetched: fn(_result) { Nil },
    on_dependencies_fetched: fn(_result) { Nil },
    on_activity_fetched: fn(_result) { Nil },
  )
}

fn edit_context() -> show_update.EditContext(Nil) {
  show_update.EditContext(
    current_task: Some(sample_task()),
    can_edit: True,
    on_task_updated: fn(_result) { Nil },
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
  )
}

fn success_context() -> show_update.SuccessContext(Nil) {
  show_update.SuccessContext(
    task_updated: "Task updated",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() -> show_update.ErrorContext(Nil) {
  show_update.ErrorContext(
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn dispatch_context() -> show_update.DispatchContext(Nil) {
  show_update.DispatchContext(
    open_context: show_context(),
    edit_context: edit_context(),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn local_model() -> show_update.Model {
  show_update.Model(
    pool: member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([sample_task()]),
    ),
    notes: member_notes.default_model(),
    dependencies: member_dependencies.default_model(),
  )
}

pub fn local_task_show_opened_sets_show_state_and_fetches_test() {
  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(
      local_model(),
      pool_messages.MemberTaskShowOpened(42),
      dispatch_context(),
    )

  let assert show_tabs.TaskDetailsTab = next.pool.member_task_show_tab
  let assert False = next.pool.member_task_show_editing
  let assert "Prepare release" = next.pool.member_task_show_edit_title
  let assert "Review checklist." = next.pool.member_task_show_edit_description
  let assert Some(42) = next.notes.member_notes_task_id
  let assert True = next.notes.member_notes == remote.Loading
  let assert True = next.dependencies.member_dependencies == remote.Loading
  let assert show_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn local_task_show_opened_uses_project_cache_when_active_list_misses_task_test() {
  let task = sample_task()
  let model =
    show_update.Model(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([]),
        member_tasks_by_project: dict.from_list([#(task.project_id, [task])]),
      ),
      notes: member_notes.default_model(),
      dependencies: member_dependencies.default_model(),
    )

  let assert Some(show_update.Update(next, _, show_update.NoAuthCheck)) =
    show_update.try_update(
      model,
      pool_messages.MemberTaskShowOpened(task.id),
      dispatch_context(),
    )

  let assert "Prepare release" = next.pool.member_task_show_edit_title
  let assert "Review checklist." = next.pool.member_task_show_edit_description
  let assert "2" = next.pool.member_task_show_edit_priority
  let assert "1" = next.pool.member_task_show_edit_type_id
}

pub fn local_task_show_closed_resets_show_state_test() {
  let open_model =
    show_update.Model(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_task_show_tab: show_tabs.TaskActivityTab,
        member_task_show_editing: True,
        member_task_show_edit_title: "Changed",
        member_task_show_edit_description: "Changed description",
        member_task_show_edit_in_flight: True,
        member_task_show_edit_error: Some("old"),
      ),
      notes: member_notes.Model(
        ..member_notes.default_model(),
        member_notes_task_id: Some(42),
        member_notes: remote.Loading,
        member_note_content: "draft",
        member_note_error: Some("old"),
        member_note_dialog_mode: dialog_mode.DialogCreate,
      ),
      dependencies: member_dependencies.Model(
        member_dependencies: remote.Loading,
        member_dependency_dialog_mode: dialog_mode.DialogCreate,
        member_dependency_search_query: "oauth",
        member_dependency_candidates: remote.Loading,
        member_dependency_selected_task_id: Some(11),
        member_dependency_add_in_flight: True,
        member_dependency_add_error: Some("old"),
        member_dependency_remove_in_flight: Some(11),
      ),
    )

  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(
      open_model,
      pool_messages.MemberTaskShowClosed,
      dispatch_context(),
    )

  let assert show_tabs.TaskDetailsTab = next.pool.member_task_show_tab
  let assert False = next.pool.member_task_show_editing
  let assert "" = next.pool.member_task_show_edit_title
  let assert "" = next.pool.member_task_show_edit_description
  let assert None = next.notes.member_notes_task_id
  let assert True = next.notes.member_notes == remote.NotAsked
  let assert "" = next.notes.member_note_content
  let assert dialog_mode.DialogClosed = next.notes.member_note_dialog_mode
  let assert True = next.dependencies == member_dependencies.default_model()
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}
