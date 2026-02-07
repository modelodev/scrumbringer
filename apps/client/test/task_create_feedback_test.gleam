import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/tasks/update as tasks_update
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/toast

fn make_task(id: Int, title: String, type_id: Int) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: title,
    description: Some("Task description"),
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
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

pub fn created_task_visible_feedback_uses_view_action_test() {
  let model = client_state.default_model()
  let task = make_task(42, "Implement toast", 1)

  let #(message, variant, action) =
    tasks_update.task_created_feedback_for_test(model, task)

  message |> should.equal("Task created")
  variant |> should.equal(toast.Success)
  action
  |> should.equal(toast.ToastAction(label: "View", kind: toast.ViewTask(42)))
}

pub fn created_task_hidden_feedback_uses_clear_filters_action_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_filters_type_id: Some(99)),
      )
    })
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, locale: locale.Es)
    })

  let task = make_task(7, "Tarea visible", 1)

  let #(message, variant, action) =
    tasks_update.task_created_feedback_for_test(model, task)

  message |> should.equal("Tarea creada, pero no visible por filtros actuales")
  variant |> should.equal(toast.Info)
  action
  |> should.equal(toast.ToastAction(
    label: "Limpiar",
    kind: toast.ClearPoolFilters,
  ))
}

pub fn toast_view_container_renders_action_button_and_aria_live_test() {
  let state =
    toast.init()
    |> toast.show_with_action(
      "Task created",
      toast.Success,
      Some(toast.ToastAction(label: "View", kind: toast.ViewTask(42))),
      100,
    )

  let html =
    toast.view_container(state, fn(_) { 0 }, fn(_) { 1 })
    |> element.to_document_string

  string.contains(html, "toast-action") |> should.be_true
  string.contains(html, "aria-live=\"polite\"") |> should.be_true
  string.contains(html, ">View<") |> should.be_true
}
