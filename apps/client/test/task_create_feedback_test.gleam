import gleam/option.{None, Some}
import gleam/string
import lustre/effect
import lustre/element

import domain/remote.{Loaded}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/capability_scope.{AllCapabilities}
import scrumbringer_client/features/pool/available_tasks
import scrumbringer_client/features/pool/task_created_feedback
import scrumbringer_client/features/pool/task_created_update
import scrumbringer_client/features/pool/visibility
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
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
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

pub fn created_task_visible_feedback_uses_view_action_test() {
  let task = make_task(42, "Implement toast", 1)

  let #(message, variant, action) =
    task_created_feedback.view(config(locale.En, None), task)

  let assert "Task created" = message
  let assert toast.Success = variant
  let assert toast.ToastAction(label: "View", kind: toast.ViewTask(42)) = action
}

pub fn created_task_hidden_feedback_uses_clear_filters_action_test() {
  let task = make_task(7, "Tarea visible", 1)

  let #(message, variant, action) =
    task_created_feedback.view(config(locale.Es, Some(99)), task)

  let assert "Tarea creada, pero no visible por filtros actuales" = message
  let assert toast.Info = variant
  let assert toast.ToastAction(label: "Limpiar", kind: toast.ClearPoolFilters) =
    action
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

  let assert True = string.contains(html, "toast-action")
  let assert True = string.contains(html, "aria-live=\"polite\"")
  let assert True = string.contains(html, ">View<")
}

pub fn post_create_effects_emit_feedback_timeout_and_toast_test() {
  let task = make_task(42, "Implement toast", 1)

  let fx = task_created_update.effects(config(locale.En, None), task, context())

  let assert False = fx == effect.none()
}

fn config(locale, type_filter) -> task_created_feedback.Config {
  task_created_feedback.Config(
    locale: locale,
    visibility: visibility.default(),
    work_filters: available_tasks.Config(
      tasks: Loaded([]),
      task_types: Loaded([]),
      my_capability_ids: Loaded([]),
      type_filter: type_filter,
      capability_filter: None,
      search_query: "",
      capability_scope: AllCapabilities,
      visibility: visibility.default(),
    ),
  )
}

fn context() -> task_created_update.Context(Int) {
  task_created_update.Context(
    on_task_created_feedback: fn(task_id) { task_id },
    on_highlight_expired: fn(task_id) { task_id },
    on_toast: fn(_message, _variant, _action) {
      effect.from(fn(_dispatch) { Nil })
    },
  )
}
