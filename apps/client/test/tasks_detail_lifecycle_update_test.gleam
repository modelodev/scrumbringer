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
import scrumbringer_client/features/tasks/detail_update
import scrumbringer_client/ui/task_tabs

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
  )
}

fn detail_context() -> detail_update.Context(Nil) {
  detail_update.Context(
    on_notes_fetched: fn(_result) { Nil },
    on_dependencies_fetched: fn(_result) { Nil },
    on_metrics_fetched: fn(_result) { Nil },
  )
}

fn edit_context() -> detail_update.EditContext(Nil) {
  detail_update.EditContext(
    current_task: Some(sample_task()),
    can_edit: True,
    on_task_updated: fn(_result) { Nil },
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
  )
}

fn success_context() -> detail_update.SuccessContext(Nil) {
  detail_update.SuccessContext(
    task_updated: "Task updated",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() -> detail_update.ErrorContext(Nil) {
  detail_update.ErrorContext(
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn dispatch_context() -> detail_update.DispatchContext(Nil) {
  detail_update.DispatchContext(
    open_context: detail_context(),
    edit_context: edit_context(),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn local_model() -> detail_update.Model {
  detail_update.Model(
    pool: member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([sample_task()]),
    ),
    notes: member_notes.default_model(),
    dependencies: member_dependencies.default_model(),
  )
}

pub fn local_task_details_opened_sets_detail_state_and_fetches_test() {
  let assert Some(detail_update.Update(next, fx, policy)) =
    detail_update.try_update(
      local_model(),
      pool_messages.MemberTaskDetailsOpened(42),
      dispatch_context(),
    )

  let assert task_tabs.TasksTab = next.pool.member_task_detail_tab
  let assert True = next.pool.member_task_detail_metrics == remote.Loading
  let assert False = next.pool.member_task_detail_editing
  let assert "Prepare release" = next.pool.member_task_detail_edit_title
  let assert "Review checklist." = next.pool.member_task_detail_edit_description
  let assert Some(42) = next.notes.member_notes_task_id
  let assert True = next.notes.member_notes == remote.Loading
  let assert True = next.dependencies.member_dependencies == remote.Loading
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn local_task_details_opened_uses_project_cache_when_active_list_misses_task_test() {
  let task = sample_task()
  let model =
    detail_update.Model(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([]),
        member_tasks_by_project: dict.from_list([#(task.project_id, [task])]),
      ),
      notes: member_notes.default_model(),
      dependencies: member_dependencies.default_model(),
    )

  let assert Some(detail_update.Update(next, _, detail_update.NoAuthCheck)) =
    detail_update.try_update(
      model,
      pool_messages.MemberTaskDetailsOpened(task.id),
      dispatch_context(),
    )

  let assert "Prepare release" = next.pool.member_task_detail_edit_title
  let assert "Review checklist." = next.pool.member_task_detail_edit_description
  let assert "2" = next.pool.member_task_detail_edit_priority
  let assert "1" = next.pool.member_task_detail_edit_type_id
}

pub fn local_task_details_closed_resets_detail_state_test() {
  let open_model =
    detail_update.Model(
      pool: member_pool.Model(
        ..member_pool.default_model(),
        member_task_detail_tab: task_tabs.MetricsTab,
        member_task_detail_metrics: remote.Loading,
        member_task_detail_editing: True,
        member_task_detail_edit_title: "Changed",
        member_task_detail_edit_description: "Changed description",
        member_task_detail_edit_in_flight: True,
        member_task_detail_edit_error: Some("old"),
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

  let assert Some(detail_update.Update(next, fx, policy)) =
    detail_update.try_update(
      open_model,
      pool_messages.MemberTaskDetailsClosed,
      dispatch_context(),
    )

  let assert task_tabs.TasksTab = next.pool.member_task_detail_tab
  let assert True = next.pool.member_task_detail_metrics == remote.NotAsked
  let assert False = next.pool.member_task_detail_editing
  let assert "" = next.pool.member_task_detail_edit_title
  let assert "" = next.pool.member_task_detail_edit_description
  let assert None = next.notes.member_notes_task_id
  let assert True = next.notes.member_notes == remote.NotAsked
  let assert "" = next.notes.member_note_content
  let assert dialog_mode.DialogClosed = next.notes.member_note_dialog_mode
  let assert True = next.dependencies == member_dependencies.default_model()
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}
