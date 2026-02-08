import gleam/int
import gleam/option.{None}
import gleam/string
import gleeunit/should
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
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/ui/task_tabs

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
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-08T00:00:00Z",
    version: 1,
    milestone_id: None,
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
    |> pool_dialogs.view_task_details(201)
    |> element.to_document_string

  string.contains(html, "Could not load metrics") |> should.be_true
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
    |> pool_dialogs.view_task_details(202)
    |> element.to_document_string

  string.contains(html, "Sin datos suficientes para métricas") |> should.be_true
}
