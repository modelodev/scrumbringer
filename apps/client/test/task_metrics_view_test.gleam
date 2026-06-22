import gleam/int
import gleam/option.{None}
import gleam/string
import lustre/element

import domain/api_error.{ApiError}
import domain/metrics
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/pool/task_details_dialog_config as task_details_dialog
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/ui/task_tabs

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn sample_task(id: Int) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: None,
    title: "Task " <> int.to_string(id),
    description: None,
    priority: 1,
    state: state,
    created_by: 1,
    created_at: "2026-02-08T00:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn with_locale(
  model: client_state.Model,
  locale: i18n_locale.Locale,
) -> client_state.Model {
  client_state.update_ui(model, fn(ui) {
    ui_state.UiModel(..ui, locale: locale)
  })
}

fn task_details_callbacks() -> task_details_dialog.Callbacks(String) {
  task_details_dialog.Callbacks(
    on_close: "close",
    on_tab_clicked: fn(_) { "tab" },
    on_dependency_dialog_opened: "dependency-open",
    on_dependency_dialog_closed: "dependency-close",
    on_dependency_add_submitted: "dependency-add",
    on_dependency_search_changed: fn(value) { "dependency-search:" <> value },
    on_dependency_selected: fn(_) { "dependency-selected" },
    on_dependency_remove: fn(_) { "dependency-remove" },
    on_edit_started: "edit-start",
    on_edit_cancelled: "edit-cancel",
    on_edit_title_changed: fn(value) { "title:" <> value },
    on_edit_description_changed: fn(value) { "description:" <> value },
    on_edit_priority_changed: fn(value) { "priority:" <> value },
    on_edit_type_id_changed: fn(value) { "type:" <> value },
    on_edit_card_id_changed: fn(value) { "card:" <> value },
    on_edit_submitted: "edit-submit",
    on_note_dialog_opened: "note-open",
    on_note_dialog_closed: "note-close",
    on_note_content_changed: fn(value) { "note:" <> value },
    on_note_submitted: "note-submit",
    on_note_delete: fn(_) { "note-delete" },
    on_claim: fn(_, _) { "claim" },
    on_release: fn(_, _) { "release" },
    on_complete: fn(_, _) { "complete" },
    on_delete: fn(_) { "delete" },
  )
}

fn task_details_view(model: client_state.Model, task_id: Int) {
  task_details_dialog.view(
    model.ui.locale,
    model.member.pool,
    model.member.dependencies,
    model.member.notes,
    None,
    False,
    [],
    task_id,
    task_details_callbacks(),
  )
}

pub fn task_metrics_error_copy_i18n_test() {
  let html =
    client_state.default_model()
    |> with_locale(i18n_locale.En)
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([sample_task(201)]),
          member_task_detail_tab: task_tabs.MetricsTab,
          member_task_detail_metrics: remote.Failed(ApiError(
            status: 409,
            code: "metrics_unavailable",
            message: "x",
          )),
        ),
      )
    })
    |> task_details_view(201)
    |> element.to_document_string

  assert_contains(html, "Could not load metrics")
}

pub fn task_metrics_empty_copy_i18n_test() {
  let html =
    client_state.default_model()
    |> with_locale(i18n_locale.Es)
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loaded([sample_task(202)]),
          member_task_detail_tab: task_tabs.MetricsTab,
          member_task_detail_metrics: remote.Loaded(metrics.TaskModalMetrics(
            claim_count: 0,
            release_count: 0,
            unique_executors: 0,
            first_claim_at: None,
            current_state_duration_s: 0,
            pool_lifetime_s: 0,
            session_count: 0,
            total_work_time_s: 0,
          )),
        ),
      )
    })
    |> task_details_view(202)
    |> element.to_document_string

  assert_contains(html, "Sin datos suficientes para métricas")
}
