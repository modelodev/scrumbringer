//// Effectful feedback workflow for task detail edit results.

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/task.{type Task}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/detail_state
import scrumbringer_client/ui/toast

pub type SuccessContext(parent_msg) {
  SuccessContext(
    task_updated: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorContext(parent_msg) {
  ErrorContext(
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn updated_ok(
  model: member_pool.Model,
  updated_task: Task,
  context: SuccessContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    detail_state.task_updated(model, updated_task),
    context.on_success_toast(context.task_updated),
  )
}

pub fn updated_error(
  model: member_pool.Model,
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    detail_state.task_update_failed(model, err.message),
    error_effect(err, context),
  )
}

pub fn error_effect(
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> Effect(parent_msg) {
  let #(message, variant) = error_feedback(err)

  case variant {
    toast.Warning -> context.on_warning_toast(message)
    toast.Error -> context.on_error_toast(message)
    _ -> context.on_error_toast(message)
  }
}

pub fn error_feedback(err: ApiError) -> #(String, toast.ToastVariant) {
  case err.status {
    403 | 409 | 422 -> #(err.message, toast.Warning)
    _ -> #(err.message, toast.Error)
  }
}
